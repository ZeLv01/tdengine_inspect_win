# Module 08: Database List
# Checks: Lists all defined database names including log and audit databases

function Get-DatabaseList {
    param(
        [object]$Config
    )
    
    $result = @{
        Name = "Database List"
        Status = "Pass"
        Data = @{}
        Issues = @()
        Details = @()
    }
    
    try {
        # Query database information using information_schema for more details
        $dbResult = Invoke-TDengineQuery -Sql "SELECT * FROM information_schema.ins_databases" -Config $Config
        
        if ($dbResult.code -eq 0 -and $dbResult.data) {
            $dbList = @()
            $systemDbs = @()
            $userDbs = @()
            $hasLogDb = $false
            $hasAuditDb = $false
            
            foreach ($db in $dbResult.data) {
                $dbName = if ($db.name) { $db.name } else { "Unknown" }
                
                $dbInfo = @{
                    "Name" = $dbName
                    "Replica" = if ($db.replica) { $db.replica } else { 0 }
                    "Duration" = if ($db.duration) { $db.duration } else { "N/A" }
                    "Keep" = if ($db.keep) { $db.keep } else { "N/A" }
                    "Tables" = if ($db.ntables) { $db.ntables } else { 0 }
                    "Status" = if ($db.status) { $db.status } else { "N/A" }
                    "Vgroups" = if ($db.vgroups) { $db.vgroups } else { 0 }
                }
                $dbList += $dbInfo
                
                # Categorize databases
                if ($dbName -eq "log" -or $dbName -eq "audit") {
                    $systemDbs += $dbInfo
                    if ($dbName -eq "log") { $hasLogDb = $true }
                    if ($dbName -eq "audit") { $hasAuditDb = $true }
                } elseif ($dbName -notin @("information_schema", "performance_schema")) {
                    $userDbs += $dbInfo
                }
            }
            
            $result.Data = @{
                "Total Databases" = $dbList.Count
                "System Databases" = $systemDbs
                "User Databases" = $userDbs
                "Has Log Database" = $hasLogDb
                "Has Audit Database" = $hasAuditDb
                "All Databases" = $dbList
            }
            
            $result.Details += "Total Databases: $($dbList.Count)"
            $result.Details += "User Databases: $($userDbs.Count)"
            $result.Details += ""
            $result.Details += "Database List:"
            $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
            $result.Details += "{0,-30} {1,-8} {2,-25} {3,-25} {4,-8} {5,-8} {6,-10}" -f "Name", "Replica", "Duration", "Keep", "Tables", "Vgroups", "Status"
            $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
            
            foreach ($db in $dbList) {
                $type = if ($db.Name -in @("log", "audit")) { "*" } 
                       elseif ($db.Name -in @("information_schema", "performance_schema")) { "#" }
                       else { " " }
                $result.Details += "{0,-30} {1,-8} {2,-25} {3,-25} {4,-8} {5,-8} {6,-10}" -f "$type$($db.Name)", $db.Replica, $db.Duration, $db.Keep, $db.Tables, $db.Vgroups, $db.Status
            }
            $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
            $result.Details += ""
            $result.Details += "Note: * = System DB, # = Meta DB, (space) = User DB"
            
            # Check for log database
            if (-not $hasLogDb) {
                $result.Status = "Warning"
                $result.Issues += "System 'log' database not found. TDengine logging may not be configured."
            }
            
        } else {
            # Fallback to SHOW DATABASES
            $dbResult = Invoke-TDengineQuery -Sql "SHOW DATABASES" -Config $Config
            
            if ($dbResult.code -eq 0 -and $dbResult.data) {
                $result.Details += "Database List (basic info):"
                foreach ($db in $dbResult.data) {
                    $dbName = if ($db.name) { $db.name } else { "Unknown" }
                    $result.Details += "  - $dbName"
                }
            } else {
                $result.Status = "Critical"
                $result.Issues += "Failed to query database list"
            }
        }
        
    } catch {
        $result.Status = "Critical"
        $result.Issues += "Failed to retrieve database list: $($_.Exception.Message)"
    }
    
    return $result
}
