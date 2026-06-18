# Module 10: Super Table Summary Statistics
# Retrieves: Super table count by database

function Get-StableCreateStatements {
    param(
        [object]$Config
    )
    
    $result = @{
        Name = "Super Table Summary Statistics"
        Status = "Pass"
        Data = @{}
        Issues = @()
        Details = @()
    }
    
    try {
        # Get super table count by database
        $stableResult = Invoke-TDengineQuery -Sql "SELECT db_name, count(*) as stable_count FROM information_schema.ins_stables GROUP BY db_name" -Config $Config
        
        if ($stableResult.code -eq 0 -and $stableResult.data) {
            $dbStats = @()
            $totalCount = 0
            $systemDbs = @("log", "audit", "information_schema", "performance_schema")
            
            foreach ($row in $stableResult.data) {
                $dbName = if ($row.db_name) { $row.db_name } else { "Unknown" }
                $count = if ($row.stable_count) { [int]$row.stable_count } else { 0 }
                
                # Skip system databases for summary
                $isSystem = $dbName -in $systemDbs
                
                $dbStats += @{
                    "Database" = $dbName
                    "Stable Count" = $count
                    "Is System" = $isSystem
                }
                
                if (-not $isSystem) {
                    $totalCount += $count
                }
            }
            
            $result.Data = @{
                "Total User Stables" = $totalCount
                "Database Statistics" = $dbStats
            }
            
            $result.Details += "Super Table Summary Statistics"
            $result.Details += "Total User Super Tables: $totalCount"
            $result.Details += ""
            $result.Details += "Super Tables by Database:"
            $result.Details += "-" * 50
            $result.Details += "{0,-30} {1,-15}" -f "Database", "Stable Count"
            $result.Details += "-" * 50
            
            foreach ($stat in $dbStats | Sort-Object -Property 'Stable Count' -Descending) {
                $type = if ($stat.'Is System') { "*" } else { " " }
                $result.Details += "{0,-30} {1,-15}" -f "$type$($stat.Database)", $stat.'Stable Count'
            }
            
            $result.Details += ""
            $result.Details += "Note: * = System DB (excluded from total)"
            
        } else {
            $result.Status = "Warning"
            $result.Issues += "No super tables found or failed to query"
        }
        
    } catch {
        $result.Status = "Critical"
        $result.Issues += "Failed to retrieve super table statistics: $($_.Exception.Message)"
    }
    
    return $result
}
