# Test Script - Verify module loading
# Run this script to check if all modules load correctly

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "Testing TDengine Inspection Modules" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

# Test connection module
Write-Host "Loading connection module..." -ForegroundColor Yellow
$connectionModule = Join-Path $ScriptDir "modules\00-Connection.ps1"
try {
    . $connectionModule
    Write-Host "  [OK] Connection module loaded" -ForegroundColor Green
    
    # Test Get-Config function
    $configPath = Join-Path $ScriptDir "config.json"
    $config = Get-Config -Path $configPath
    Write-Host "  [OK] Config loaded: $($config.connection.server)" -ForegroundColor Green
} catch {
    Write-Host "  [FAIL] $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test other modules
Write-Host "Loading inspection modules..." -ForegroundColor Yellow
$modulePath = Join-Path $ScriptDir "modules"
$modules = Get-ChildItem -Path $modulePath -Filter "*.ps1" | 
    Where-Object { $_.Name -ne "00-Connection.ps1" } | 
    Sort-Object Name

$loaded = 0
$failed = 0

foreach ($module in $modules) {
    try {
        . $module.FullName
        $loaded++
        Write-Host "  [OK] $($module.Name)" -ForegroundColor Green
    } catch {
        $failed++
        Write-Host "  [FAIL] $($module.Name): $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Results:" -ForegroundColor Cyan
Write-Host "  Loaded: $loaded" -ForegroundColor Green
Write-Host "  Failed: $failed" -ForegroundColor $(if($failed -gt 0){"Red"}else{"Green"})

# Test if functions are available
Write-Host ""
Write-Host "Testing function availability..." -ForegroundColor Yellow

$functions = @(
    "Get-SystemInfo",
    "Get-CPUInfo",
    "Get-NetworkInfo",
    "Get-DataDirectoryInfo",
    "Get-HostsConfigInfo",
    "Get-DnodeInfo",
    "Get-MnodeInfo",
    "Get-DatabaseList",
    "Get-DatabaseCreateStatements",
    "Get-StableCreateStatements",
    "Get-StableStatistics",
    "Get-StableDiskDistribution",
    "Get-DiskUsageInfo",
    "Get-CPUUsageInfo",
    "Get-FirewallStatus",
    "Get-ServiceVersionInfo",
    "Get-ServiceStatus",
    "Get-ErrorLogInfo",
    "Get-UserInfo",
    "Get-LicenseInfo",
    "Get-SlowQueryInfo",
    "Get-ReplicaInfo",
    "Get-CrashDetectionInfo",
    "Get-ConfigFilesInfo",
    "Get-TaosxInfo"
)

$available = 0
$missing = 0

foreach ($func in $functions) {
    if (Get-Command $func -ErrorAction SilentlyContinue) {
        $available++
    } else {
        $missing++
        Write-Host "  [MISSING] $func" -ForegroundColor Red
    }
}

Write-Host "  Available: $available / $($functions.Count)" -ForegroundColor $(if($missing -eq 0){"Green"}else{"Yellow"})

if ($missing -eq 0) {
    Write-Host ""
    Write-Host "All modules loaded successfully!" -ForegroundColor Green
    Write-Host "You can now run: .\TDengine-Inspect.ps1" -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "Some functions are missing. Check the module files." -ForegroundColor Yellow
}
