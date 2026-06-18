# TDengine Inspection Task Scheduler
# Configures Windows Task Scheduler for automated inspections

param(
    [Parameter(Mandatory=$false)]
    [string]$TaskName = "TDengine Inspection",
    
    [Parameter(Mandatory=$false)]
    [string]$ScriptPath = ".\TDengine-Inspect.ps1",
    
    [Parameter(Mandatory=$false)]
    [string]$Schedule = "Daily",
    
    [Parameter(Mandatory=$false)]
    [string]$Time = "02:00",
    
    [Parameter(Mandatory=$false)]
    [int]$RepeatInterval = 0,
    
    [Parameter(Mandatory=$false)]
    [switch]$Remove,
    
    [Parameter(Mandatory=$false)]
    [switch]$List,
    
    [Parameter(Mandatory=$false)]
    [switch]$Run
)

function Show-TaskList {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  TDengine Inspection Tasks" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    $tasks = Get-ScheduledTask -TaskPath "\" -ErrorAction SilentlyContinue | 
        Where-Object { $_.TaskName -like "*TDengine*" -or $_.TaskName -like "*Inspection*" }
    
    if ($tasks) {
        foreach ($task in $tasks) {
            $info = Get-ScheduledTaskInfo -TaskName $task.TaskName -ErrorAction SilentlyContinue
            Write-Host "Task: $($task.TaskName)" -ForegroundColor Yellow
            Write-Host "  Status: $($task.State)" -ForegroundColor White
            Write-Host "  Last Run: $(if($info.LastRunTime -ne [datetime]::MinValue){$info.LastRunTime}else{'Never'})" -ForegroundColor White
            Write-Host "  Last Result: $($info.LastTaskResult)" -ForegroundColor White
            Write-Host "  Next Run: $(if($info.NextRunTime -ne [datetime]::MinValue){$info.NextRunTime}else{'Not Scheduled'})" -ForegroundColor White
            Write-Host ""
        }
    } else {
        Write-Host "No TDengine inspection tasks found." -ForegroundColor Gray
    }
}

function Remove-InspectionTask {
    param([string]$Name)
    
    try {
        $task = Get-ScheduledTask -TaskName $Name -ErrorAction SilentlyContinue
        
        if ($task) {
            Unregister-ScheduledTask -TaskName $Name -Confirm:$false
            Write-Host "Task '$Name' removed successfully." -ForegroundColor Green
        } else {
            Write-Host "Task '$Name' not found." -ForegroundColor Yellow
        }
    } catch {
        Write-Error "Failed to remove task: $_"
    }
}

function New-InspectionTask {
    param(
        [string]$Name,
        [string]$Script,
        [string]$ScheduleType,
        [string]$StartTime,
        [int]$Repeat
    )
    
    try {
        # Get full script path
        $fullScriptPath = Resolve-Path $Script -ErrorAction Stop
        
        # Create action
        $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$fullScriptPath`" -Quiet"
        
        # Create trigger based on schedule type
        switch ($ScheduleType.ToLower()) {
            "daily" {
                $trigger = New-ScheduledTaskTrigger -Daily -At $StartTime
            }
            "weekly" {
                $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At $StartTime
            }
            "hourly" {
                $trigger = New-ScheduledTaskTrigger -Once -At $StartTime -RepetitionInterval (New-TimeSpan -Hours 1)
            }
            "startup" {
                $trigger = New-ScheduledTaskTrigger -AtStartup
            }
            default {
                $trigger = New-ScheduledTaskTrigger -Daily -At $StartTime
            }
        }
        
        # Add repeat interval if specified
        if ($Repeat -gt 0 -and $ScheduleType.ToLower() -notin @("hourly")) {
            $trigger.Repetition.Interval = [System.Xml.XmlConvert]::ToString([TimeSpan]::FromMinutes($Repeat))
        }
        
        # Create settings
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable
        
        # Create principal (run as current user)
        $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType S4U -RunLevel Highest
        
        # Register task
        $task = Register-ScheduledTask -TaskName $Name -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description "TDengine Database Inspection Task"
        
        Write-Host "Task '$Name' created successfully!" -ForegroundColor Green
        Write-Host "  Schedule: $ScheduleType at $StartTime" -ForegroundColor White
        Write-Host "  Script: $fullScriptPath" -ForegroundColor White
        
        return $task
    } catch {
        Write-Error "Failed to create task: $_"
    }
}

function Start-InspectionNow {
    param([string]$Name)
    
    try {
        $task = Get-ScheduledTask -TaskName $Name -ErrorAction SilentlyContinue
        
        if ($task) {
            Start-ScheduledTask -TaskName $Name
            Write-Host "Task '$Name' started." -ForegroundColor Green
        } else {
            Write-Host "Task '$Name' not found. Creating and running..." -ForegroundColor Yellow
            New-InspectionTask -Name $Name -Script $ScriptPath -ScheduleType "Daily" -StartTime "00:00"
            Start-ScheduledTask -TaskName $Name
        }
    } catch {
        Write-Error "Failed to start task: $_"
    }
}

# Main execution
if ($List) {
    Show-TaskList
} elseif ($Remove) {
    Remove-InspectionTask -Name $TaskName
} elseif ($Run) {
    Start-InspectionNow -Name $TaskName
} else {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  TDengine Task Scheduler Setup" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Interactive setup
    Write-Host "Schedule Options:" -ForegroundColor Yellow
    Write-Host "  1. Daily - Run once per day" -ForegroundColor White
    Write-Host "  2. Weekly - Run once per week (Monday)" -ForegroundColor White
    Write-Host "  3. Hourly - Run every hour" -ForegroundColor White
    Write-Host "  4. Startup - Run at system startup" -ForegroundColor White
    Write-Host ""
    
    $choice = Read-Host "Select schedule type (1-4) [default: 1]"
    
    $scheduleType = switch ($choice) {
        "2" { "Weekly" }
        "3" { "Hourly" }
        "4" { "Startup" }
        default { "Daily" }
    }
    
    if ($scheduleType -ne "Startup") {
        $timeInput = Read-Host "Enter start time (HH:mm) [default: $Time]"
        if ($timeInput) { $Time = $timeInput }
    }
    
    $taskNameInput = Read-Host "Enter task name [default: $TaskName]"
    if ($taskNameInput) { $TaskName = $taskNameInput }
    
    Write-Host ""
    Write-Host "Creating scheduled task..." -ForegroundColor Yellow
    
    New-InspectionTask -Name $TaskName -Script $ScriptPath -ScheduleType $scheduleType -StartTime $Time -Repeat $RepeatInterval
    
    Write-Host ""
    Write-Host "Setup complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Useful commands:" -ForegroundColor Yellow
    Write-Host "  List tasks: .\TaskScheduler.ps1 -List" -ForegroundColor White
    Write-Host "  Remove task: .\TaskScheduler.ps1 -Remove -TaskName `"$TaskName`"" -ForegroundColor White
    Write-Host "  Run now: .\TaskScheduler.ps1 -Run -TaskName `"$TaskName`"" -ForegroundColor White
}
