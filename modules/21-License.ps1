# Module 21: Database License/Authorization

function Get-LicenseInfo {
    param(
        [object]$Config
    )
    
    $result = @{
        Name = "Database License/Authorization"
        Status = "Pass"
        Data = @{}
        Issues = @()
        Details = @()
    }
    
    try {
        # Run SHOW GRANTS (basic view)
        $showGrantsRaw = $null
        $showGrantsFull = $null
        
        try {
            $showGrantsRaw = Invoke-TDengineQuery -Sql "SHOW GRANTS" -Config $Config
        } catch { }
        
        try {
            $showGrantsFull = Invoke-TDengineQuery -Sql "SHOW GRANTS FULL" -Config $Config
        } catch { }
        
        $result.Details += "Database License/Authorization Information"
        $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
        $result.Details += "1. LICENSE SUMMARY"
        $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
        
        if ($showGrantsRaw -and $showGrantsRaw.code -eq 0 -and $showGrantsRaw.data -and $showGrantsRaw.data.Count -gt 0) {
            $grant = $showGrantsRaw.data[0]
            
            # Extract fields dynamically
            $version = if ($grant.version) { $grant.version } elseif ($grant.'version') { $grant.'version' } else { $null }
            $expireTime = if ($grant.expire_time) { $grant.expire_time } elseif ($grant.'expire_time') { $grant.'expire_time' } else { $null }
            $serviceTime = if ($grant.service_time) { $grant.service_time } elseif ($grant.'service_time') { $grant.'service_time' } else { $null }
            $expired = if ($grant.expired) { $grant.expired } elseif ($grant.'expired') { $grant.'expired' } else { $null }
            $state = if ($grant.state) { $grant.state } elseif ($grant.'state') { $grant.'state' } else { $null }
            $timeseries = if ($grant.timeseries) { $grant.timeseries } elseif ($grant.'timeseries') { $grant.'timeseries' } else { $null }
            $dnodes = if ($grant.dnodes) { $grant.dnodes } elseif ($grant.'dnodes') { $grant.'dnodes' } else { $null }
            $cpuCores = if ($grant.cpu_cores) { $grant.cpu_cores } elseif ($grant.'cpu_cores') { $grant.'cpu_cores' } else { $null }
            $vnodes = if ($grant.vnodes) { $grant.vnodes } elseif ($grant.'vnodes') { $grant.'vnodes' } else { $null }
            $storageSize = if ($grant.storage_size) { $grant.storage_size } elseif ($grant.'storage_size') { $grant.'storage_size' } else { $null }
            
            $result.Details += "{0,-30} {1}" -f "Version", $(if ($version) { $version } else { "N/A" })
            $result.Details += "{0,-30} {1}" -f "License Expiry", $(if ($expireTime) { $expireTime } else { "N/A" })
            $result.Details += "{0,-30} {1}" -f "Service Time", $(if ($serviceTime) { $serviceTime } else { "N/A" })
            $result.Details += "{0,-30} {1}" -f "Expired", $(if ($expired) { $expired } else { "N/A" })
            $result.Details += "{0,-30} {1}" -f "State", $(if ($state) { $state } else { "N/A" })
            $result.Details += "{0,-30} {1}" -f "Timeseries", $(if ($timeseries) { $timeseries } else { "N/A" })
            $result.Details += "{0,-30} {1}" -f "Dnodes", $(if ($dnodes) { $dnodes } else { "N/A" })
            $result.Details += "{0,-30} {1}" -f "CPU Cores", $(if ($cpuCores) { $cpuCores } else { "N/A" })
            $result.Details += "{0,-30} {1}" -f "Vnodes", $(if ($vnodes) { $vnodes } else { "N/A" })
            $result.Details += "{0,-30} {1}" -f "Storage Size", $(if ($storageSize) { $storageSize } else { "N/A" })
            
            # Check expiry
            if ($expireTime) {
                try {
                    $expireDateTime = [DateTime]::Parse($expireTime.ToString())
                    $daysUntilExpiry = ($expireDateTime - (Get-Date)).Days
                    $result.Details += "{0,-30} {1}" -f "Days Until Expiry", $daysUntilExpiry
                    $result.Data["Days Until Expiry"] = $daysUntilExpiry
                    
                    if ($daysUntilExpiry -lt 0) {
                        $result.Status = "Critical"
                        $result.Issues += "CRITICAL: License has expired!"
                    } elseif ($daysUntilExpiry -lt $Config.thresholds.licenseExpiryDays) {
                        $result.Status = "Warning"
                        $result.Issues += "License expires in $daysUntilExpiry days (threshold: $($Config.thresholds.licenseExpiryDays) days)"
                    }
                } catch { }
            }
            
            # Check timeseries usage (format: "used/unlimited" or "used/max")
            if ($timeseries) {
                $parts = $timeseries.ToString() -split '/'
                if ($parts.Count -eq 2) {
                    $tsUsed = $parts[0]
                    $tsAuth = $parts[1]
                    $result.Data["Timeseries Used"] = $tsUsed
                    $result.Data["Timeseries Authorized"] = $tsAuth
                    
                    if ($tsAuth -notmatch 'unlimited|infinite' -and [int]$tsAuth -gt 0) {
                        $usagePercent = [math]::Round(([int]$tsUsed / [int]$tsAuth) * 100, 2)
                        $result.Details += "{0,-30} {1}%" -f "Timeseries Usage", $usagePercent
                        $result.Data["Timeseries Usage %"] = $usagePercent
                        
                        if ($usagePercent -ge $Config.thresholds.licenseUsagePercent) {
                            $result.Status = "Warning"
                            $result.Issues += "Timeseries usage ($usagePercent%) exceeds threshold ($($Config.thresholds.licenseUsagePercent)%)"
                        }
                    }
                }
            }
            
            $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
        } else {
            $result.Details += "License summary not available via WebSocket"
            $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
        }
        
        # SHOW GRANTS FULL
        $result.Details += ""
        $result.Details += "2. GRANT DETAILS"
        $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
        
        if ($showGrantsFull -and $showGrantsFull.code -eq 0 -and $showGrantsFull.data -and $showGrantsFull.data.Count -gt 0) {
            $result.Details += "{0,-20} {1,-25} {2,-25} {3}" -f "Grant Name", "Display Name", "Expire", "Limits"
            $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
            
            foreach ($row in $showGrantsFull.data) {
                $grantName = if ($row.grant_name) { $row.grant_name } elseif ($row.'grant_name') { $row.'grant_name' } else { "N/A" }
                $displayName = if ($row.display_name) { $row.display_name } elseif ($row.'display_name') { $row.'display_name' } else { "N/A" }
                $expire = if ($row.expire) { $row.expire } elseif ($row.'expire') { $row.'expire' } else { "N/A" }
                $limits = if ($row.limits) { $row.limits } elseif ($row.'limits') { $row.'limits' } else { "N/A" }
                
                $result.Details += "{0,-20} {1,-25} {2,-25} {3}" -f $grantName, $displayName, $expire, $limits
            }
            $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
        } else {
            $result.Details += "Grant details not available via WebSocket"
            $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
        }
        
    } catch {
        $result.Status = "Warning"
        $result.Issues += "Failed to retrieve license information: $($_.Exception.Message)"
    }
    
    return $result
}
