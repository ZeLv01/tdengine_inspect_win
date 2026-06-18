# Module 07: Database Mnode Information
# Checks: Mnode role, status, role_time

function Get-MnodeInfo {
    param(
        [object]$Config
    )
    
    $result = @{
        Name = "Database Mnode Information"
        Status = "Pass"
        Data = @{}
        Issues = @()
        Details = @()
    }
    
    try {
        # Query mnode information using information_schema for reliable access
        $mnodeResult = Invoke-TDengineQuery -Sql "SELECT * FROM information_schema.ins_mnodes" -Config $Config
        
        if ($mnodeResult.code -eq 0 -and $mnodeResult.data) {
            $mnodeList = @()
            $offlineMnodes = @()
            $leaderCount = 0
            
            foreach ($mnode in $mnodeResult.data) {
                $mnodeInfo = @{
                    "ID" = if ($mnode.id) { $mnode.id } else { "N/A" }
                    "Endpoint" = if ($mnode.endpoint) { $mnode.endpoint } else { "N/A" }
                    "Role" = if ($mnode.role) { $mnode.role } else { "N/A" }
                    "Status" = if ($mnode.status) { $mnode.status } else { "unknown" }
                    "Role Time" = if ($mnode.role_time) { $mnode.role_time } else { "N/A" }
                    "Create Time" = if ($mnode.create_time) { $mnode.create_time } else { "N/A" }
                }
                $mnodeList += $mnodeInfo
                
                # Count leaders
                $role = $mnodeInfo.Role.ToString().ToLower()
                if ($role -eq "leader" -or $role -eq "master") {
                    $leaderCount++
                }
                
                # Check for offline mnodes
                $status = $mnodeInfo.Status.ToString().ToLower()
                if ($status -ne "ready" -and $status -ne "online" -and $status -ne "ok") {
                    $offlineMnodes += $mnodeInfo.Endpoint
                }
            }
            
            $result.Data = @{
                "Total Mnodes" = $mnodeList.Count
                "Leader Count" = $leaderCount
                "Mnode List" = $mnodeList
                "Offline Mnodes" = $offlineMnodes
            }
            
            $result.Details += "Total Mnodes: $($mnodeList.Count)"
            $result.Details += "Leader Count: $leaderCount"
            $result.Details += ""
            $result.Details += "Mnode Details:"
            $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
            $result.Details += "{0,-5} {1,-30} {2,-12} {3,-12} {4,-22} {5,-22}" -f "ID", "Endpoint", "Role", "Status", "Role Time", "Create Time"
            $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
            
            foreach ($mnode in $mnodeList) {
                $statusLower = $mnode.Status.ToString().ToLower()
                $statusIcon = if ($statusLower -eq "ready" -or $statusLower -eq "online" -or $statusLower -eq "ok") { "[OK]" } else { "[!!]" }
                $result.Details += "{0,-5} {1,-30} {2,-12} {3,-12} {4,-22} {5,-22}" -f $mnode.ID, $mnode.Endpoint, $mnode.Role, "$statusIcon$($mnode.Status)", $mnode.'Role Time', $mnode.'Create Time'
            }
            $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
            
            # Check for issues
            if ($offlineMnodes.Count -gt 0) {
                $result.Status = "Critical"
                $result.Issues += "Offline mnodes detected: $($offlineMnodes -join ', ')"
            }
            
            if ($leaderCount -ne 1) {
                $result.Status = "Warning"
                $result.Issues += "Expected exactly 1 mnode leader, found $leaderCount"
            }
            
            if ($mnodeList.Count -lt 3) {
                $result.Status = "Warning"
                $result.Issues += "Current deployment is single-node (no high availability). Consider deploying a 3-node cluster with 3 mnodes for HA."
            }
            
        } else {
            $result.Status = "Critical"
            $result.Issues += "Failed to query mnode information"
        }
        
    } catch {
        $result.Status = "Critical"
        $result.Issues += "Failed to retrieve mnode information: $($_.Exception.Message)"
    }
    
    return $result
}
