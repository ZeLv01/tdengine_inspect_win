# Module 19: Database Error Logs
# Checks: ERROR logs in taos, taosd, and taosAdapter logs

function Get-ErrorLogInfo {
    param(
        [object]$Config
    )
    
    $result = @{
        Name = "Database Error Logs"
        Status = "Pass"
        Data = @{}
        Issues = @()
        Details = @()
    }
    
    try {
        $logPath = $Config.paths.log
        $errorLogs = @()
        $recentErrors = @()
        
        # Define log files to check
        $logFiles = @(
            @{ Name = "taosd"; Pattern = "taosdlog*.log*" },
            @{ Name = "taosadapter"; Pattern = "taosadapter*.log*" },
            @{ Name = "taos"; Pattern = "taoslog*.log*" },
            @{ Name = "taoskeeper"; Pattern = "taoskeeper*.log*" },
            @{ Name = "taosx"; Pattern = "taosx*.log*" },
            @{ Name = "taos-explorer"; Pattern = "taos-explorer*.log*" }
        )
        
        $cutoffDate = (Get-Date).AddDays(-7)  # Last 7 days
        
        foreach ($logFile in $logFiles) {
            $logFilesFound = Get-ChildItem -Path $logPath -Filter $logFile.Pattern -Recurse -ErrorAction SilentlyContinue
            
            foreach ($file in $logFilesFound) {
                # Check if file is recent
                if ($file.LastWriteTime -lt $cutoffDate) {
                    continue
                }
                
                try {
                    # Search for ERROR lines
                    $errors = Select-String -Path $file.FullName -Pattern "ERROR|FATAL|PANIC" -ErrorAction SilentlyContinue | Select-Object -First 50
                    
                    foreach ($error in $errors) {
                        $errorInfo = @{
                            "Source" = $logFile.Name
                            "File" = $file.Name
                            "Line" = $error.LineNumber
                            "Timestamp" = ""
                            "Message" = $error.Line.Trim()
                        }
                        
                        # Try to extract timestamp (ISO format: YYYY-MM-DD HH:mm:ss)
                        if ($error.Line -match '(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})') {
                            $errorInfo.Timestamp = $Matches[1]
                        }
                        # Try TDengine log format (MM/dd HH:mm:ss)
                        elseif ($error.Line -match '(\d{2}/\d{2}\s+\d{2}:\d{2}:\d{2})') {
                            $errorInfo.Timestamp = $Matches[1]
                        }
                        
                        $errorLogs += $errorInfo
                    }
                    
                    if ($errors.Count -gt 0) {
                        $recentErrors += @{
                            "Source" = $logFile.Name
                            "File" = $file.Name
                            "Error Count" = $errors.Count
                            "Last Modified" = $file.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
                        }
                    }
                } catch {
                    # Skip files that can't be read
                }
            }
        }
        
        $result.Data = @{
            "Total Errors Found" = $errorLogs.Count
            "Log Sources with Errors" = $recentErrors.Count
            "Recent Errors" = $recentErrors
            "Error Details" = $errorLogs | Select-Object -First 100
        }
        
        $result.Details += "Database Error Log Analysis"
        $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
        $result.Details += "Log Path: $logPath"
        $result.Details += "Total Errors Found: $($errorLogs.Count)"
        $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
        
        if ($recentErrors.Count -gt 0) {
            $result.Details += ""
            $result.Details += "Log Sources with Errors:"
            $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
            $result.Details += "{0,-20} {1,-30} {2}" -f "Source", "File", "Error Count"
            $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
            foreach ($err in $recentErrors) {
                $result.Details += "{0,-20} {1,-30} {2}" -f $err.Source, $err.File, $err.'Error Count'
            }
            $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
            
            $result.Details += ""
            $result.Details += "Recent Error Messages by Source (up to 10 per source):"
            $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
            
            # Group errors by source
            $groupedErrors = @{}
            foreach ($err in $errorLogs) {
                $src = $err.Source
                if (-not $groupedErrors.ContainsKey($src)) {
                    $groupedErrors[$src] = @()
                }
                $groupedErrors[$src] += $err
            }
            
            foreach ($src in $groupedErrors.Keys | Sort-Object) {
                $sourceErrors = $groupedErrors[$src]
                $displayCount = [math]::Min($sourceErrors.Count, 10)
                $result.Details += "--- $src ($($sourceErrors.Count) total, showing $displayCount) ---"
                for ($i = 0; $i -lt $displayCount; $i++) {
                    $err = $sourceErrors[$i]
                    $timestamp = if ($err.Timestamp) { "[$($err.Timestamp)]" } else { "" }
                    $result.Details += "  [$($err.File)] $timestamp $($err.Message)"
                }
            }
            $result.Details += "----------------------------------------------------------------------------------------------------------------------------------------"
            
            # Set status - errors in logs are warnings, not failures
            if ($errorLogs.Count -gt 0) {
                $result.Status = "Warning"
                $result.Issues += "Found $($errorLogs.Count) error messages in logs."
            }
        } else {
            $result.Details += "No recent error logs found."
        }
        
    } catch {
        $result.Status = "Warning"
        $result.Issues += "Failed to analyze error logs: $_"
    }
    
    return $result
}
