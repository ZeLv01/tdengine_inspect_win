# Module 09: Database Create Statements
# Retrieves: Database creation SQL statements

function Get-DatabaseCreateStatements {
    param(
        [object]$Config
    )
    
    $result = @{
        Name = "Database Create Statements"
        Status = "Pass"
        Data = @{}
        Issues = @()
        Details = @()
    }
    
    try {
        # First get all databases from information_schema (same as DatabaseList)
        $dbResult = Invoke-TDengineQuery -Sql "SELECT * FROM information_schema.ins_databases" -Config $Config
        
        if ($dbResult.code -eq 0 -and $dbResult.data) {
            $createStatements = @{}
            
            foreach ($db in $dbResult.data) {
                $dbName = if ($db.name -and $db.name -ne "") { $db.name } else { continue }
                
                # Skip system meta databases
                if ($dbName -in @("information_schema", "performance_schema")) {
                    continue
                }
                
                try {
                    $escapedName = "``$dbName``"
                    $sql = "SHOW CREATE DATABASE $escapedName"
                    $createResult = Invoke-TDengineQuery -Sql $sql -Config $Config
                    if ($createResult.code -eq 0 -and $createResult.data -and $createResult.data.Count -gt 0) {
                        # Handle different response formats
                        $createSql = $null
                        if ($createResult.data[0].'Create Database') {
                            $createSql = $createResult.data[0].'Create Database'
                        } elseif ($createResult.data[0].'Create Database') {
                            $createSql = $createResult.data[0].'Create Database'
                        } elseif ($createResult.data[0] -is [PSCustomObject]) {
                            # Try first property
                            $props = $createResult.data[0].PSObject.Properties
                            if ($props.Count -gt 0) {
                                $createSql = $props[0].Value
                            }
                        }
                        
                        if ($createSql) {
                            $createStatements[$dbName] = $createSql
                        }
                    }
                } catch {
                    Write-Warning "Failed to get create statement for database $dbName : $($_.Exception.Message)"
                }
            }
            
            $result.Data = @{
                "Database Count" = $createStatements.Count
                "Create Statements" = $createStatements
            }
            
            $result.Details += "Retrieved create statements for $($createStatements.Count) databases"
            $result.Details += ""
            
            foreach ($dbName in $createStatements.Keys) {
                $result.Details += "=== $dbName ==="
                $result.Details += $createStatements[$dbName]
                $result.Details += ""
            }
            
        } else {
            $result.Status = "Critical"
            $result.Issues += "Failed to query database list"
        }
        
    } catch {
        $result.Status = "Critical"
        $result.Issues += "Failed to retrieve database create statements: $($_.Exception.Message)"
    }
    
    return $result
}
