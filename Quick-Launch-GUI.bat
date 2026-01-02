@echo off
REM ================================================================
REM Enhanced Backup Manager - Quick Launcher
REM Author: Gianpaolo Albanese
REM Version: 2.0
REM Date: 2025-12-26
REM Notes: Enhanced by AI Assistant (Kiro) based on original work
REM        Original backup scripts created 2024-12-16
REM        Enhanced GUI and features added 2025-12-23
REM ================================================================
REM Double-click this file to launch the backup manager
REM ================================================================

title Enhanced Backup Manager - Quick Launch

REM Change to the directory where the batch file is located
cd /d "%~dp0"

REM Show what we're doing
echo.
echo ================================================================
echo  Enhanced Backup Manager - Starting Interface
echo ================================================================
echo.

REM Try GUI first, fallback to menu
echo Attempting to start GUI...
powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File "scripts\gui\BackupManagerGUI.ps1" 2>nul

REM If GUI failed, use menu interface
if %ERRORLEVEL% NEQ 0 (
    echo GUI unavailable, starting menu interface...
    powershell -ExecutionPolicy Bypass -File "scripts\gui\Backup-Menu.ps1"
) else (
    echo GUI started successfully
)

REM Exit
exit /b 0