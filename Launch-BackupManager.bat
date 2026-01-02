@echo off
REM ================================================================
REM Enhanced Backup Manager - Easy Launcher
REM Author: Gianpaolo Albanese
REM Version: 2.0
REM Date: 2025-12-23
REM Notes: Enhanced by AI Assistant (Kiro) based on original work
REM        Original backup scripts created 2024-12-16
REM        Enhanced GUI and features added 2025-12-23
REM ================================================================
REM This batch file makes it easy to launch the backup tool
REM No PowerShell knowledge required - just double-click to run!
REM ================================================================

title Enhanced Backup Manager Launcher

echo.
echo ================================================================
echo                 ENHANCED BACKUP MANAGER
echo                      Easy Launcher
echo ================================================================
echo.
echo Welcome! This tool will help you backup your files to AWS S3.
echo.
echo Checking system requirements...
echo.

REM Check if PowerShell is available
powershell -Command "Write-Host 'PowerShell: Available' -ForegroundColor Green"
if %errorlevel% neq 0 (
    echo ERROR: PowerShell is not available on this system.
    echo Please install PowerShell 5.1 or later.
    pause
    exit /b 1
)

REM Check if required files exist
if not exist "scripts\gui\BackupManagerGUI.ps1" (
    echo ERROR: BackupManagerGUI.ps1 not found in scripts\gui directory.
    echo Please make sure all backup manager files are in the correct folders.
    pause
    exit /b 1
)

if not exist "scripts\core\BackupSharedFunctions.ps1" (
    echo ERROR: BackupSharedFunctions.ps1 not found in scripts\core directory.
    echo Please make sure all backup manager files are in the correct folders.
    pause
    exit /b 1
)

echo System requirements: OK
echo.
echo ================================================================
echo                    LAUNCH OPTIONS
echo ================================================================
echo.
echo === MAIN OPERATIONS ===
echo 1. Launch GUI Interface (Recommended for new users)
echo 2. Launch Quick Menu (Command line interface)
echo 3. Run Backup (Direct backup with current settings)
echo 4. Run Restore (Direct restore with current settings)
echo.
echo === CONFIGURATION ===
echo 5. Review Current Configuration
echo 6. Update Configuration Settings
echo 7. Configure Scheduled Backups
echo.
echo === HELP ^& SUPPORT ===
echo 8. View Help and Exit
echo.
set /p choice="Please select an option (1-8): "

if "%choice%"=="1" goto launch_gui
if "%choice%"=="2" goto launch_menu
if "%choice%"=="3" goto run_backup
if "%choice%"=="4" goto run_restore
if "%choice%"=="5" goto review_config
if "%choice%"=="6" goto update_config
if "%choice%"=="7" goto configure_schedule
if "%choice%"=="8" goto show_help
goto invalid_choice

:launch_gui
echo.
echo Launching Enhanced Backup Manager GUI...
echo Please wait while the graphical interface loads...
echo.
powershell -ExecutionPolicy Bypass -File "scripts\gui\BackupManagerGUI.ps1"
goto end

:launch_menu
echo.
echo Launching Quick Menu...
echo.
powershell -ExecutionPolicy Bypass -File "Launch-BackupManager.ps1"
goto end

:run_backup
echo.
echo Starting backup operation...
echo This will use your current configuration settings.
echo.
powershell -ExecutionPolicy Bypass -File "scripts\core\BackupEngine.ps1" -Operation Backup
pause
goto end

:run_restore
echo.
echo Starting restore operation...
echo This will use your current configuration settings.
echo.
powershell -ExecutionPolicy Bypass -File "scripts\core\BackupEngine.ps1" -Operation Restore
pause
goto end

:review_config
echo.
echo ================================================================
echo                   CURRENT CONFIGURATION REVIEW
echo ================================================================
echo.
if not exist "BackupConfig.json" (
    echo ERROR: Configuration file not found!
    echo Please run the GUI first to create initial configuration.
    echo.
    pause
    goto start
)

echo Reading current configuration...
echo.
powershell -ExecutionPolicy Bypass -Command "& { $config = Get-Content 'BackupConfig.json' | ConvertFrom-Json; Write-Host '=== BACKUP CONFIGURATION ===' -ForegroundColor Yellow; Write-Host ''; Write-Host 'Backup Type:' $config.BackupType -ForegroundColor Green; Write-Host 'S3 Bucket:' $config.S3Bucket -ForegroundColor Green; Write-Host 'AWS Profile:' $config.AWSProfile -ForegroundColor Green; Write-Host 'Backup Destination:' $config.BackupDestination -ForegroundColor Green; Write-Host 'Restore Destination:' $config.RestoreDestination -ForegroundColor Green; Write-Host ''; Write-Host '=== BACKUP FOLDERS ===' -ForegroundColor Yellow; $config.BackupFolders | ForEach-Object { $status = if ($_.Enabled) { '[ENABLED]' } else { '[DISABLED]' }; Write-Host $status $_.Source '->' $_.Destination -ForegroundColor $(if ($_.Enabled) { 'Green' } else { 'Gray' }) }; Write-Host ''; Write-Host '=== SETTINGS ===' -ForegroundColor Yellow; Write-Host 'Log Level:' $config.LogLevel -ForegroundColor Green; Write-Host 'Schedule Enabled:' $config.ScheduleEnabled -ForegroundColor Green; if ($config.ScheduleEnabled) { Write-Host 'Schedule:' $config.ScheduleFrequency 'at' $config.ScheduleTime -ForegroundColor Green }; Write-Host 'Verify Backups:' $config.VerifyBackups -ForegroundColor Green; Write-Host 'Max Backup Versions:' $config.MaxBackupVersions -ForegroundColor Green; Write-Host ''; Write-Host '=== EXCLUDE PATTERNS ===' -ForegroundColor Yellow; $config.ExcludePatterns | ForEach-Object { Write-Host '  -' $_ -ForegroundColor Cyan } }"
echo.
echo Configuration review complete.
echo.
echo TIP: To modify these settings, choose option 6 (Update Configuration)
echo      or use option 1 (GUI Interface) for a visual editor.
echo.
pause
goto start

:update_config
echo.
echo ================================================================
echo                   UPDATE CONFIGURATION
echo ================================================================
echo.
echo Choose what you want to update:
echo.
echo 1. AWS Settings (S3 Bucket, Profile, Backup Type)
echo 2. Backup Folders (Add/Remove/Enable/Disable folders)
echo 3. Restore Destination
echo 4. Logging Settings
echo 5. Exclude Patterns
echo 6. Open Configuration File in Notepad
echo 7. Reset Configuration to Defaults
echo 8. Back to Main Menu
echo.
set /p config_choice="Select configuration option (1-8): "

if "%config_choice%"=="1" goto update_aws
if "%config_choice%"=="2" goto update_folders
if "%config_choice%"=="3" goto update_restore
if "%config_choice%"=="4" goto update_logging
if "%config_choice%"=="5" goto update_exclude
if "%config_choice%"=="6" goto edit_config_file
if "%config_choice%"=="7" goto reset_config
if "%config_choice%"=="8" goto start
goto invalid_config_choice

:update_aws
echo.
echo Updating AWS Settings...
echo.
echo Current AWS configuration will be displayed, then you can make changes.
echo.
powershell -ExecutionPolicy Bypass -Command "& { Write-Host 'Opening AWS configuration update...' -ForegroundColor Green; $config = Get-Content 'BackupConfig.json' | ConvertFrom-Json; Write-Host ''; Write-Host 'Current S3 Bucket:' $config.S3Bucket -ForegroundColor Yellow; $newBucket = Read-Host 'Enter new S3 bucket name (or press Enter to keep current)'; if ($newBucket) { $config.S3Bucket = $newBucket }; Write-Host 'Current AWS Profile:' $config.AWSProfile -ForegroundColor Yellow; $newProfile = Read-Host 'Enter new AWS profile (or press Enter to keep current)'; if ($newProfile) { $config.AWSProfile = $newProfile }; Write-Host 'Current Backup Type:' $config.BackupType -ForegroundColor Yellow; Write-Host 'Available types: AWS_S3, Local, Network'; $newType = Read-Host 'Enter new backup type (or press Enter to keep current)'; if ($newType) { $config.BackupType = $newType }; $config | ConvertTo-Json -Depth 10 | Set-Content 'BackupConfig.json'; Write-Host ''; Write-Host 'AWS settings updated successfully!' -ForegroundColor Green }"
echo.
pause
goto update_config

:update_folders
echo.
echo Launching GUI for folder management...
echo The GUI provides the best interface for managing backup folders.
echo.
powershell -ExecutionPolicy Bypass -File "scripts\gui\BackupManagerGUI.ps1"
goto update_config

:update_restore
echo.
echo Updating Restore Destination...
echo.
powershell -ExecutionPolicy Bypass -Command "& { $config = Get-Content 'BackupConfig.json' | ConvertFrom-Json; Write-Host 'Current Restore Destination:' $config.RestoreDestination -ForegroundColor Yellow; Write-Host ''; Write-Host 'Enter new restore destination path:'; Write-Host 'Examples:'; Write-Host '  C:\Restored_Files'; Write-Host '  \\\\server\\share\\restored'; Write-Host ''; $newDest = Read-Host 'New restore destination'; if ($newDest) { $config.RestoreDestination = $newDest; $config | ConvertTo-Json -Depth 10 | Set-Content 'BackupConfig.json'; Write-Host ''; Write-Host 'Restore destination updated successfully!' -ForegroundColor Green } else { Write-Host 'No changes made.' -ForegroundColor Yellow } }"
echo.
pause
goto update_config

:update_logging
echo.
echo Updating Logging Settings...
echo.
powershell -ExecutionPolicy Bypass -Command "& { $config = Get-Content 'BackupConfig.json' | ConvertFrom-Json; Write-Host 'Current Log Level:' $config.LogLevel -ForegroundColor Yellow; Write-Host ''; Write-Host 'Available log levels:'; Write-Host '  MINIMAL  - Only errors and success messages'; Write-Host '  INFO     - General information + errors'; Write-Host '  DETAILED - Detailed information + file operations'; Write-Host '  ALL      - Everything including debug info'; Write-Host ''; $newLevel = Read-Host 'Enter new log level (MINIMAL/INFO/DETAILED/ALL)'; if ($newLevel -and $newLevel -in @('MINIMAL','INFO','DETAILED','ALL')) { $config.LogLevel = $newLevel; $config | ConvertTo-Json -Depth 10 | Set-Content 'BackupConfig.json'; Write-Host ''; Write-Host 'Log level updated successfully!' -ForegroundColor Green } else { Write-Host 'Invalid log level or no changes made.' -ForegroundColor Yellow } }"
echo.
pause
goto update_config

:update_exclude
echo.
echo Current exclude patterns prevent certain files from being backed up.
echo Opening configuration for exclude pattern management...
echo.
powershell -ExecutionPolicy Bypass -Command "& { $config = Get-Content 'BackupConfig.json' | ConvertFrom-Json; Write-Host 'Current exclude patterns:' -ForegroundColor Yellow; $config.ExcludePatterns | ForEach-Object { Write-Host '  ' $_ -ForegroundColor Cyan }; Write-Host ''; Write-Host 'Common patterns to exclude:'; Write-Host '  *.tmp, *.log, *.cache, Thumbs.db, .DS_Store'; Write-Host '  node_modules, .git, __pycache__'; Write-Host ''; Write-Host 'For detailed exclude pattern editing, use option 6 to edit the config file directly.'; Write-Host 'Or use the GUI (option 1 from main menu) for easier management.' }"
echo.
pause
goto update_config

:edit_config_file
echo.
echo Opening configuration file in Notepad...
echo.
echo IMPORTANT: Make sure to save the file with valid JSON syntax!
echo If you break the JSON format, the backup system won't work.
echo.
pause
notepad BackupConfig.json
echo.
echo Configuration file editing complete.
echo Testing configuration validity...
echo.
powershell -ExecutionPolicy Bypass -Command "& { try { $config = Get-Content 'BackupConfig.json' | ConvertFrom-Json; Write-Host 'Configuration file is valid!' -ForegroundColor Green } catch { Write-Host 'ERROR: Configuration file has invalid JSON syntax!' -ForegroundColor Red; Write-Host 'Please fix the syntax errors and try again.' -ForegroundColor Red } }"
echo.
pause
goto update_config

:reset_config
echo.
echo ================================================================
echo                    RESET CONFIGURATION
echo ================================================================
echo.
echo WARNING: This will reset ALL configuration settings to defaults!
echo You will lose all current settings including:
echo - AWS credentials and S3 bucket settings
echo - Backup folder selections
echo - Custom exclude patterns
echo - Scheduling settings
echo.
set /p confirm="Are you sure you want to reset? (type YES to confirm): "
if /i "%confirm%"=="YES" (
    echo.
    echo Resetting configuration...
    powershell -ExecutionPolicy Bypass -File "scripts\utilities\Clear-BackupConfig.ps1"
    echo.
    echo Configuration has been reset to defaults.
    echo You will need to reconfigure your settings using the GUI.
    echo.
) else (
    echo.
    echo Reset cancelled.
    echo.
)
pause
goto update_config

:invalid_config_choice
echo.
echo Invalid choice. Please select a number between 1-8.
echo.
pause
goto update_config

:configure_schedule
echo.
echo Launching scheduler configuration...
echo.
powershell -ExecutionPolicy Bypass -File "scripts\core\BackupScheduler.ps1"
goto end

:show_help
echo.
echo ================================================================
echo                    ENHANCED BACKUP MANAGER
echo                         HELP GUIDE
echo ================================================================
echo.
echo WHAT IS THIS TOOL?
echo This is a comprehensive backup solution that helps you:
echo - Backup your important files to Amazon S3 cloud storage
echo - Restore files from S3 back to your computer
echo - Schedule automatic backups
echo - Monitor backup progress and logs
echo.
echo GETTING STARTED:
echo 1. First time users should choose option 1 (GUI Interface)
echo 2. In the GUI, go to Configuration tab to set up AWS credentials
echo 3. Use the Backup Folders tab to select what to backup
echo 4. Test with a "Dry Run" before doing actual backups
echo.
echo REQUIREMENTS:
echo - AWS CLI installed (https://aws.amazon.com/cli/)
echo - AWS account with S3 access
echo - Configured AWS credentials (run 'aws configure')
echo.
echo SUPPORT:
echo - Use the Help tab in the GUI for detailed instructions
echo - Check the Logs tab for troubleshooting
echo - All operations are logged to your Desktop
echo.
echo For more information, launch the GUI and check the Help tab.
echo.
pause
goto end

:invalid_choice
echo.
echo Invalid choice. Please select a number between 1-8.
echo.
pause
goto start

:end
echo.
echo Thank you for using Enhanced Backup Manager!
echo.
pause
exit /b 0

:start
REM This label is used for restarting the menu
goto :eof