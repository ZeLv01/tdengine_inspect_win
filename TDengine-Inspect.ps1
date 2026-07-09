# TDengine Inspection Tool for Windows
# Main Script - TDengine-Inspect.ps1
# Version: 1.0.0
# Description: Comprehensive inspection tool for TDengine database on Windows

param(
    [string]$ConfigPath = "",
    [string]$OutputPath = "",
    [switch]$OpenReport,
    [switch]$Quiet
)

# Set error action preference
$ErrorActionPreference = "Continue"

# Get script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Set default config path
if (-not $ConfigPath) {
    $ConfigPath = Join-Path $ScriptDir "config.json"
}

# Import connection module first
$connectionModule = Join-Path $ScriptDir "modules\00-Connection.ps1"
if (Test-Path $connectionModule) {
    . $connectionModule
} else {
    Write-Error "Connection module not found: $connectionModule"
    exit 1
}

# Helper function to convert table data to HTML table
function ConvertTo-HtmlTable {
    param(
        [array]$Headers,
        [array]$Rows
    )
    
    $html = "<table class='data-table'>`n<thead><tr>"
    foreach ($header in $Headers) {
        $html += "<th>$([System.Web.HttpUtility]::HtmlEncode($header))</th>"
    }
    $html += "</tr></thead>`n<tbody>"
    
    foreach ($row in $Rows) {
        $html += "<tr>"
        foreach ($cell in $row) {
            $html += "<td>$([System.Web.HttpUtility]::HtmlEncode($cell))</td>"
        }
        $html += "</tr>`n"
    }
    
    $html += "</tbody></table>`n"
    return $html
}

# Generate HTML report
function New-HTMLReport {
    param(
        [array]$Results,
        [object]$Config,
        [string]$TemplatePath,
        [string]$OutputPath,
        [datetime]$StartTime,
        [datetime]$EndTime
    )
    
    # Load template
    $template = Get-Content $TemplatePath -Raw
    
    # Calculate statistics using switch to avoid Where-Object filtering issues
    $totalChecks = $Results.Count
    $passCount = 0; $warningCount = 0; $failCount = 0
    foreach ($r in $Results) {
        switch ($r.Status) {
            "Pass" { $passCount++ }
            "Warning" { $warningCount++ }
            "Critical" { $failCount++ }
        }
    }
    
    # Calculate duration
    $duration = $EndTime - $StartTime
    $durationStr = "{0:mm\:ss}" -f $duration
    
    # Get server info
    $server = $Config.connection.server
    $version = "Unknown"
    $connectionMethod = $Config.connection.method
    
    # Try to get version from results
    $versionResult = $Results | Where-Object { $_.Name -eq "Database Service Version" }
    if ($versionResult -and $versionResult.Data -and $versionResult.Data["Server Version"]) {
        $version = $versionResult.Data["Server Version"]
    }
    
    # Generate sections HTML
    $sectionsHtml = ""
    $navItemsHtml = ""
    $sectionIndex = 0
    $warningSummary = @()
    $failSummary = @()
    
    foreach ($result in $Results) {
        $sectionIndex++
        $statusClass = $result.Status.ToLower()
        $badgeClass = $statusClass
        $anchorId = "section-$sectionIndex"
        
        # Generate navigation item
        $statusBadge = switch ($result.Status) {
            "Pass" { "OK" }
            "Warning" { "!!" }
            "Critical" { "XX" }
            default { "??" }
        }
        $navItemsHtml += "<li><a href=`"#$anchorId`" class=`"$statusClass`">$sectionIndex. $($result.Name) <span class=`"nav-badge`">$statusBadge</span></a></li>`n"
        
        # Collect warnings and failures for summary
        if ($result.Status -eq "Warning" -and $result.Issues.Count -gt 0) {
            $warningSummary += "$sectionIndex. $($result.Name): $($result.Issues[0])"
        }
        if ($result.Status -eq "Critical" -and $result.Issues.Count -gt 0) {
            $failSummary += "$sectionIndex. $($result.Name): $($result.Issues[0])"
        }
        
        # Section header
        $sectionsHtml += @"
        <div class="section" id="$anchorId">
            <div class="section-header">
                <h2>$sectionIndex. $($result.Name)</h2>
                <span class="badge $badgeClass">$($result.Status)</span>
            </div>
            <div class="section-content">
"@
        
        # Issues
        if ($result.Issues -and $result.Issues.Count -gt 0) {
            $issueClass = if ($statusClass -eq "critical") { "critical" } else { "warning" }
            $sectionsHtml += "<div class=`"issues $issueClass`"><strong>Issues:</strong><ul>"
            foreach ($issue in $result.Issues) {
                $sectionsHtml += "<li>$issue</li>"
            }
            $sectionsHtml += "</ul></div>"
        }
        
        # Details
        if ($result.Details -and $result.Details.Count -gt 0) {
            $detailsText = $result.Details -join "`n"
            $detailsHtml = [System.Web.HttpUtility]::HtmlEncode($detailsText)
            $sectionsHtml += "<div class=`"details`">$detailsHtml</div>"
        }

        # Tables (structured table data)
        if ($result.Tables -and $result.Tables.Count -gt 0) {
            foreach ($table in $result.Tables) {
                if ($table.Caption) {
                    $sectionsHtml += "<h4 style='margin:10px 0 5px;color:#495057'>$($table.Caption)</h4>"
                }
                if ($table.Headers -and $table.Rows -and $table.Rows.Count -gt 0) {
                    $sectionsHtml += ConvertTo-HtmlTable -Headers $table.Headers -Rows $table.Rows
                }
            }
        }

            $sectionsHtml += "</div></div>"
    }
    
    # Generate alert summary HTML
    $alertSummaryHtml = ""
    if ($failSummary.Count -gt 0 -or $warningSummary.Count -gt 0) {
        $alertSummaryHtml = '<div class="alert-summary">'
        
        if ($failSummary.Count -gt 0) {
            $alertSummaryHtml += '<div class="alert-section fail">'
            $alertSummaryHtml += '<h3>Failed (' + $failCount + ')</h3>'
            $alertSummaryHtml += '<ul>'
            foreach ($item in $failSummary) {
                $alertSummaryHtml += "<li>$([System.Web.HttpUtility]::HtmlEncode($item))</li>"
            }
            $alertSummaryHtml += '</ul></div>'
        }
        
        if ($warningSummary.Count -gt 0) {
            $alertSummaryHtml += '<div class="alert-section warning">'
            $alertSummaryHtml += '<h3>Warnings (' + $warningSummary.Count + ')</h3>'
            $alertSummaryHtml += '<ul>'
            foreach ($item in $warningSummary) {
                $alertSummaryHtml += "<li>$([System.Web.HttpUtility]::HtmlEncode($item))</li>"
            }
            $alertSummaryHtml += '</ul></div>'
        }
        
        $alertSummaryHtml += '</div>'
    }
    
    # Replace placeholders
    $template = $template -replace "{{SERVER}}", $server
    $template = $template -replace "{{VERSION}}", $version
    $template = $template -replace "{{DATE}}", (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    $template = $template -replace "{{DURATION}}", $durationStr
    $template = $template -replace "{{CONNECTION_METHOD}}", $connectionMethod
    $template = $template -replace "{{TOTAL_CHECKS}}", $totalChecks
    $template = $template -replace "{{PASS_COUNT}}", $passCount
    $template = $template -replace "{{WARNING_COUNT}}", $warningCount
    $template = $template -replace "{{FAIL_COUNT}}", $failCount
    $template = $template -replace "{{ALERT_SUMMARY}}", $alertSummaryHtml
    $template = $template -replace "{{NAV_ITEMS}}", $navItemsHtml
    $template = $template -replace "{{SECTIONS}}", $sectionsHtml
    $template = $template -replace "{{GENERATED_AT}}", (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    
    # Save report
    $template | Out-File -FilePath $OutputPath -Encoding UTF8
    
    return $OutputPath
}

# Main execution
function Main {
    $startTime = Get-Date
    
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  TDengine Inspection Tool" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Load configuration
    Write-Host "[1/5] Loading configuration..." -ForegroundColor Yellow
    try {
        $Config = Get-Config -Path $ConfigPath
        Write-Host "  Server: $($Config.connection.server)" -ForegroundColor Gray
        Write-Host "  Method: $($Config.connection.method)" -ForegroundColor Gray
        Write-Host "  Port: $($Config.connection.port)" -ForegroundColor Gray
    } catch {
        Write-Error "Failed to load configuration: $_"
        exit 1
    }
    
    # Import other modules
    Write-Host "[2/5] Loading inspection modules..." -ForegroundColor Yellow
    $modulePath = Join-Path $ScriptDir "modules"
    $modules = Get-ChildItem -Path $modulePath -Filter "*.ps1" | 
        Where-Object { $_.Name -ne "00-Connection.ps1" } | 
        Sort-Object Name
    
    $loadedCount = 0
    foreach ($module in $modules) {
        try {
            . $module.FullName
            $loadedCount++
            if (-not $Quiet) {
                Write-Host "  Loaded: $($module.Name)" -ForegroundColor Gray
            }
        } catch {
            Write-Warning "Failed to load module $($module.Name): $($_.Exception.Message)"
        }
    }
    Write-Host "  Loaded $loadedCount modules" -ForegroundColor Gray
    
    # Test connection
    Write-Host "[3/5] Testing connection..." -ForegroundColor Yellow
    try {
        $connectionTest = Test-TDengineConnection -Config $Config
        if ($connectionTest.Success) {
            Write-Host "  Connection successful!" -ForegroundColor Green
        } else {
            if ($connectionTest.ErrorType -eq "auth") {
                Write-Host ""
                Write-Host "========================================" -ForegroundColor Red
                Write-Host "  Authentication Failed!" -ForegroundColor Red
                Write-Host "========================================" -ForegroundColor Red
                Write-Host ""
                Write-Host "  $($connectionTest.Message)" -ForegroundColor Red
                Write-Host ""
                Write-Host "  Please verify the 'user' and 'password' fields in config.json" -ForegroundColor Yellow
                Write-Host ""
                exit 1
            } elseif ($connectionTest.ErrorType -eq "connection") {
                Write-Host ""
                Write-Host "========================================" -ForegroundColor Red
                Write-Host "  Connection Failed!" -ForegroundColor Red
                Write-Host "========================================" -ForegroundColor Red
                Write-Host ""
                Write-Host "  $($connectionTest.Message)" -ForegroundColor Red
                Write-Host ""
                Write-Host "  Please verify the 'server' and 'port' fields in config.json" -ForegroundColor Yellow
                Write-Host "  Ensure TDengine service is running on the target server." -ForegroundColor Yellow
                Write-Host ""
                exit 1
            } else {
                Write-Host ""
                Write-Host "========================================" -ForegroundColor Red
                Write-Host "  Connection Failed!" -ForegroundColor Red
                Write-Host "========================================" -ForegroundColor Red
                Write-Host ""
                Write-Host "  $($connectionTest.Message)" -ForegroundColor Red
                Write-Host ""
                exit 1
            }
        }
    } catch {
        $errMsg = $_.Exception.Message
        Write-Error "Connection failed: $errMsg"
        exit 1
    }
    
    # Run inspections
    Write-Host "[4/5] Running inspections..." -ForegroundColor Yellow
    $Results = @()
    
    # Define inspection functions in order
    $inspections = @(
        @{Name="Get-SystemInfo"; Label="System Information"},
        @{Name="Get-CPUInfo"; Label="CPU Information"},
        @{Name="Get-MemoryInfo"; Label="Memory Information"},
        @{Name="Get-NetworkInfo"; Label="Network Information"},
        @{Name="Get-DataDirectoryInfo"; Label="Data Directory"},
        @{Name="Get-HostsConfigInfo"; Label="Hosts Configuration"},
        @{Name="Get-DnodeInfo"; Label="Dnode Information"},
        @{Name="Get-MnodeInfo"; Label="Mnode Information"},
        @{Name="Get-DatabaseList"; Label="Database List"},
        @{Name="Get-DatabaseCreateStatements"; Label="Database Create SQL"},
        @{Name="Get-StableCreateStatements"; Label="Super Table Statistics"},
        @{Name="Get-StableStatistics"; Label="Super Table Details"},
        @{Name="Get-StableDiskDistribution"; Label="Disk Distribution"},
        @{Name="Get-DiskUsageInfo"; Label="Disk Usage"},
        @{Name="Get-CPUUsageInfo"; Label="CPU Usage"},
        @{Name="Get-FirewallStatus"; Label="Firewall Status"},
        @{Name="Get-ServiceVersionInfo"; Label="Service Version"},
        @{Name="Get-ServiceStatus"; Label="Service Status"},
        @{Name="Get-ErrorLogInfo"; Label="Error Logs"},
        @{Name="Get-UserInfo"; Label="Database Users"},
        @{Name="Get-LicenseInfo"; Label="License/Authorization"},
        @{Name="Get-SlowQueryInfo"; Label="Slow Queries"},
        @{Name="Get-ReplicaInfo"; Label="Replica Count"},
        @{Name="Get-DatabaseVariables"; Label="Database Variables"},
        @{Name="Get-VnodeLeaderInfo"; Label="Vnodes Leader Distribution"},
        @{Name="Get-MeasurePoints"; Label="Database Measure Points"},
        @{Name="Get-CrashDetectionInfo"; Label="Crash Detection"},
        @{Name="Get-ConfigFilesInfo"; Label="Configuration Files"},
        @{Name="Get-TaosxInfo"; Label="TaosX Status"}
    )
    
    $totalInspections = $inspections.Count
    $currentInspection = 0
    
    foreach ($inspection in $inspections) {
        $currentInspection++
        $progress = [math]::Round(($currentInspection / $totalInspections) * 100)
        
        if (-not $Quiet) {
            Write-Progress -Activity "Running Inspections" -Status "$($inspection.Label) ($currentInspection/$totalInspections)" -PercentComplete $progress
        }
        
        try {
            $funcName = $inspection.Name
            $result = & $funcName -Config $Config
            $Results += $result
            
            $statusColor = switch ($result.Status) {
                "Pass" { "Green" }
                "Warning" { "Yellow" }
                "Critical" { "Red" }
                default { "White" }
            }
            
            if (-not $Quiet) {
                $statusIcon = switch ($result.Status) {
                    "Pass" { "[OK]" }
                    "Warning" { "[!!]" }
                    "Critical" { "[XX]" }
                    default { "[??]" }
                }
                Write-Host "  $currentInspection. $statusIcon $($result.Name)" -ForegroundColor $statusColor
            }
        } catch {
            Write-Warning "Failed to run inspection $($inspection.Name): $($_.Exception.Message)"
            $Results += @{
                Name = $inspection.Label
                Status = "Critical"
                Data = @{}
                Issues = @("Inspection failed: $($_.Exception.Message)")
                Details = @()
            }
        }
    }
    
    Write-Progress -Activity "Running Inspections" -Completed
    
    # Generate report
    Write-Host "[5/5] Generating report..." -ForegroundColor Yellow
    
    $endTime = Get-Date
    
    # Determine output path
    if (-not $OutputPath) {
        $outputDir = Join-Path $ScriptDir $Config.report.outputDir
        if (-not (Test-Path $outputDir)) {
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        }
        $OutputPath = Join-Path $outputDir "report-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"
    }
    
    $templatePath = Join-Path $ScriptDir "templates\report-template.html"
    
    # Add System.Web assembly for HTML encoding
    Add-Type -AssemblyName System.Web
    
    $reportPath = New-HTMLReport -Results $Results -Config $Config -TemplatePath $templatePath -OutputPath $OutputPath -StartTime $startTime -EndTime $endTime
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Inspection Complete!" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Summary
    Write-Host ""
    Write-Host "Status breakdown:" -ForegroundColor Gray
    $Results | ForEach-Object { Write-Host "  $($_.Name): $($_.Status)" -ForegroundColor Gray }
    
    # Debug: manually count fails
    $debugFail = @()
    foreach ($r in $Results) { if ($r.Status -eq "Critical") { $debugFail += $r.Name } }
    
    # Use manual counting instead of Where-Object to avoid filtering issues
    $passCount = 0; $warningCount = 0; $failCount = 0
    foreach ($r in $Results) {
        switch ($r.Status) {
            "Pass" { $passCount++ }
            "Warning" { $warningCount++ }
            "Critical" { $failCount++ }
        }
    }
    
    Write-Host "Summary:" -ForegroundColor White
    Write-Host "  Total Checks: $($Results.Count)" -ForegroundColor White
    Write-Host "  Passed: $passCount" -ForegroundColor Green
    Write-Host "  Warnings: $warningCount" -ForegroundColor Yellow
    Write-Host "  Failed: $failCount" -ForegroundColor Red
    Write-Host ""
    Write-Host "Report saved to: $reportPath" -ForegroundColor Green
    
    # Open report if requested
    if ($OpenReport) {
        Start-Process $reportPath
    }
    
    # Return exit code based on results
    if ($failCount -gt 0) {
        exit 2
    } elseif ($warningCount -gt 0) {
        exit 1
    } else {
        exit 0
    }
}

# Run main function
Main
