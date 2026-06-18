# Module 03: Memory Information
# Checks: Server memory usage

function Get-MemoryInfo {
    param(
        [object]$Config
    )
    
    $result = @{
        Name = "Memory Information"
        Status = "Pass"
        Data = @{}
        Issues = @()
        Details = @()
    }
    
    try {
        # Get Memory information
        $os = Get-CimInstance Win32_OperatingSystem
        $totalMemoryGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
        $freeMemoryGB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
        $usedMemoryGB = [math]::Round($totalMemoryGB - $freeMemoryGB, 2)
        $memoryUsagePercent = [math]::Round(($usedMemoryGB / $totalMemoryGB) * 100, 2)
        
        $result.Data = @{
            "Total Memory (GB)" = $totalMemoryGB
            "Used Memory (GB)" = $usedMemoryGB
            "Free Memory (GB)" = $freeMemoryGB
            "Memory Usage %" = "$memoryUsagePercent%"
        }
        
        $result.Details += "Memory Information"
        $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
        $result.Details += "{0,-25} {1}" -f "Total Memory", "$totalMemoryGB GB"
        $result.Details += "{0,-25} {1}" -f "Used Memory", "$usedMemoryGB GB ($memoryUsagePercent%)"
        $result.Details += "{0,-25} {1}" -f "Free Memory", "$freeMemoryGB GB"
        $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
        
        # Check memory usage
        if ($memoryUsagePercent -ge 90) {
            $result.Status = "Critical"
            $result.Issues += "Memory usage is critically high: $memoryUsagePercent%"
        } elseif ($memoryUsagePercent -ge 80) {
            $result.Status = "Warning"
            $result.Issues += "Memory usage is high: $memoryUsagePercent%"
        }
        
    } catch {
        $result.Status = "Critical"
        $result.Issues += "Failed to retrieve memory information: $_"
    }
    
    return $result
}
