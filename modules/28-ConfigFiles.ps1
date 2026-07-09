# Module 28: Configuration Files
# Checks: Output the contents of taos.cfg (non-comment lines) and local.json.
# - taos.cfg: from TDengine install path cfg\ directory
# - local.json: from dataDir\dnode\config\local.json (dataDir resolved from taos.cfg or config.json)

function Get-ConfigFilesInfo {
    param(
        [object]$Config
    )

    $result = @{
        Name = "Configuration Files"
        Status = "Pass"
        Data = @{}
        Issues = @()
        Details = @()
    }

    try {
        # ===== 1. taos.cfg =====
        $taosCfgPath = Join-Path $Config.paths.tdengine "cfg\taos.cfg"
        $result.Details += "===== taos.cfg ($taosCfgPath) ====="

        if (Test-Path $taosCfgPath) {
            $lines = Get-Content $taosCfgPath -ErrorAction SilentlyContinue
            $nonCommentLines = $lines | Where-Object { $_ -match '\S' -and $_ -notmatch '^\s*#' }
            if ($nonCommentLines) {
                foreach ($line in $nonCommentLines) {
                    $result.Details += $line
                }
            } else {
                $result.Details += "(No non-comment lines)"
            }
        } else {
            $result.Details += "(File not found)"
            $result.Issues += "taos.cfg not found at: $taosCfgPath"
        }

        # ===== 2. Determine dataDir for local.json path =====
        $dataDir = $null
        if (Test-Path $taosCfgPath) {
            $lines = Get-Content $taosCfgPath -ErrorAction SilentlyContinue
            foreach ($line in $lines) {
                if ($line -match '^\s*#') { continue }
                if ($line -match '^\s*[dD][aA][tT][aA][dD][iI][rR]\s+(\S+)') {
                    $dataDir = ($line -split '\s+', 4)[1].Trim()
                    break  # Take the first dataDir line
                }
            }
        }
        if (-not $dataDir) {
            $dataDir = $Config.paths.data
        }

        # ===== 3. local.json =====
        $localJsonPath = Join-Path $dataDir "dnode\config\local.json"
        $result.Details += ""
        $result.Details += "===== local.json ($localJsonPath) ====="

        if (Test-Path $localJsonPath) {
            $content = Get-Content $localJsonPath -Raw -ErrorAction SilentlyContinue
            if ($content) {
                $result.Details += $content.Trim()
            } else {
                $result.Details += "(Empty file)"
            }
        } else {
            $result.Details += "(File not found)"
            $result.Issues += "local.json not found at: $localJsonPath"
        }

        # Set status to Warning if any file missing
        if ($result.Issues.Count -gt 0) {
            $result.Status = "Warning"
        }

    } catch {
        $result.Status = "Warning"
        $result.Issues += "Failed to read configuration files: $_"
    }

    return $result
}
