# Module 26: Database Measure Points
# Checks: Total measure points (columns-1) per database

function Get-MeasurePoints {
    param(
        [object]$Config
    )
    
    $result = @{
        Name = "Database Measure Points"
        Status = "Pass"
        Data = @{}
        Issues = @()
        Details = @()
    }
    
    try {
        $pointResult = Invoke-TDengineQuery -Sql "SELECT db_name, sum(columns-1) FROM information_schema.ins_tables WHERE db_name not in ('log','audit','information_schema','performance_schema') GROUP BY db_name" -Config $Config
        
        if ($pointResult.code -eq 0 -and $pointResult.data) {
            $dbPoints = @()
            $totalPoints = 0
            $maxDb = ""
            $maxPoints = 0
            
            foreach ($row in $pointResult.data) {
                $dbName = if ($row.db_name) { $row.db_name } else { "Unknown" }
                $points = if ($row.'sum(columns-1)') { [int]$row.'sum(columns-1)' } else { 0 }
                
                $dbPoints += @{
                    "Database" = $dbName
                    "Measure Points" = $points
                }
                $totalPoints += $points
                
                if ($points -gt $maxPoints) {
                    $maxPoints = $points
                    $maxDb = $dbName
                }
            }
            
            $result.Data = @{
                "Total Measure Points" = $totalPoints
                "Database Count" = $dbPoints.Count
                "Database List" = $dbPoints
            }
            
            $result.Details += "Database Measure Points Usage"
            $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
            $result.Details += "Total Measure Points: $totalPoints"
            $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
            $result.Details += ""
            $result.Details += "Measure Points by Database:"
            $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
            $result.Details += "{0,-25} {1}" -f "Database", "Measure Points"
            $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
            
            foreach ($dp in $dbPoints | Sort-Object 'Measure Points' -Descending) {
                $result.Details += "{0,-25} {1}" -f $dp.Database, $dp.'Measure Points'
            }
            $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
            
        } else {
            $result.Status = "Warning"
            $result.Issues += "Failed to query measure point information"
        }
        
    } catch {
        $result.Status = "Warning"
        $result.Issues += "Failed to retrieve measure point information: $($_.Exception.Message)"
    }
    
    return $result
}
