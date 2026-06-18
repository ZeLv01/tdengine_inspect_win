# Module 11: Super Table Summary Statistics
# Checks: Normal columns, tag columns, column width, nchar width, varchar width, non-char width, subtable count
# Note: Excludes system databases (log, audit, information_schema, performance_schema)

function Get-StableStatistics {
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
        # Get super table information
        $stableResult = Invoke-TDengineQuery -Sql "SELECT * FROM information_schema.ins_stables" -Config $Config
        
        if ($stableResult.code -eq 0 -and $stableResult.data) {
            $stableStats = @()
            $systemDbs = @("log", "audit", "information_schema", "performance_schema")
            
            foreach ($stable in $stableResult.data) {
                $dbName = if ($stable.db_name) { $stable.db_name } else { "Unknown" }
                $stableName = if ($stable.stable_name) { $stable.stable_name } else { "Unknown" }
                $ntables = if ($stable.ntables) { $stable.ntables } else { 0 }
                
                # Skip system databases
                if ($dbName -in $systemDbs) {
                    continue
                }
                
                # Get column details
                try {
                    $edb = "``$dbName``"
                    $est = "``$stableName``"
                    $sql = "DESCRIBE ${edb}.${est}"
                    $colResult = Invoke-TDengineQuery -Sql $sql -Config $Config
                    
                    $normalCols = 0
                    $tagCols = 0
                    $totalColWidth = 0
                    $ncharWidth = 0
                    $varcharWidth = 0
                    $nonCharWidth = 0
                    
                    if ($colResult.code -eq 0 -and $colResult.data) {
                        foreach ($col in $colResult.data) {
                            $colType = if ($col.type) { $col.type.ToString().ToUpper() } else { "" }
                            $colLength = 0
                            if ($col.length) { $colLength = [int]$col.length }
                            
                            if ($colType -eq "TAG") {
                                $tagCols++
                            } else {
                                $normalCols++
                            }
                            
                            # Calculate widths
                            if ($colType -match "NCHAR|NVARCHAR") {
                                $ncharWidth += $colLength
                                $totalColWidth += $colLength
                            } elseif ($colType -match "VARCHAR|BINARY") {
                                $varcharWidth += $colLength
                                $totalColWidth += $colLength
                            } else {
                                $nonCharWidth += $colLength
                                $totalColWidth += $colLength
                            }
                        }
                    }
                    
                    $stableStats += @{
                        "Database" = $dbName
                        "Stable Name" = $stableName
                        "Normal Columns" = $normalCols
                        "Tag Columns" = $tagCols
                        "Total Column Width" = $totalColWidth
                        "NCHAR Width" = $ncharWidth
                        "VARCHAR Width" = $varcharWidth
                        "Non-Char Width" = $nonCharWidth
                        "Subtable Count" = $ntables
                    }
                    
                } catch {
                    $errMsg = $_.Exception.Message
                    if ($errMsg -notmatch "Table does not exist") {
                        Write-Warning "Failed to get details for stable ${dbName}.${stableName}: $errMsg"
                    }
                }
            }
            
            $result.Data = @{
                "Total Stables" = $stableStats.Count
                "Statistics" = $stableStats
            }
            
            $result.Details += "Super Table Statistics Summary (User Databases Only)"
            $result.Details += "Total Super Tables: $($stableStats.Count)"
            $result.Details += ""
            
            if ($stableStats.Count -gt 0) {
                $result.Details += "Detailed Statistics:"
                $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
                $result.Details += "{0,-25} {1,-30} {2,-8} {3,-8} {4,-10} {5,-10} {6,-10} {7,-10} {8,-10}" -f "Database", "Stable Name", "Cols", "Tags", "Width", "NCHAR", "VARCHAR", "NonChar", "SubTables"
                $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
                
                foreach ($stat in $stableStats) {
                    $result.Details += "{0,-25} {1,-30} {2,-8} {3,-8} {4,-10} {5,-10} {6,-10} {7,-10} {8,-10}" -f $stat.Database, $stat.'Stable Name', $stat.'Normal Columns', $stat.'Tag Columns', $stat.'Total Column Width', $stat.'NCHAR Width', $stat.'VARCHAR Width', $stat.'Non-Char Width', $stat.'Subtable Count'
                }
                $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
            } else {
                $result.Details += "No user super tables found."
            }
            
        } else {
            $result.Status = "Warning"
            $result.Issues += "No super tables found"
        }
        
    } catch {
        $result.Status = "Critical"
        $result.Issues += "Failed to retrieve super table statistics: $($_.Exception.Message)"
    }
    
    return $result
}
