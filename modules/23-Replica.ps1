# Module 22: Database Replica Count
# Checks: Cluster replica count is less than 3

function Get-ReplicaInfo {
    param(
        [object]$Config
    )
    
    $result = @{
        Name = "Database Replica Count"
        Status = "Pass"
        Data = @{}
        Issues = @()
        Details = @()
    }
    
    try {
        # Query database information using information_schema for consistent column names
        $dbResult = Invoke-TDengineQuery -Sql "SELECT * FROM information_schema.ins_databases" -Config $Config
        
        if ($dbResult.code -eq 0 -and $dbResult.data) {
            $dbReplicas = @()
            $lowReplicaDbs = @()
            $expectedReplica = $Config.cluster.replica
            
            foreach ($db in $dbResult.data) {
                # Safe converter for field values
                function SafeInt($val) {
                    if ($val -eq $null) { return 1 }
                    $s = $val.ToString().Trim()
                    if ($s -eq 'NULL' -or $s -eq '' -or $s -eq 'N/A') { return 1 }
                    $result = 0
                    if ([int]::TryParse($s, [ref]$result)) { return $result }
                    return 1
                }
                function SafeStr($val) {
                    if ($val -eq $null) { return "N/A" }
                    $s = $val.ToString().Trim()
                    if ($s -eq 'NULL' -or $s -eq '') { return "N/A" }
                    return $s
                }
                
                $dbName = SafeStr $(if ($db -is [PSCustomObject]) { $db.name } else { $db['name'] })
                if ($dbName -eq "N/A" -or [string]::IsNullOrEmpty($dbName)) { $dbName = "Unknown" }
                
                # Skip system databases
                if ($dbName -in @("information_schema", "performance_schema", "log", "audit")) { continue }
                
                $replica = SafeInt $(if ($db -is [PSCustomObject]) { $db.replica } else { $db['replica'] })
                $duration = SafeStr $(if ($db -is [PSCustomObject]) { $db.duration } else { $db['duration'] })
                $keep = SafeStr $(if ($db -is [PSCustomObject]) { $db.keep } else { $db['keep'] })
                $tables = SafeInt $(if ($db -is [PSCustomObject]) { $db.ntables } else { $db['ntables'] })
                $status = SafeStr $(if ($db -is [PSCustomObject]) { $db.status } else { $db['status'] })
                
                $dbInfo = @{
                    "Database" = $dbName
                    "Replica" = $replica
                    "Duration" = $duration
                    "Keep" = $keep
                    "Tables" = $tables
                    "Status" = $status
                }
                $dbReplicas += $dbInfo
                
                # Check if replica is less than expected
                if ($replica -lt $expectedReplica) {
                    $lowReplicaDbs += $dbInfo
                }
            }
            
            $result.Data = @{
                "Total Databases" = $dbReplicas.Count
                "Expected Replica" = $expectedReplica
                "Database Replicas" = $dbReplicas
                "Low Replica Databases" = $lowReplicaDbs
            }
            
            $result.Details += "Database Replica Analysis"
            $result.Details += "Expected Replica Count: $expectedReplica"
            $result.Details += "Total User Databases: $($dbReplicas.Count)"
            $result.Details += ""
            
            if ($dbReplicas.Count -gt 0) {
                $result.Details += "Database Replica Details:"
                foreach ($db in $dbReplicas) {
                    $icon = if ($db.Replica -ge $expectedReplica) { "[OK]" } else { "[LOW]" }
                    $result.Details += "  $icon $($db.Database): Replica=$($db.Replica) | Tables=$($db.Tables) | Status=$($db.Status)"
                }
                
                # Report low replica databases
                if ($lowReplicaDbs.Count -gt 0) {
                    $result.Status = "Warning"
                    $result.Issues += "Databases with replica count less than $expectedReplica :"
                    foreach ($db in $lowReplicaDbs) {
                        $result.Issues += "  - $($db.Database): $($db.Replica) replica(s)"
                    }
                }
                
                # Special warning for single replica (no HA)
                $singleReplicaDbs = $dbReplicas | Where-Object { $_.Replica -eq 1 }
                if ($singleReplicaDbs.Count -gt 0) {
                    $result.Details += ""
                    $result.Details += "WARNING: Single replica databases (no high availability):"
                    foreach ($db in $singleReplicaDbs) {
                        $result.Details += "  - $($db.Database)"
                    }
                }
            } else {
                $result.Details += "No user databases found."
            }
            
        } else {
            $result.Status = "Critical"
            $result.Issues += "Failed to query database information"
        }
        
    } catch {
        $result.Status = "Critical"
        $result.Issues += "Failed to retrieve replica information: $($_.Exception.Message)"
    }
    
    return $result
}
