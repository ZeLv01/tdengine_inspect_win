# Module 27: Crash Detection
# Checks: taosd core dump files (.dmp and _stack.log) in the configured corefile directory.
# If crash files exist, lists them sorted by last modified time (newest first).

function Get-CrashDetectionInfo {
    param(
        [object]$Config
    )

    $result = @{
        Name = "Crash Detection"
        Status = "Pass"
        Data = @{}
        Issues = @()
        Details = @()
        Tables = @()
    }

    try {
        # Read corefile path from config, default to C:\TDengine
        $corePath = if ($Config.paths.corefile) { $Config.paths.corefile } else { "C:\TDengine" }
        $result.Details += "Checking crash files in: $corePath"
        $result.Data["Corefile Path"] = $corePath

        # Check if the directory exists
        if (-not (Test-Path $corePath)) {
            $result.Status = "Warning"
            $result.Issues += "Corefile directory does not exist: $corePath"
            $result.Details += "Directory not found. Cannot scan for crash files."
            $result.Data["Directory Exists"] = $false
            return $result
        }
        $result.Data["Directory Exists"] = $true

        # Scan for crash files: taosd_*.dmp and taosd_*stack.log
        # Note: Notepad may append .txt, so we match .dmp or stack.log anywhere in the filename
        $crashFiles = Get-ChildItem -Path $corePath -Filter "taosd_*" -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '\.dmp' -or $_.Name -match 'stack\.log' } |
            Sort-Object LastWriteTime -Descending

        if (-not $crashFiles -or $crashFiles.Count -eq 0) {
            $result.Details += "No crash dump files found. taosd appears stable."
            $result.Data["Crash Files Found"] = 0
        } else {
            $result.Status = "Critical"
            $result.Issues += "Found $($crashFiles.Count) taosd crash file(s) in: $corePath"
            $result.Data["Crash Files Found"] = $crashFiles.Count

            foreach ($f in $crashFiles) {
                $sizeKB = [math]::Round($f.Length / 1KB, 1)
                $modTime = $f.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
                $result.Details += "[CRASH] $($f.Name) | $sizeKB KB | $modTime"
            }

            # Build table for HTML report
            $rows = @()
            foreach ($f in $crashFiles) {
                $sizeKB = [math]::Round($f.Length / 1KB, 1)
                $modTime = $f.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
                $rows += @(, @($f.Name, "$sizeKB KB", $modTime))
            }
            $result.Tables += @{
                Caption = "Crash Files Detected (newest first)"
                Headers = @("File Name", "Size", "Last Modified")
                Rows = $rows
            }
        }

    } catch {
        $result.Status = "Critical"
        $result.Issues += "Failed to check crash files: $_"
    }

    return $result
}
