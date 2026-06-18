@echo off
REM TDengine Inspection Tool - Quick Start
REM This batch file provides easy access to the inspection tool

:MENU
cls
echo ========================================
echo   TDengine Inspection Tool
echo ========================================
echo.
echo   1. Run Inspection (Default Settings)
echo   2. Run Inspection (Open Report)
echo   3. Run Inspection (Quiet Mode)
echo   4. Configure Task Scheduler
echo   5. List Scheduled Tasks
echo   6. Edit Configuration
echo   7. Exit
echo.
echo ========================================

set /p choice="Select option (1-7): "

if "%choice%"=="1" goto RUN
if "%choice%"=="2" goto RUN_OPEN
if "%choice%"=="3" goto RUN_QUIET
if "%choice%"=="4" goto SCHEDULE
if "%choice%"=="5" goto LIST_TASKS
if "%choice%"=="6" goto EDIT_CONFIG
if "%choice%"=="7" goto EXIT

echo Invalid choice. Please try again.
pause
goto MENU

:RUN
echo.
echo Running inspection...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0TDengine-Inspect.ps1"
echo.
pause
goto MENU

:RUN_OPEN
echo.
echo Running inspection and opening report...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0TDengine-Inspect.ps1" -OpenReport
echo.
pause
goto MENU

:RUN_QUIET
echo.
echo Running inspection (quiet mode)...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0TDengine-Inspect.ps1" -Quiet
echo.
pause
goto MENU

:SCHEDULE
echo.
echo Opening Task Scheduler setup...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0TaskScheduler.ps1"
echo.
pause
goto MENU

:LIST_TASKS
echo.
echo Listing scheduled tasks...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0TaskScheduler.ps1" -List
echo.
pause
goto MENU

:EDIT_CONFIG
echo.
echo Opening configuration file...
notepad "%~dp0config.json"
goto MENU

:EXIT
echo.
echo Thank you for using TDengine Inspection Tool!
exit /b 0
