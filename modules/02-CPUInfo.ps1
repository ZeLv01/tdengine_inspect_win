# Module 02: CPU Information
# Checks: CPU model, architecture, core count

function Get-CPUInfo {
    param(
        [object]$Config
    )
    
    $result = @{
        Name = "CPU Information"
        Status = "Pass"
        Data = @{}
        Issues = @()
        Details = @()
    }
    
    try {
        # Get CPU information
        $cpu = Get-CimInstance Win32_Processor
        
        $result.Data = @{
            "CPU Name" = $cpu.Name.Trim()
            "CPU Manufacturer" = $cpu.Manufacturer
            "CPU Architecture" = switch ($cpu.Architecture) {
                0 { "x86" }
                9 { "x64" }
                12 { "ARM64" }
                default { "Unknown ($($cpu.Architecture))" }
            }
            "Physical Cores" = $cpu.NumberOfCores
            "Logical Processors" = $cpu.NumberOfLogicalProcessors
            "Max Clock Speed (MHz)" = $cpu.MaxClockSpeed
        }
        
        $result.Details += "CPU Information"
        $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
        $result.Details += "{0,-25} {1}" -f "CPU Name", $cpu.Name.Trim()
        $result.Details += "{0,-25} {1}" -f "Manufacturer", $cpu.Manufacturer
        $result.Details += "{0,-25} {1}" -f "Architecture", $(switch ($cpu.Architecture) { 0 {"x86"} 9 {"x64"} 12 {"ARM64"} default {"Unknown"} })
        $result.Details += "{0,-25} {1}" -f "Physical Cores", $cpu.NumberOfCores
        $result.Details += "{0,-25} {1}" -f "Logical Processors", $cpu.NumberOfLogicalProcessors
        $result.Details += "{0,-25} {1}" -f "Max Clock Speed", "$($cpu.MaxClockSpeed) MHz"
        $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
        
        # Check if CPU cores are sufficient (recommend at least 4)
        if ($cpu.NumberOfCores -lt 4) {
            $result.Status = "Warning"
            $result.Issues += "System has only $($cpu.NumberOfCores) CPU cores. Recommend at least 4 cores for TDengine."
        }
        
    } catch {
        $result.Status = "Critical"
        $result.Issues += "Failed to retrieve CPU information: $_"
    }
    
    return $result
}
