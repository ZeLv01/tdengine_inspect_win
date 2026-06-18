# TDengine Inspection Tool - Build Script
# Usage: .\build.ps1

param(
    [string]$OutputDir = ".\dist",
    [string]$IconPath = ".\assets\tdengine.ico",
    [switch]$Clean
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  TDengine Inspection Tool - Build" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Check PS2EXE
Write-Host "[1/6] Checking PS2EXE..." -ForegroundColor Yellow
if (-not (Get-Module -ListAvailable -Name ps2exe)) {
    Install-Module -Name ps2exe -Force -Scope CurrentUser
}
Import-Module ps2exe -ErrorAction Stop
Write-Host "  OK" -ForegroundColor Green

# 2. Prepare output
Write-Host "[2/6] Preparing output..." -ForegroundColor Yellow
if ($Clean -and (Test-Path $OutputDir)) { Remove-Item -Path $OutputDir -Recurse -Force }
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null }

# 3. Read source files
Write-Host "[3/6] Reading source files..." -ForegroundColor Yellow
$moduleFiles = Get-ChildItem "modules" -Filter "*.ps1" | Sort-Object Name
$moduleBlock = ""
foreach ($m in $moduleFiles) {
    if ($m.Name -eq "00-Connection.ps1") {
        $lines = Get-Content $m.FullName
        $keep = @()
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $n = $i + 1
            if ($n -ge 4 -and $n -le 15) { continue }
            $keep += $lines[$i]
        }
        $content = $keep -join "`r`n"
    } else {
        $content = Get-Content $m.FullName -Raw
    }
    $moduleBlock += "# ===== Module: $($m.Name) =====`r`n$content`r`n"
}
Write-Host "  Modules: $($moduleFiles.Count)" -ForegroundColor Gray

$templateContent = Get-Content "templates/report-template.html" -Raw
Write-Host "  Template: loaded" -ForegroundColor Gray

$mainScript = Get-Content "TDengine-Inspect.ps1" -Raw

# 4. Generate combined script
Write-Host "[4/6] Generating combined script..." -ForegroundColor Yellow
$tempDir = "$(Get-Location)\build-temp"
$combinedPath = "$tempDir\TDengine-Inspect-Combined.ps1"
if (-not (Test-Path $tempDir)) { New-Item -ItemType Directory -Path $tempDir -Force | Out-Null }

# Use StreamWriter to build script
$sw = New-Object System.IO.StreamWriter($combinedPath, $false, [System.Text.Encoding]::UTF8)

# Header - NO param block, parse args manually
$sw.WriteLine("# TDengine Inspection Tool - Combined Script")
$sw.WriteLine('$ErrorActionPreference="Continue"')
$sw.WriteLine('')
$sw.WriteLine('# Parse command line args (PS2EXE-safe)')
$sw.WriteLine('$ConfigPath=""; $OutputPath=""; $OpenReport=$false; $Quiet=$false')
$sw.WriteLine('for($i=0;$i -lt $args.Count;$i++){')
$sw.WriteLine('  switch($args[$i]){')
$sw.WriteLine('    "-ConfigPath"{$i++;if($i -lt $args.Count){$ConfigPath=$args[$i]}}')
$sw.WriteLine('    "-OutputPath"{$i++;if($i -lt $args.Count){$OutputPath=$args[$i]}}')
$sw.WriteLine('    "-OpenReport"{$OpenReport=$true}')
$sw.WriteLine('    "-Quiet"{$Quiet=$true}')
$sw.WriteLine('  }')
$sw.WriteLine('}')
$sw.WriteLine('')
$sw.WriteLine('# Detect script directory')
$sw.WriteLine('try{$ScriptDir=Split-Path -Parent ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)}catch{$ScriptDir=$PWD}')
$sw.WriteLine('')
$sw.WriteLine('# Set default config path')
$sw.WriteLine('if($ConfigPath -eq "" -or $null -eq $ConfigPath){$ConfigPath=Join-Path $ScriptDir "config.json"}')
$sw.WriteLine('')

# Embed template
$sw.WriteLine('$script:EmbeddedTemplate = @''')
$sw.Write($templateContent)
$sw.WriteLine("")
$sw.WriteLine("'@")
$sw.WriteLine("")

# Modules
$sw.WriteLine("# Modules")
$sw.Write($moduleBlock)
$sw.WriteLine("")

# Override Get-Config (EXE-aware)
$sw.WriteLine('function Get-Config { param($Path) if([string]::IsNullOrEmpty($Path)){$Path=Join-Path $ScriptDir "config.json"} if(-not (Test-Path $Path)){throw "Config not found: $Path"} return Get-Content $Path -Raw | ConvertFrom-Json }')
$sw.WriteLine('function Import-Modules { param($p) }')
$sw.WriteLine('')

# Override New-HTMLReport (use embedded template)
$sw.WriteLine('function New-HTMLReport {')
$sw.WriteLine('  param($Results,$Config,$tp,$OutputPath,$StartTime,$EndTime)')
$sw.WriteLine('  $template = $script:EmbeddedTemplate')
$sw.WriteLine('  $totalChecks = $Results.Count')
$sw.WriteLine('  $passCount = 0; $warnCount = 0; $failCount = 0')
$sw.WriteLine('  foreach ($r in $Results) { switch ($r.Status) { "Pass"{$passCount++} "Warning"{$warnCount++} "Critical"{$failCount++} } }')
$sw.WriteLine('  $duration = $EndTime - $StartTime')
$sw.WriteLine('  $durationStr = "{0:mm\:ss}" -f $duration')
$sw.WriteLine('  $server = $Config.connection.server')
$sw.WriteLine('  $version = "Unknown"')
$sw.WriteLine('  $connectionMethod = $Config.connection.method')
$sw.WriteLine('  $versionResult = $Results | ? { $_.Name -eq "Database Service Version" }')
$sw.WriteLine('  if ($versionResult -and $versionResult.Data -and $versionResult.Data["Server Version"]) { $version = $versionResult.Data["Server Version"] }')
$sw.WriteLine('  $sectionsHtml = ""; $navHtml = ""; $si = 0; $warnSum = @(); $failSum = @()')
$sw.WriteLine('  foreach ($r in $Results) {')
$sw.WriteLine('    $si++; $sc = $r.Status.ToLower(); $aid = "section-$si"')
$sw.WriteLine('    $badge = switch($r.Status){"Pass"{"OK"}"Warning"{"!!"}"Critical"{"XX"}}')
$sw.WriteLine('    $navHtml += "<li><a href=`"#$aid`" class=`"$sc`">$si. $($r.Name) <span class=`"nb`">$badge</span></a></li>`n"')
$sw.WriteLine('    if ($r.Status -eq "Warning" -and $r.Issues.Count) { $warnSum += "$si. $($r.Name): $($r.Issues[0])" }')
$sw.WriteLine('    if ($r.Status -eq "Critical" -and $r.Issues.Count) { $failSum += "$si. $($r.Name): $($r.Issues[0])" }')
$sw.WriteLine('    $sectionsHtml += "<div class=`"section`" id=`"$aid`"><div class=`"section-header`"><h2>$si. $($r.Name)</h2><span class=`"badge $sc`">$($r.Status)</span></div><div class=`"sc`">"')
$sw.WriteLine('    if ($r.Issues.Count) { $ic = if($sc -eq "fail"){"fail"}else{"warning"}; $sectionsHtml += "<div class=`"issues $ic`"><strong>Issues:</strong><ul>"; foreach ($x in $r.Issues) { $sectionsHtml += "<li>$x</li>" }; $sectionsHtml += "</ul></div>" }')
$sw.WriteLine('    if ($r.Details.Count) { $sectionsHtml += "<div class=`"details`">$([System.Web.HttpUtility]::HtmlEncode(($r.Details -join "`n")))</div>" }')
$sw.WriteLine('    $sectionsHtml += "</div></div>"')
$sw.WriteLine('  }')
$sw.WriteLine('  $alertHtml = ""')
$sw.WriteLine('  if ($failSum.Count -or $warnSum.Count) { $alertHtml = "<div class=`"alert-summary`">"; if($failSum.Count){$alertHtml+="<div class=`"alert-section fail`"><h3>Failed ($failCount)</h3><ul>";foreach($x in $failSum){$alertHtml+="<li>$([System.Web.HttpUtility]::HtmlEncode($x))</li>"};$alertHtml+="</ul></div>"}; if($warnSum.Count){$alertHtml+="<div class=`"alert-section warning`"><h3>Warnings ($warnCount)</h3><ul>";foreach($x in $warnSum){$alertHtml+="<li>$([System.Web.HttpUtility]::HtmlEncode($x))</li>"};$alertHtml+="</ul></div>"}; $alertHtml+="</div>" }')
$sw.WriteLine('  $repl = @{')
$sw.WriteLine('    "{{SERVER}}" = $server')
$sw.WriteLine('    "{{VERSION}}" = $version')
$sw.WriteLine('    "{{DATE}}" = (Get-Date -f "yyyy-MM-dd HH:mm:ss")')
$sw.WriteLine('    "{{DURATION}}" = $durationStr')
$sw.WriteLine('    "{{CONNECTION_METHOD}}" = $connectionMethod')
$sw.WriteLine('    "{{TOTAL_CHECKS}}" = $totalChecks')
$sw.WriteLine('    "{{PASS_COUNT}}" = $passCount')
$sw.WriteLine('    "{{WARNING_COUNT}}" = $warnCount')
$sw.WriteLine('    "{{FAIL_COUNT}}" = $failCount')
$sw.WriteLine('    "{{ALERT_SUMMARY}}" = $alertHtml')
$sw.WriteLine('    "{{NAV_ITEMS}}" = $navHtml')
$sw.WriteLine('    "{{SECTIONS}}" = $sectionsHtml')
$sw.WriteLine('    "{{GENERATED_AT}}" = (Get-Date -f "yyyy-MM-dd HH:mm:ss")')
$sw.WriteLine('  }')
$sw.WriteLine('  foreach ($k in $repl.Keys) { $template = $template -replace [regex]::Escape($k), $repl[$k] }')
$sw.WriteLine('  if (-not $OutputPath) { $OutputPath = Join-Path $ScriptDir "output\report-$(Get-Date -f yyyyMMdd-HHmmss).html" }')
$sw.WriteLine('  $outDir = Split-Path $OutputPath -Parent')
$sw.WriteLine('  if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }')
$sw.WriteLine('  $template | Out-File -FilePath $OutputPath -Encoding UTF8')
$sw.WriteLine('  return $OutputPath')
$sw.WriteLine('}')
$sw.WriteLine('')

# Main function
$sw.WriteLine('function Main {')
$sw.WriteLine('  $st = Get-Date')
$sw.WriteLine('  Write-Host "============== TDengine Inspection Tool ==============" -ForegroundColor Cyan')
$sw.WriteLine('  if([string]::IsNullOrEmpty($ConfigPath)){$ConfigPath=Join-Path $ScriptDir "config.json"}')
$sw.WriteLine('  if(-not (Test-Path $ConfigPath)){ Write-Error "Config not found: $ConfigPath"; exit 1 }')
$sw.WriteLine('  try { $Config = Get-Config -Path $ConfigPath; Write-Host "  Server: $($Config.connection.server) ($($Config.connection.method):$($Config.connection.port))" -ForegroundColor Gray } catch { Write-Error "Config: $_"; exit 1 }')
$sw.WriteLine('  try { if (Test-TDengineConnection -Config $Config) { Write-Host "  Connection: OK" -ForegroundColor Green } else { Write-Warning "Connection: failed" } } catch { Write-Warning "Connection: $_" }')
$sw.WriteLine('  $Results = @()')
$sw.WriteLine('  $funcs = @("Get-SystemInfo","Get-CPUInfo","Get-MemoryInfo","Get-NetworkInfo","Get-DataDirectoryInfo","Get-HostsConfigInfo","Get-DnodeInfo","Get-MnodeInfo","Get-DatabaseList","Get-DatabaseCreateStatements","Get-StableCreateStatements","Get-StableStatistics","Get-StableDiskDistribution","Get-DiskUsageInfo","Get-CPUUsageInfo","Get-FirewallStatus","Get-ServiceVersionInfo","Get-ServiceStatus","Get-ErrorLogInfo","Get-UserInfo","Get-LicenseInfo","Get-SlowQueryInfo","Get-ReplicaInfo","Get-DatabaseVariables","Get-VnodeLeaderInfo","Get-MeasurePoints")')
$sw.WriteLine('  $ci = 0')
$sw.WriteLine('  foreach ($f in $funcs) { $ci++; try { $r = & $f -Config $Config; $Results += $r; $sc = switch($r.Status){"Pass"{"Green"};"Warning"{"Yellow"};"Critical"{"Red"}}; if (-not $Quiet) { Write-Host "  $ci. [$($r.Status)] $($r.Name)" -ForegroundColor $sc } } catch { Write-Warning "  $ci. [FAIL] ${f}: $_" } }')
$sw.WriteLine('  Write-Host ""')
$sw.WriteLine('  Add-Type -AssemblyName System.Web')
$sw.WriteLine('  $rp = New-HTMLReport -Results $Results -Config $Config -tp "" -OutputPath $OutputPath -StartTime $st -EndTime (Get-Date)')
$sw.WriteLine('  $pc = ($Results | ? { $_.Status -eq "Pass" }).Count')
$sw.WriteLine('  $wc = ($Results | ? { $_.Status -eq "Warning" }).Count')
$sw.WriteLine('  $fc = ($Results | ? { $_.Status -eq "Critical" }).Count')
$sw.WriteLine('  Write-Host "Summary: Total=$($Results.Count) Pass=$pc Warning=$wc Fail=$fc" -ForegroundColor White')
$sw.WriteLine('  if ($rp) { Write-Host "Report: $rp" -ForegroundColor Green; if ($OpenReport) { Start-Process $rp } }')
$sw.WriteLine('  else { Write-Warning "Report not generated" }')
$sw.WriteLine('  if ($fc -gt 0) { exit 2 } elseif ($wc -gt 0) { exit 1 } else { exit 0 }')
$sw.WriteLine('}')
$sw.WriteLine('')

$sw.WriteLine('Main')

$sw.Close()
Write-Host "  Combined script: $combinedPath" -ForegroundColor Green

# 5. Download icon
Write-Host "[5/6] Checking icon..." -ForegroundColor Yellow
if (-not (Test-Path $IconPath)) {
    $iconDir = Split-Path $IconPath -Parent
    if (-not (Test-Path $iconDir)) { New-Item -ItemType Directory -Path $iconDir -Force | Out-Null }
    try { Invoke-WebRequest -Uri "https://www.taosdata.com/wp-content/uploads/2025/07/favicon.ico" -OutFile $IconPath -ErrorAction Stop; Write-Host "  Icon downloaded." -ForegroundColor Green }
    catch { Write-Warning "Failed to download icon."; $IconPath = $null }
}

# 6. Package EXE
Write-Host "[6/6] Packaging EXE..." -ForegroundColor Yellow
$exePath = Join-Path $OutputDir "TDengine-Inspect.exe"
$params = @{ InputFile = $combinedPath; OutputFile = $exePath; Title = "TDengine Inspection Tool"; Version = "1.0.0"; Company = "TDengine"; Description = "TDengine Database Inspection Tool"; NoConsole = $false }
if ($IconPath -and (Test-Path $IconPath)) { $params.IconFile = $IconPath }
try {
    Invoke-PS2EXE @params
    Write-Host "  EXE: $exePath ($([math]::Round((Get-Item $exePath).Length/1KB))KB)" -ForegroundColor Green
} catch { Write-Error "Failed: $_"; exit 1 }

# Copy files
Copy-Item "config.json" (Join-Path $OutputDir "config.json") -Force
Copy-Item "README.md" (Join-Path $OutputDir "README.md") -Force -ErrorAction SilentlyContinue
Copy-Item "README_CN.md" (Join-Path $OutputDir "README_CN.md") -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Build Complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Output: $OutputDir"
Get-ChildItem $OutputDir | ForEach-Object { Write-Host "  - $($_.Name) ($([math]::Round($_.Length/1KB))KB)" }
Write-Host ""
Write-Host "Usage: TDengine-Inspect.exe" -ForegroundColor White
