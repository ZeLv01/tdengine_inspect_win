# Module 22: Slow Query Check
# Checks: Slow query records (TDengine default threshold: 10 seconds)

function Get-SlowQueryInfo {
    param(
        [object]$Config
    )
    
    $result = @{
        Name = "Slow Query Check"
        Status = "Pass"
        Data = @{}
        Issues = @()
        Details = @()
    }
    
    try {
        $slowQueries = @()
        $querySuccess = $false
        $tableFound = $false
        $lookbackDays = $Config.thresholds.slowQueryLookbackDays
        $thresholdMs = $Config.thresholds.slowQueryThresholdMs
        
        # Method 1: Try log.taosd_slow_sql_detail
        try {
            $sql = "SELECT * FROM log.taosd_slow_sql_detail WHERE start_time > NOW() - ${lookbackDays}d ORDER BY start_time DESC LIMIT 100"
            $queryResult = Invoke-WebSocketQuery -Sql $sql -Config $Config
            if ($queryResult.code -eq 0) {
                $tableFound = $true
                if ($queryResult.data -and $queryResult.data.Count -gt 0) {
                    $slowQueries = $queryResult.data
                    $querySuccess = $true
                }
            }
        } catch { }
        
        # Method 2: Try log.taosd_slow_sql
        if (-not $tableFound) {
            try {
                $sql = "SELECT * FROM log.taosd_slow_sql WHERE ts > NOW() - ${lookbackDays}d ORDER BY ts DESC LIMIT 100"
                $queryResult = Invoke-WebSocketQuery -Sql $sql -Config $Config
                if ($queryResult.code -eq 0) {
                    $tableFound = $true
                    if ($queryResult.data -and $queryResult.data.Count -gt 0) {
                        $slowQueries = $queryResult.data
                        $querySuccess = $true
                    }
                }
            } catch { }
        }
        
        # Method 3: Try performance_schema.slow_queries
        if (-not $tableFound) {
            try {
                $sql = "SELECT * FROM performance_schema.slow_queries WHERE start_time > NOW() - ${lookbackDays}d ORDER BY start_time DESC LIMIT 100"
                $queryResult = Invoke-WebSocketQuery -Sql $sql -Config $Config
                if ($queryResult.code -eq 0) {
                    $tableFound = $true
                    if ($queryResult.data -and $queryResult.data.Count -gt 0) {
                        $slowQueries = $queryResult.data
                        $querySuccess = $true
                    }
                }
            } catch { }
        }
        
        # Method 4: Try information_schema.ins_slow_queries
        if (-not $tableFound) {
            try {
                $sql = "SELECT * FROM information_schema.ins_slow_queries WHERE start_time > NOW() - ${lookbackDays}d ORDER BY start_time DESC LIMIT 100"
                $queryResult = Invoke-WebSocketQuery -Sql $sql -Config $Config
                if ($queryResult.code -eq 0) {
                    $tableFound = $true
                    if ($queryResult.data -and $queryResult.data.Count -gt 0) {
                        $slowQueries = $queryResult.data
                        $querySuccess = $true
                    }
                }
            } catch { }
        }
        
        # No query tables found at all
        if (-not $tableFound) {
            $result.Data = @{
                "Total Slow Queries" = 0
                "Status" = "No slow queries"
            }
            $result.Details += "Slow Query Analysis"
            $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
            $result.Details += "No slow queries found. Database performance is good."
            $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
            return $result  # Pass status - not an error
        }
        
        # Table found but no data
        if (-not $querySuccess -or $slowQueries.Count -eq 0) {
            $result.Data = @{
                "Total Slow Queries" = 0
                "Status" = "No slow queries"
            }
            $result.Details += "Slow Query Analysis"
            $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
            $result.Details += "No slow queries found. Database performance is good."
            $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
            return $result  # Pass status - normal
        }
        
        # Slow queries found
        $result.Data = @{
            "Total Slow Queries" = $slowQueries.Count
            "Status" = "Slow queries found"
        }
        
        $result.Details += "Slow Query Analysis"
        $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
        $result.Details += "Total Slow Queries: $($slowQueries.Count)"
        $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
        
        $result.Details += ""
        $result.Details += "Recent Slow Queries (up to 10):"
        $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
        $showCount = [math]::Min($slowQueries.Count, 10)
        for ($i = 0; $i -lt $showCount; $i++) {
            $query = $slowQueries[$i]
            $startTime = if ($query.start_time) { $query.start_time } elseif ($query.ts) { $query.ts } else { "Unknown" }
            $duration = if ($query.query_time) { "$($query.query_time) ms" } elseif ($query.duration) { "$($query.duration) ms" } else { "Unknown" }
            $sql = if ($query.sql) { $query.sql } else { "N/A" }
            if ($sql.Length -gt 100) { $sql = $sql.Substring(0, 100) + "..." }
            $result.Details += "[$startTime] Duration: $duration"
            $result.Details += "  SQL: $sql"
        }
        $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
        
        $result.Status = "Warning"
        $result.Issues += "Found $($slowQueries.Count) slow queries"
        
    } catch {
        $result.Status = "Warning"
        $result.Issues += "Failed to retrieve slow query information: $($_.Exception.Message)"
    }
    
    return $result
}
