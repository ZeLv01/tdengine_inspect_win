# Module 04: Database Data Directory Usage
# Checks: Data directory mount path, filesystem, storage type, used space, available space, usage percentage

function Get-DataDirectoryInfo {
    param(
        [object]$Config
    )
    
    $result = @{
        Name = "Database Data Directory Usage"
        Status = "Pass"
        Data = @{}
        Issues = @()
        Details = @()
    }
    
    try {
        # Get data directory from TDengine configuration
        $configFile = Join-Path $Config.paths.tdengine "cfg\taos.cfg"
        $dataDir = "C:\TDengine\data"  # Default
        
        if (Test-Path $configFile) {
            $configContent = Get-Content $configFile -ErrorAction SilentlyContinue
            $dataDirLine = $configContent | Where-Object { $_ -match '^\s*dataDir\s+' }
            if ($dataDirLine) {
                $dataDir = ($dataDirLine -split '\s+')[1].Trim()
            }
        }
        
        # Get disk information
        $driveLetter = $dataDir.Substring(0, 1)
        $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='${driveLetter}:'"
        
        if ($disk) {
            $totalGB = [math]::Round($disk.Size / 1GB, 2)
            $freeGB = [math]::Round($disk.FreeSpace / 1GB, 2)
            $usedGB = [math]::Round(($disk.Size - $disk.FreeSpace) / 1GB, 2)
            $usedPercent = [math]::Round((($disk.Size - $disk.FreeSpace) / $disk.Size) * 100, 2)
            
            $result.Data = @{
                "Data Directory" = $dataDir
                "Drive" = "${driveLetter}:"
                "File System" = $disk.FileSystem
                "Total Space (GB)" = $totalGB
                "Used Space (GB)" = $usedGB
                "Free Space (GB)" = $freeGB
                "Used Percentage" = "$usedPercent%"
                "Volume Name" = $disk.VolumeName
            }
            
            $result.Details += "Data Directory: $dataDir"
            $result.Details += "Drive: ${driveLetter}: ($($disk.FileSystem))"
            $result.Details += "Total: ${totalGB} GB"
            $result.Details += "Used: ${usedGB} GB ($usedPercent%)"
            $result.Details += "Free: ${freeGB} GB"
            
            # Check thresholds
            $warningThreshold = $Config.thresholds.diskUsageWarning
            $criticalThreshold = $Config.thresholds.diskUsageCritical
            
            if ($usedPercent -ge $criticalThreshold) {
                $result.Status = "Critical"
                $result.Issues += "CRITICAL: Disk usage ($usedPercent%) exceeds critical threshold ($criticalThreshold%)"
            } elseif ($usedPercent -ge $warningThreshold) {
                $result.Status = "Warning"
                $result.Issues += "WARNING: Disk usage ($usedPercent%) exceeds warning threshold ($warningThreshold%)"
            }
        } else {
            $result.Status = "Critical"
            $result.Issues += "Could not find disk information for drive ${driveLetter}:"
        }
        
    } catch {
        $result.Status = "Critical"
        $result.Issues += "Failed to retrieve data directory information: $_"
    }
    
    return $result
}

