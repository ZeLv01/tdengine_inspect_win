# Module 16: Database Service Version
# Checks: taos and taosd version consistency

function Get-ServiceVersionInfo {
    param(
        [object]$Config
    )
    
    $result = @{
        Name = "Database Service Version"
        Status = "Pass"
        Data = @{}
        Issues = @()
        Details = @()
    }
    
    try {
        $versionInfo = [ordered]@{}
        
        # Get server version via SQL
        try {
            $serverResult = Invoke-TDengineQuery -Sql "SELECT server_version()" -Config $Config
            if ($serverResult.code -eq 0 -and $serverResult.data) {
                $versionInfo["Server Version"] = $serverResult.data[0].'server_version()'
            }
        } catch {
            $versionInfo["Server Version"] = "Unknown"
        }
        
        # Get client version via SQL
        try {
            $clientResult = Invoke-TDengineQuery -Sql "SELECT client_version()" -Config $Config
            if ($clientResult.code -eq 0 -and $clientResult.data) {
                $versionInfo["Client Version"] = $clientResult.data[0].'client_version()'
            }
        } catch {
            $versionInfo["Client Version"] = "Unknown"
        }
        
        # Get taos version
        try {
            $taosOutput = & taos -V 2>&1
            $taosText = $taosOutput -join "`n"
            if ($taosText -match 'taos version:\s*(\S+)') {
                $versionInfo["taos Version"] = $Matches[1]
            } else {
                $versionInfo["taos Version"] = "Not detected"
            }
        } catch {
            $versionInfo["taos Version"] = "Not installed"
        }
        
        # Get taosd version
        try {
            $taosdOutput = & taosd -V 2>&1
            $taosdText = $taosdOutput -join "`n"
            if ($taosdText -match 'taosd version:\s*(\S+)') {
                $versionInfo["taosd Version"] = $Matches[1]
            } else {
                $versionInfo["taosd Version"] = "Not detected"
            }
        } catch {
            $versionInfo["taosd Version"] = "Not installed"
        }
        
        # Get taosadapter version
        try {
            $adapterOutput = & taosadapter -V 2>&1
            $adapterText = $adapterOutput -join "`n"
            if ($adapterText -match 'taosAdapter version:\s*(\S+)') {
                $versionInfo["taosAdapter Version"] = $Matches[1]
            } else {
                $versionInfo["taosAdapter Version"] = "Not detected"
            }
        } catch {
            $versionInfo["taosAdapter Version"] = "Not installed"
        }
        
        # Get taoskeeper version
        try {
            $keeperOutput = & taoskeeper -V 2>&1
            $keeperText = $keeperOutput -join "`n"
            if ($keeperText -match 'taoskeeper version:\s*(\S+)') {
                $versionInfo["taoskeeper Version"] = $Matches[1]
            } else {
                $versionInfo["taoskeeper Version"] = "Not detected"
            }
        } catch {
            $versionInfo["taoskeeper Version"] = "Not installed"
        }
        
        # Get taosx version
        try {
            $taosxOutput = & taosx -V 2>&1
            $taosxText = $taosxOutput -join "`n"
            if ($taosxText -match 'taosx version:\s*(\S+)') {
                $versionInfo["taosx Version"] = $Matches[1]
            } else {
                $versionInfo["taosx Version"] = "Not detected"
            }
        } catch {
            $versionInfo["taosx Version"] = "Not installed"
        }
        
        # Get taos-explorer version
        try {
            $explorerOutput = & taos-explorer -V 2>&1
            $explorerText = $explorerOutput -join "`n"
            if ($explorerText -match 'taos-explorer version:\s*(\S+)') {
                $versionInfo["taos-explorer Version"] = $Matches[1]
            } else {
                $versionInfo["taos-explorer Version"] = "Not detected"
            }
        } catch {
            $versionInfo["taos-explorer Version"] = "Not installed"
        }
        
        $result.Data = $versionInfo
        
        $result.Details += "TDengine Version Information"
        $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
        $result.Details += "{0,-25} {1}" -f "Component", "Version"
        $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
        
        foreach ($key in $versionInfo.Keys) {
            $result.Details += "{0,-25} {1}" -f $key, $versionInfo[$key]
        }
        $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
        
        # Check version consistency (remove enterprise suffix for comparison)
        $versions = $versionInfo.Values | Where-Object { 
            $_ -ne "Unknown" -and $_ -ne "Not installed" -and $_ -ne "Not detected" -and $_ -match '\d+\.\d+' 
        } | ForEach-Object {
            # Remove .enterprise suffix for comparison
            $_ -replace '\.enterprise$', ''
        } | Select-Object -Unique
        
        if ($versions.Count -gt 1) {
            $result.Status = "Warning"
            $result.Issues += "Version mismatch detected between components"
        }
        
    } catch {
        $result.Status = "Critical"
        $result.Issues += "Failed to retrieve version information: $($_.Exception.Message)"
    }
    
    return $result
}
