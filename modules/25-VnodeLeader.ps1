# Module 25: Vnodes Leader Distribution
# Checks: Vnode leader count per dnode, balance status

function Get-VnodeLeaderInfo {
    param(
        [object]$Config
    )
    
    $result = @{
        Name = "Vnodes Leader Distribution"
        Status = "Pass"
        Data = @{}
        Issues = @()
        Details = @()
    }
    
    try {
        $querySuccess = $false
        $leaderData = @()
        
        # Query vnode leader count by dnode
        try {
            $queryResult = Invoke-TDengineQuery -Sql "SELECT dnode_id, count(*) FROM information_schema.ins_vnodes WHERE status='leader' GROUP BY dnode_id ORDER BY dnode_id" -Config $Config
            
            if ($queryResult.code -eq 0 -and $queryResult.data) {
                $totalLeaders = 0
                $dnodeCount = 0
                
                foreach ($row in $queryResult.data) {
                    $dnodeId = if ($row.dnode_id) { $row.dnode_id } else { "Unknown" }
                    $leaderCount = if ($row.'count(*)') { [int]$row.'count(*)' } else { 0 }
                    
                    $leaderData += @{
                        "Dnode ID" = $dnodeId
                        "Leader Count" = $leaderCount
                    }
                    $totalLeaders += $leaderCount
                    $dnodeCount++
                }
                
                # Also get total dnode count for comparison
                try {
                    $dnodeResult = Invoke-TDengineQuery -Sql "SHOW DNODES" -Config $Config
                    if ($dnodeResult.code -eq 0 -and $dnodeResult.data) {
                        $totalDnodes = $dnodeResult.data.Count
                    }
                } catch { }
                
                $result.Data = @{
                    "Total Leaders" = $totalLeaders
                    "Dnodes with Leaders" = $dnodeCount
                    "Total Dnodes" = $totalDnodes
                    "Leader Distribution" = $leaderData
                }
                
                $result.Details += "Vnodes Leader Distribution"
                $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
                $result.Details += "Total Leaders: $totalLeaders | Dnodes with Leaders: $dnodeCount / $totalDnodes"
                $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
                $result.Details += ""
                $result.Details += "Leader Distribution:"
                $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
                $result.Details += "{0,-12} {1}" -f "Dnode ID", "Leader Count"
                $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
                
                foreach ($ld in $leaderData | Sort-Object "Dnode ID") {
                    $result.Details += "{0,-12} {1}" -f $ld.'Dnode ID', $ld.'Leader Count'
                }
                $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
                
                $querySuccess = $true
                
                # Check for balance issues
                if ($dnodeCount -gt 0 -and $totalDnodes -gt 1) {
                    $leaderCounts = $leaderData | ForEach-Object { $_.'Leader Count' }
                    $maxLeaders = ($leaderCounts | Measure-Object -Maximum).Maximum
                    $minLeaders = ($leaderCounts | Measure-Object -Minimum).Minimum
                    
                    # Check if any dnode has no leaders
                    $dnodeIdsWithLeaders = $leaderData | ForEach-Object { $_.'Dnode ID' }
                    
                    # Try to get all dnode IDs
                    try {
                        $dnodeResult = Invoke-TDengineQuery -Sql "SELECT dnode_id FROM information_schema.ins_dnodes ORDER BY dnode_id" -Config $Config
                        if ($dnodeResult.code -eq 0 -and $dnodeResult.data) {
                            foreach ($dn in $dnodeResult.data) {
                                $did = if ($dn.dnode_id) { $dn.dnode_id } else { $null }
                                if ($did -and $did -notin $dnodeIdsWithLeaders) {
                                    $result.Status = "Warning"
                                    $result.Issues += "Dnode $did has 0 vnode leaders. Recommend: BALANCE VGROUP LEADER"
                                }
                            }
                        }
                    } catch { }
                    
                    # Check for significant imbalance (one node has > 60% of leaders)
                    if ($dnodeCount -ge 2 -and $totalLeaders -gt 0) {
                        $expectedPerNode = $totalLeaders / $dnodeCount
                        # If one node has more than 1.5x the expected leaders
                        foreach ($ld in $leaderData) {
                            if ($ld.'Leader Count' -gt ($expectedPerNode * 1.5)) {
                                $result.Status = "Warning"
                                $result.Issues += "Dnode $($ld.'Dnode ID') has $($ld.'Leader Count') leaders (expected ~$([math]::Round($expectedPerNode))). Unbalanced - recommend: BALANCE VGROUP LEADER"
                            }
                        }
                        # If one node has fewer than 50% of expected leaders
                        foreach ($ld in $leaderData) {
                            if ($ld.'Leader Count' -lt ($expectedPerNode * 0.5)) {
                                $result.Status = "Warning"
                                $result.Issues += "Dnode $($ld.'Dnode ID') has only $($ld.'Leader Count') leaders (expected ~$([math]::Round($expectedPerNode))). Unbalanced - recommend: BALANCE VGROUP LEADER"
                            }
                        }
                    }
                }
                
                if ($result.Status -eq "Warning" -and $result.Issues.Count -gt 0) {
                    $result.Details += ""
                    $result.Details += "Balance Recommendation:"
                    $result.Details += "  Run: BALANCE VGROUP LEADER"
                    $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
                }
                
            } else {
                $result.Status = "Warning"
                $result.Issues += "Failed to query vnode leader information"
            }
        } catch {
            $result.Status = "Warning"
            $result.Issues += "Failed to query vnode leader information: $($_.Exception.Message)"
        }
        
    } catch {
        $result.Status = "Warning"
        $result.Issues += "Failed to retrieve vnode leader information: $($_.Exception.Message)"
    }
    
    return $result
}
