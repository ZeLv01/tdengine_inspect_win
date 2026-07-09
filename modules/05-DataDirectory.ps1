# Module 05: Database Data Directory Usage
# Checks: Data directory mount path(s), filesystem, storage type,
# used/available space per drive, directory existence, and subdirectory file sizes.
# Supports TDengine multi-tier storage: multiple dataDir lines in taos.cfg.

function Get-DataDirectoryInfo {
    param(
        [object]$Config
    )

    $result = @{
        Name = "Database Data Directory Usage"
        Status = "Pass"
        Data = @{}
        Issues = @()
        Details = @()
        Tables = @()
    }

    try {
        # ----- Step 1: Parse taos.cfg for all dataDir lines -----
        $configFile = Join-Path $Config.paths.tdengine "cfg\taos.cfg"
        $dataDirs = @()  # Each entry: @{ Path = "..."; Level = ...; IsPrimary = ... }

        if (Test-Path $configFile) {
            $configContent = Get-Content $configFile -ErrorAction SilentlyContinue
            foreach ($line in $configContent) {
                # Skip comment lines
                if ($line -match '^\s*#') { continue }
                # Match dataDir or datadir (case-insensitive) with a path argument
                if ($line -match '^\s*[dD][aA][tT][aA][dD][iI][rR]\s+(\S+)') {
                    $parts = $line -split '\s+', 4  # Max 4 parts: key, path, level, primary
                    $dirPath = $parts[1].Trim()
                    $level = if ($parts.Count -gt 2 -and $parts[2] -ne '') { $parts[2] } else { $null }
                    $isPrimary = if ($parts.Count -gt 3 -and $parts[3] -ne '') { $parts[3] } else { $null }
                    $dataDirs += @{
                        Path = $dirPath
                        Level = $level
                        IsPrimary = $isPrimary
                    }
                    $result.Details += "Found dataDir in taos.cfg: $dirPath"
                }
            }
        } else {
            $result.Details += "taos.cfg not found at: $configFile"
        }

        # Fallback to config.json paths.data if no dataDir found in taos.cfg
        if ($dataDirs.Count -eq 0) {
            $fallbackPath = $Config.paths.data
            $dataDirs += @{
                Path = $fallbackPath
                Level = $null
                IsPrimary = $null
            }
            $result.Details += "No dataDir in taos.cfg, using config default: $fallbackPath"
        }

        # ----- Step 2: Directory existence validation -----
        $hasMissingDir = $false
        foreach ($dir in $dataDirs) {
            if (-not (Test-Path $dir.Path)) {
                $result.Issues += "WARNING: Data directory '$($dir.Path)' does not exist on the filesystem"
                $hasMissingDir = $true
            }
        }
        if ($hasMissingDir -and $result.Status -eq "Pass") {
            $result.Status = "Warning"
        }

        # ----- Step 3: Query disk info per unique drive -----
        $driveInfo = @{}       # Key: drive letter (e.g. "C"), Value: disk object
        $driveResults = @{}    # Key: drive letter, Value: @{ Total, Used, Free, UsedPercent, FileSystem, VolumeName }
        $maxUsedPercent = 0

        foreach ($dir in $dataDirs) {
            $d = $dir.Path.Substring(0, 1).ToUpper()
            if (-not $driveInfo.ContainsKey($d)) {
                $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='${d}:'" -ErrorAction SilentlyContinue
                $driveInfo[$d] = $disk
                if ($disk) {
                    $totalGB = [math]::Round($disk.Size / 1GB, 2)
                    $freeGB = [math]::Round($disk.FreeSpace / 1GB, 2)
                    $usedGB = [math]::Round(($disk.Size - $disk.FreeSpace) / 1GB, 2)
                    $usedPercent = if ($disk.Size -gt 0) {
                        [math]::Round((($disk.Size - $disk.FreeSpace) / $disk.Size) * 100, 2)
                    } else { 0 }
                    if ($usedPercent -gt $maxUsedPercent) { $maxUsedPercent = $usedPercent }
                    $driveResults[$d] = @{
                        Total = $totalGB
                        Used = $usedGB
                        Free = $freeGB
                        UsedPercent = $usedPercent
                        FileSystem = $disk.FileSystem
                        VolumeName = $disk.VolumeName
                    }
                } else {
                    $driveResults[$d] = $null
                }
            }
        }

        # ----- Step 4: Threshold check (based on max usage across all drives) -----
        $warningThreshold = $Config.thresholds.diskUsageWarning
        $criticalThreshold = $Config.thresholds.diskUsageCritical

        if ($maxUsedPercent -ge $criticalThreshold) {
            $result.Status = "Critical"
            $result.Issues += "CRITICAL: Disk usage ($maxUsedPercent%) exceeds critical threshold ($criticalThreshold%)"
        } elseif ($maxUsedPercent -ge $warningThreshold) {
            $result.Status = "Warning"
            $result.Issues += "WARNING: Disk usage ($maxUsedPercent%) exceeds warning threshold ($warningThreshold%)"
        }

        # ----- Step 5: Build Details lines -----
        $result.Details += "--- Disk Usage by Drive ---"
        foreach ($d in $driveResults.Keys | Sort-Object) {
            $info = $driveResults[$d]
            if ($info) {
                $result.Details += "Drive ${d}: | Total: $($info.Total) GB | Used: $($info.Used) GB ($($info.UsedPercent)%) | Free: $($info.Free) GB | $($info.FileSystem)"
            } else {
                $result.Details += "Drive ${d}: Could not retrieve disk information"
            }
        }

        $result.Details += "--- Configured Data Directories ---"
        foreach ($dir in $dataDirs) {
            $extra = ""
            if ($dir.Level -ne $null) { $extra += " Level=$($dir.Level)" }
            if ($dir.IsPrimary -ne $null) { $extra += " Primary=$($dir.IsPrimary)" }
            $status = if (Test-Path $dir.Path) { "[Exists]" } else { "[Missing!]" }
            $result.Details += "$status $($dir.Path)$extra"
        }

        # ----- Step 6: Build Tables -----

        # Table 1: Disk usage summary per drive
        $diskHeaders = @("Drive", "File System", "Volume Name", "Total (GB)", "Used (GB)", "Free (GB)", "Used %")
        $diskRows = @()
        foreach ($d in $driveResults.Keys | Sort-Object) {
            $info = $driveResults[$d]
            if ($info) {
                $diskRows += @(, @("${d}:", $info.FileSystem, $info.VolumeName,
                    $info.Total, $info.Used, $info.Free, "$($info.UsedPercent)%"))
            } else {
                $diskRows += @(, @("${d}:", "N/A", "N/A", "N/A", "N/A", "N/A", "N/A"))
            }
        }
        $result.Tables += @{
            Caption = "Disk Usage Summary"
            Headers = $diskHeaders
            Rows = $diskRows
        }

        # Table 2+: Per-directory subdirectory file sizes (one table per dataDir)
        foreach ($dir in $dataDirs) {
            if (-not (Test-Path $dir.Path)) { continue }
            $subDirSizes = @()
            $items = Get-ChildItem $dir.Path -Directory -ErrorAction SilentlyContinue
            foreach ($item in $items) {
                $sizeBytes = (Get-ChildItem $item.FullName -Recurse -File -ErrorAction SilentlyContinue |
                    Measure-Object Length -Sum).Sum
                $sizeMB = if ($sizeBytes) { [math]::Round($sizeBytes / 1MB, 2) } else { 0 }
                $subDirSizes += @{ Dir = $item.Name; SizeMB = $sizeMB }
            }
            # Sort by size descending
            $subDirSizes = $subDirSizes | Sort-Object SizeMB -Descending

            if ($subDirSizes.Count -gt 0) {
                $caption = "Subdirectory File Sizes: $($dir.Path)"
                $extra = ""
                if ($dir.Level -ne $null) { $extra += " (Level=$($dir.Level)" }
                if ($dir.IsPrimary -ne $null) { $extra += ", Primary=$($dir.IsPrimary)" }
                if ($extra -ne "") { $extra += ")" }
                $caption += $extra

                $rows = @()
                foreach ($s in $subDirSizes) {
                    $rows += @(, @($s.Dir, "$($s.SizeMB) MB"))
                }
                $result.Tables += @{
                    Caption = $caption
                    Headers = @("Directory", "Size (MB)")
                    Rows = $rows
                }
            } else {
                $result.Details += "(No subdirectories found in $($dir.Path))"
            }
        }

        # ----- Step 7: Set Data field (backward compatible) -----
        $result.Data = @{
            "Data Directory Count" = $dataDirs.Count
            "Drives Checked" = ($driveResults.Keys | Sort-Object) -join ", "
            "Max Used Percentage" = "$maxUsedPercent%"
        }

    } catch {
        $result.Status = "Critical"
        $result.Issues += "Failed to retrieve data directory information: $_"
    }

    return $result
}
