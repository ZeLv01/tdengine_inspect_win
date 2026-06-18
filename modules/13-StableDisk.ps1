# Module 12: Super Table Disk Distribution
# Checks: Super table disk distribution across vnodes (user databases only)

function Get-StableDiskDistribution {
    param(
        [object]$Config
    )
    
    $result = @{
        Name = "Super Table Disk Distribution"
        Status = "Pass"
        Data = @{}
        Issues = @()
        Details = @()
    }
    
    try {
        # Get super table information
        $stableResult = Invoke-TDengineQuery -Sql "SELECT * FROM information_schema.ins_stables" -Config $Config
        
        if ($stableResult.code -eq 0 -and $stableResult.data) {
            $diskDistribution = @()
            $systemDbs = @("log", "audit", "information_schema", "performance_schema")
            
            foreach ($stable in $stableResult.data) {
                $dbName = if ($stable.db_name) { $stable.db_name } else { "Unknown" }
                $stableName = if ($stable.stable_name) { $stable.stable_name } else { "Unknown" }
                
                # Skip system databases
                if ($dbName -in $systemDbs) {
                    continue
                }
                
                try {
                    # Get table distribution information
                    $edb = "``$dbName``"
                    $est = "``$stableName``"
                    $sql = "SHOW TABLE DISTRIBUTED ${edb}.${est}"
                    $distResult = Invoke-TDengineQuery -Sql $sql -Config $Config
                    
                    if ($distResult.code -eq 0 -and $distResult.data) {
                        $totalBlocks = 0
                        $totalSize = 0
                        $totalTables = 0
                        $totalVgroups = 0
                        $compressionRatio = "N/A"
                        
                        foreach ($row in $distResult.data) {
                            $blockDist = if ($row.'_block_dist') { $row.'_block_dist' } else { "" }
                            
                            if ($blockDist -match 'Total_Blocks=\[(\d+)\]') {
                                $totalBlocks = [int]$Matches[1]
                            }
                            if ($blockDist -match 'Total_Size=\[([^\]]+)\]') {
                                $totalSize = $Matches[1]
                            }
                            if ($blockDist -match 'Total_Tables=\[(\d+)\]') {
                                $totalTables = [int]$Matches[1]
                            }
                            if ($blockDist -match 'Total_Vgroups=\[(\d+)\]') {
                                $totalVgroups = [int]$Matches[1]
                            }
                            if ($blockDist -match 'Compression_Ratio=\[([^\]]+)\]') {
                                $compressionRatio = $Matches[1]
                            }
                        }
                        
                        $diskDistribution += @{
                            "Database" = $dbName
                            "Stable Name" = $stableName
                            "Total Blocks" = $totalBlocks
                            "Total Size" = $totalSize
                            "Total Tables" = $totalTables
                            "Total Vgroups" = $totalVgroups
                            "Compression Ratio" = $compressionRatio
                        }
                    }
                } catch {
                    $errMsg = $_.Exception.Message
                    if ($errMsg -notmatch "Table does not exist") {
                        Write-Warning "Failed to get disk distribution for stable ${dbName}.${stableName}: $errMsg"
                    }
                }
            }
            
            $result.Data = @{
                "Total Stables" = $diskDistribution.Count
                "Distribution" = $diskDistribution
            }
            
            $result.Details += "Super Table Disk Distribution (User Databases Only)"
            $result.Details += "Total Super Tables: $($diskDistribution.Count)"
            $result.Details += ""
            
            if ($diskDistribution.Count -gt 0) {
                $result.Details += "Distribution Details:"
                $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
                $result.Details += "{0,-25} {1,-25} {2,-8} {3,-16} {4,-8} {5,-8} {6}" -f "Database", "Stable Name", "Blocks", "Size", "Tables", "Vgroups", "Compression"
                $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
                
                foreach ($dist in $diskDistribution) {
                    $result.Details += "{0,-25} {1,-25} {2,-8} {3,-16} {4,-8} {5,-8} {6}" -f $dist.Database, $dist.'Stable Name', $dist.'Total Blocks', $dist.'Total Size', $dist.'Total Tables', $dist.'Total Vgroups', $dist.'Compression Ratio'
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
        $result.Issues += "Failed to retrieve super table disk distribution: $($_.Exception.Message)"
    }
    
    return $result
}
