# Module 06: Database Dnode Information
# Checks: Vnodes count, dnode status, reboot_time

function Get-DnodeInfo {
    param(
        [object]$Config
    )
    
    $result = @{
        Name = "Database Dnode Information"
        Status = "Pass"
        Data = @{}
        Issues = @()
        Details = @()
    }
    
    try {
        # Query dnode information using information_schema for reliable access
        $dnodeResult = Invoke-TDengineQuery -Sql "SELECT * FROM information_schema.ins_dnodes" -Config $Config
        
        if ($dnodeResult.code -eq 0 -and $dnodeResult.data) {
            $dnodeList = @()
            $offlineDnodes = @()
            
            foreach ($dnode in $dnodeResult.data) {
                $dnodeInfo = @{
                    "ID" = if ($dnode.id) { $dnode.id } else { "N/A" }
                    "Endpoint" = if ($dnode.endpoint) { $dnode.endpoint } else { "N/A" }
                    "Status" = if ($dnode.status) { $dnode.status } else { "unknown" }
                    "Vnodes" = if ($dnode.vnodes) { $dnode.vnodes } else { 0 }
                    "Reboot Time" = if ($dnode.reboot_time) { $dnode.reboot_time } else { "N/A" }
                    "Create Time" = if ($dnode.create_time) { $dnode.create_time } else { "N/A" }
                }
                $dnodeList += $dnodeInfo
                
                # Check for offline dnodes
                $status = $dnodeInfo.Status.ToString().ToLower()
                if ($status -ne "ready" -and $status -ne "online" -and $status -ne "ok") {
                    $offlineDnodes += $dnodeInfo.Endpoint
                }
            }
            
            # Query vnode distribution
            $vnodeCount = 0
            try {
                $vnodeResult = Invoke-TDengineQuery -Sql "SHOW VNODES" -Config $Config
                if ($vnodeResult.code -eq 0 -and $vnodeResult.data) {
                    $vnodeCount = $vnodeResult.data.Count
                }
            } catch {
                # VNODES query might fail, continue anyway
            }
            
            $result.Data = @{
                "Total Dnodes" = $dnodeList.Count
                "Total Vnodes" = $vnodeCount
                "Dnode List" = $dnodeList
                "Offline Dnodes" = $offlineDnodes
            }
            
            $result.Details += "Total Dnodes: $($dnodeList.Count)"
            $result.Details += "Total Vnodes: $vnodeCount"
            $result.Details += ""
            $result.Details += "Dnode Details:"
            $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
            $result.Details += "{0,-5} {1,-30} {2,-12} {3,-8} {4,-22} {5,-22}" -f "ID", "Endpoint", "Status", "Vnodes", "Reboot Time", "Create Time"
            $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
            
            foreach ($dnode in $dnodeList) {
                $statusLower = $dnode.Status.ToString().ToLower()
                $statusIcon = if ($statusLower -eq "ready" -or $statusLower -eq "online" -or $statusLower -eq "ok") { "[OK]" } else { "[!!]" }
                $result.Details += "{0,-5} {1,-30} {2,-12} {3,-8} {4,-22} {5,-22}" -f $dnode.ID, $dnode.Endpoint, "$statusIcon$($dnode.Status)", $dnode.Vnodes, $dnode.'Reboot Time', $dnode.'Create Time'
            }
            $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
            
            # Report offline dnodes
            if ($offlineDnodes.Count -gt 0) {
                $result.Status = "Critical"
                $result.Issues += "Offline dnodes detected: $($offlineDnodes -join ', ')"
            }
            
        } else {
            $result.Status = "Critical"
            $result.Issues += "Failed to query dnode information"
        }
        
    } catch {
        $result.Status = "Critical"
        $result.Issues += "Failed to retrieve dnode information: $($_.Exception.Message)"
    }
    
    return $result
}
