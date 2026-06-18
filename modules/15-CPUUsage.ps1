# Module 14: CPU Usage Check
# Checks: Current CPU usage

function Get-CPUUsageInfo {
    param(
        [object]$Config
    )
    
    $result = @{
        Name = "CPU Usage Check"
        Status = "Pass"
        Data = @{}
        Issues = @()
        Details = @()
    }
    
    try {
        # Get current CPU usage (quick check)
        $cpuUsage = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
        
        # Get per-core CPU usage
        $cpuCores = Get-CimInstance Win32_Processor | Select-Object Name, LoadPercentage
        
        $highUsageThreshold = $Config.thresholds.cpuUsageWarning
        
        $result.Data = @{
            "Current CPU Usage" = "$cpuUsage%"
            "High Usage Threshold" = "$highUsageThreshold%"
            "CPU Cores" = $cpuCores | ForEach-Object { 
                @{
                    "Name" = $_.Name
                    "Load" = "$($_.LoadPercentage)%"
                }
            }
        }
        
        $result.Details += "CPU Usage Summary"
        $result.Details += "Current Overall Usage: $cpuUsage%"
        $result.Details += "Threshold: $highUsageThreshold%"
        $result.Details += ""
        $result.Details += "CPU Core Details:"
        
        foreach ($core in $cpuCores) {
            $icon = if ($core.LoadPercentage -ge $highUsageThreshold) { "[HIGH]" } else { "[OK]" }
            $result.Details += "  $icon $($core.Name): $($core.LoadPercentage)%"
        }
        
        # Check if CPU usage exceeds threshold
        if ($cpuUsage -ge $highUsageThreshold) {
            $result.Status = "Warning"
            $result.Issues += "Current CPU usage ($cpuUsage%) exceeds threshold ($highUsageThreshold%)"
        }
        
    } catch {
        $result.Status = "Warning"
        $result.Issues += "Failed to retrieve CPU usage information: $($_.Exception.Message)"
    }
    
    return $result
}
