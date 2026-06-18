# Module 13: Disk Usage Check
# Checks: Disk used space below 15% free threshold

function Get-DiskUsageInfo {
    param(
        [object]$Config
    )
    
    $result = @{
        Name = "Disk Usage Check"
        Status = "Pass"
        Data = @{}
        Issues = @()
        Details = @()
    }
    
    try {
        # Get all local disks
        $disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"
        
        $diskList = @()
        $warningDisks = @()
        $criticalDisks = @()
        
        foreach ($disk in $disks) {
            $totalGB = [math]::Round($disk.Size / 1GB, 2)
            $freeGB = [math]::Round($disk.FreeSpace / 1GB, 2)
            $usedGB = [math]::Round(($disk.Size - $disk.FreeSpace) / 1GB, 2)
            $usedPercent = [math]::Round((($disk.Size - $disk.FreeSpace) / $disk.Size) * 100, 2)
            $freePercent = [math]::Round(($disk.FreeSpace / $disk.Size) * 100, 2)
            
            $diskInfo = @{
                "Drive" = $disk.DeviceID
                "Volume Name" = $disk.VolumeName
                "File System" = $disk.FileSystem
                "Total (GB)" = $totalGB
                "Used (GB)" = $usedGB
                "Free (GB)" = $freeGB
                "Used %" = "$usedPercent%"
                "Free %" = "$freePercent%"
            }
            $diskList += $diskInfo
            
            # Check thresholds (15% free = 85% used)
            if ($usedPercent -ge 95) {
                $criticalDisks += "$($disk.DeviceID) ($freePercent% free)"
            } elseif ($usedPercent -ge 85) {
                $warningDisks += "$($disk.DeviceID) ($freePercent% free)"
            }
        }
        
        $result.Data = @{
            "Total Disks" = $diskList.Count
            "Disk List" = $diskList
            "Warning Disks" = $warningDisks
            "Critical Disks" = $criticalDisks
        }
        
        $result.Details += "Disk Usage Summary"
        $result.Details += "Total Disks: $($diskList.Count)"
        $result.Details += ""
        
        foreach ($disk in $diskList) {
            $freePercent = [double]($disk.'Free %' -replace '%', '')
            $icon = if ($freePercent -lt 5) { "[CRITICAL]" } 
                   elseif ($freePercent -lt 15) { "[WARNING]" }
                   else { "[OK]" }
            $result.Details += "  $icon $($disk.Drive) ($($disk.'Volume Name')): Used=$($disk.'Used %') Free=$($disk.'Free %') | $($disk.'Used (GB)')GB / $($disk.'Total (GB)')GB"
        }
        
        # Report issues
        if ($criticalDisks.Count -gt 0) {
            $result.Status = "Critical"
            $result.Issues += "CRITICAL: Disks with less than 5% free space: $($criticalDisks -join ', ')"
        }
        
        if ($warningDisks.Count -gt 0) {
            $result.Status = "Warning"
            $result.Issues += "WARNING: Disks with less than 15% free space: $($warningDisks -join ', ')"
        }
        
    } catch {
        $result.Status = "Critical"
        $result.Issues += "Failed to retrieve disk usage information: $_"
    }
    
    return $result
}

