# Module 01: Operating System Information
# Checks: System name, version, kernel version, system startup time

function Get-SystemInfo {
    param(
        [object]$Config
    )
    
    $result = @{
        Name = "Operating System Information"
        Status = "Pass"
        Data = @{}
        Issues = @()
        Details = @()
    }
    
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        
        $result.Data = @{
            "System Name" = $os.Caption
            "System Version" = $os.Version
            "Build Number" = $os.BuildNumber
            "OS Architecture" = $os.OSArchitecture
            "System Drive" = $os.SystemDrive
            "Windows Directory" = $os.WindowsDirectory
            "Last Boot Time" = $os.LastBootUpTime.ToString("yyyy-MM-dd HH:mm:ss")
            "Uptime (Days)" = [math]::Round(((Get-Date) - $os.LastBootUpTime).TotalDays, 2)
        }
        
        $result.Details += "System: $($os.Caption)"
        $result.Details += "Version: $($os.Version) (Build $($os.BuildNumber))"
        $result.Details += "Architecture: $($os.OSArchitecture)"
        $result.Details += "Last Boot: $($os.LastBootUpTime.ToString('yyyy-MM-dd HH:mm:ss'))"
        
        # Check if system has been running for too long (30+ days)
        $uptimeDays = ((Get-Date) - $os.LastBootUpTime).TotalDays
        if ($uptimeDays -gt 30) {
            $result.Status = "Warning"
            $result.Issues += "System has been running for $([math]::Round($uptimeDays, 0)) days. Consider scheduling a reboot."
        }
        
    } catch {
        $result.Status = "Critical"
        $result.Issues += "Failed to retrieve system information: $_"
    }
    
    return $result
}

