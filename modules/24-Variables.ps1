# Module 24: Database Variables
# Shows: TDengine configuration parameters via SHOW VARIABLES

function Get-DatabaseVariables {
    param(
        [object]$Config
    )
    
    $result = @{
        Name = "Database Variables"
        Status = "Pass"
        Data = @{}
        Issues = @()
        Details = @()
    }
    
    try {
        # Try SHOW CLUSTER VARIABLES (3.0+) first, fallback to SHOW VARIABLES
        $varResult = $null
        $querySuccess = $false
        
        try {
            $varResult = Invoke-TDengineQuery -Sql "SHOW CLUSTER VARIABLES" -Config $Config
            if ($varResult.code -eq 0 -and $varResult.data -and $varResult.data.Count -gt 0) {
                $querySuccess = $true
            }
        } catch { }
        
        if (-not $querySuccess) {
            try {
                $varResult = Invoke-TDengineQuery -Sql "SHOW VARIABLES" -Config $Config
                if ($varResult.code -eq 0 -and $varResult.data -and $varResult.data.Count -gt 0) {
                    $querySuccess = $true
                }
            } catch { }
        }
        
        $result.Details += "TDengine Configuration Variables"
        $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
        
        if ($querySuccess) {
            $result.Details += "{0,-35} {1}" -f "Variable Name", "Value"
            $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
            
            foreach ($row in $varResult.data) {
                $name = if ($row.name) { $row.name } elseif ($row.'name') { $row.'name' } else { "N/A" }
                $value = if ($row.value) { $row.value } elseif ($row.'value') { $row.'value' } else { "N/A" }
                $result.Details += "{0,-35} {1}" -f $name, $value
            }
            $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
            $result.Data["Variable Count"] = $varResult.data.Count
        } else {
            $result.Details += "SHOW VARIABLES not available via WebSocket"
            $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
        }
        
    } catch {
        $result.Status = "Warning"
        $result.Issues += "Failed to retrieve database variables: $($_.Exception.Message)"
    }
    
    return $result
}
