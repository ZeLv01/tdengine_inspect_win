# Module 17: Database Service Status
# Checks: taosd, taosAdapter, taosKeeper, taosX, taos-explorer service status

function Get-ServiceStatus {
    param(
        [object]$Config
    )
    
    $result = @{
        Name = "Database Service Status"
        Status = "Pass"
        Data = @{}
        Issues = @()
        Details = @()
    }
    
    try {
        # Define TDengine services to check
        $services = @(
            @{ Name = "taosd"; DisplayName = "TDengine Server (taosd)" },
            @{ Name = "taosadapter"; DisplayName = "TDengine Adapter (taosAdapter)" },
            @{ Name = "taoskeeper"; DisplayName = "TDengine Keeper (taosKeeper)" },
            @{ Name = "taosx"; DisplayName = "TDengine X (taosX)" },
            @{ Name = "taos-explorer"; DisplayName = "TDengine Explorer (taos-explorer)" }
        )
        
        $serviceStatus = @()
        $stoppedServices = @()
        $runningServices = @()
        
        foreach ($svc in $services) {
            $service = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
            
            if ($service) {
                $status = @{
                    "Name" = $svc.Name
                    "Display Name" = $svc.DisplayName
                    "Status" = $service.Status
                    "Start Type" = $service.StartType
                }
                $serviceStatus += $status
                
                if ($service.Status -eq "Running") {
                    $runningServices += $svc.Name
                } else {
                    $stoppedServices += $svc.Name
                }
            } else {
                $serviceStatus += @{
                    "Name" = $svc.Name
                    "Display Name" = $svc.DisplayName
                    "Status" = "Not Installed"
                    "Start Type" = "N/A"
                }
            }
        }
        
        # Also check via process
        $processNames = @("taosd", "taosadapter", "taoskeeper", "taosx", "taos-explorer")
        $runningProcesses = @()
        
        foreach ($procName in $processNames) {
            $proc = Get-Process -Name $procName -ErrorAction SilentlyContinue
            if ($proc) {
                $runningProcesses += @{
                    "Name" = $procName
                    "PID" = $proc.Id
                    "Memory (MB)" = [math]::Round($proc.WorkingSet64 / 1MB, 2)
                    "CPU (s)" = [math]::Round($proc.CPU, 2)
                }
            }
        }
        
        $result.Data = @{
            "Services" = $serviceStatus
            "Running Services" = $runningServices
            "Stopped Services" = $stoppedServices
            "Running Processes" = $runningProcesses
        }
        
        $result.Details += "TDengine Service Status"
        $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
        $result.Details += "{0,-10} {1,-35} {2,-12} {3,-15}" -f "Status", "Service Name", "State", "Start Type"
        $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
        
        foreach ($svc in $serviceStatus) {
            $icon = switch ($svc.Status) {
                "Running" { "[OK]" }
                "Stopped" { "[STOP]" }
                "Not Installed" { "[N/A]" }
                default { "[??]" }
            }
            $result.Details += "{0,-10} {1,-35} {2,-12} {3,-15}" -f $icon, $svc.'Display Name', $svc.Status, $svc.'Start Type'
        }
        $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
        
        if ($runningProcesses.Count -gt 0) {
            $result.Details += ""
            $result.Details += "Running Processes:"
            foreach ($proc in $runningProcesses) {
                $result.Details += "  - $($proc.Name) (PID: $($proc.'PID'), Memory: $($proc.'Memory (MB)') MB)"
            }
        }
        
        # Report stopped services
        if ($stoppedServices.Count -gt 0) {
            $result.Status = "Warning"
            $result.Issues += "Stopped TDengine services: $($stoppedServices -join ', ')"
        }
        
        # Check if taosd is running (critical)
        if ("taosd" -in $stoppedServices) {
            $result.Status = "Critical"
            $result.Issues += "CRITICAL: taosd (TDengine Server) is not running"
        }
        
    } catch {
        $result.Status = "Critical"
        $result.Issues += "Failed to retrieve service status: $_"
    }
    
    return $result
}

