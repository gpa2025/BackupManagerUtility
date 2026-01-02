#Requires -Version 5.1
<#
.SYNOPSIS
    Simple Menu-Based Backup Manager
.DESCRIPTION
    A simple text-based menu interface for the backup system while the GUI is being fixed
.AUTHOR
    Enhanced by AI Assistant (Kiro)
.VERSION
    1.0
.DATE
    2025-12-26
#>

# Import shared functions
. "$PSScriptRoot\..\core\BackupSharedFunctions.ps1"

function Show-Menu {
    Clear-Host
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Blue
    Write-Host "           ENHANCED BACKUP MANAGER - MENU INTERFACE           " -ForegroundColor Green
    Write-Host "================================================================" -ForegroundColor Blue
    Write-Host ""
    Write-Host "  1. Run Backup (Upload to S3)" -ForegroundColor White
    Write-Host "  2. Run Backup (Dry Run - Test Only)" -ForegroundColor White
    Write-Host "  3. Run Restore (Download from S3)" -ForegroundColor White
    Write-Host "  4. View Configuration" -ForegroundColor White
    Write-Host "  5. Update Configuration" -ForegroundColor Cyan
    Write-Host "  6. View Recent Logs" -ForegroundColor White
    Write-Host "  7. Test AWS Connection" -ForegroundColor White
    Write-Host "  8. Monitor Logs (Real-time)" -ForegroundColor White
    Write-Host "  9. Clear Configuration" -ForegroundColor White
    Write-Host " 10. Exit" -ForegroundColor White
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Blue
    Write-Host ""
}

function Show-Config {
    $config = Load-Config
    Write-Host ""
    Write-Host "=== CURRENT CONFIGURATION ===" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Backup Settings:" -ForegroundColor Cyan
    Write-Host "  Backup Type: $($config.BackupType)" -ForegroundColor White
    Write-Host "  S3 Bucket: $($config.S3Bucket)" -ForegroundColor White
    Write-Host "  AWS Profile: $($config.AWSProfile)" -ForegroundColor White
    Write-Host "  Restore Destination: $($config.RestoreDestination)" -ForegroundColor White
    Write-Host ""
    Write-Host "Logging Settings:" -ForegroundColor Cyan
    Write-Host "  Log Level: $($config.LogLevel)" -ForegroundColor White
    Write-Host "  Log File Operations: $($config.LogFileOperations)" -ForegroundColor White
    Write-Host "  Log Failures Only: $($config.LogFailuresOnly)" -ForegroundColor White
    Write-Host ""
    Write-Host "Advanced Settings:" -ForegroundColor Cyan
    Write-Host "  Use Compression: $($config.UseCompression)" -ForegroundColor White
    Write-Host "  Verify Backups: $($config.VerifyBackups)" -ForegroundColor White
    Write-Host "  Max Backup Versions: $($config.MaxBackupVersions)" -ForegroundColor White
    Write-Host ""
    Write-Host "Enabled Folders:" -ForegroundColor Cyan
    foreach ($folder in $config.BackupFolders) {
        $status = if ($folder.Enabled) { "[YES]" } else { "[NO]" }
        Write-Host "  $status $($folder.Source) -> $($folder.Destination)" -ForegroundColor White
    }
    Write-Host ""
    Write-Host "Exclude Patterns:" -ForegroundColor Cyan
    foreach ($pattern in $config.ExcludePatterns) {
        Write-Host "  - $pattern" -ForegroundColor White
    }
    Write-Host ""
}

function Update-Config {
    $config = Load-Config
    
    do {
        Clear-Host
        Write-Host ""
        Write-Host "=== UPDATE CONFIGURATION ===" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "What would you like to update?" -ForegroundColor White
        Write-Host ""
        Write-Host "  1. S3 Bucket Name" -ForegroundColor White
        Write-Host "  2. AWS Profile" -ForegroundColor White
        Write-Host "  3. Restore Destination" -ForegroundColor White
        Write-Host "  4. Log Level" -ForegroundColor White
        Write-Host "  5. Logging Options" -ForegroundColor White
        Write-Host "  6. Backup Folders (Enable/Disable)" -ForegroundColor White
        Write-Host "  7. Add Custom Folder" -ForegroundColor White
        Write-Host "  8. Exclude Patterns" -ForegroundColor White
        Write-Host "  9. Advanced Settings" -ForegroundColor White
        Write-Host " 10. Save and Return to Main Menu" -ForegroundColor Green
        Write-Host ""
        
        $choice = Read-Host "Select option (1-10)"
        
        switch ($choice) {
            "1" {
                Write-Host ""
                Write-Host "Current S3 Bucket: $($config.S3Bucket)" -ForegroundColor Cyan
                $newBucket = Read-Host "Enter new S3 bucket name (or press Enter to keep current)"
                if ($newBucket -and $newBucket.Trim() -ne "") {
                    $config.S3Bucket = $newBucket.Trim()
                    Write-Host "S3 bucket updated to: $($config.S3Bucket)" -ForegroundColor Green
                }
            }
            "2" {
                Write-Host ""
                Write-Host "Current AWS Profile: $($config.AWSProfile)" -ForegroundColor Cyan
                $newProfile = Read-Host "Enter new AWS profile name (or press Enter to keep current)"
                if ($newProfile -and $newProfile.Trim() -ne "") {
                    $config.AWSProfile = $newProfile.Trim()
                    Write-Host "AWS profile updated to: $($config.AWSProfile)" -ForegroundColor Green
                }
            }
            "3" {
                Write-Host ""
                Write-Host "Current Restore Destination: $($config.RestoreDestination)" -ForegroundColor Cyan
                $newDest = Read-Host "Enter new restore destination path (or press Enter to keep current)"
                if ($newDest -and $newDest.Trim() -ne "") {
                    $config.RestoreDestination = $newDest.Trim()
                    Write-Host "Restore destination updated to: $($config.RestoreDestination)" -ForegroundColor Green
                }
            }
            "4" {
                Write-Host ""
                Write-Host "Current Log Level: $($config.LogLevel)" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "Available log levels:" -ForegroundColor White
                Write-Host "  MINIMAL  - Only errors and success messages" -ForegroundColor Gray
                Write-Host "  INFO     - Basic operation info (default)" -ForegroundColor Gray
                Write-Host "  DETAILED - Includes file operation summaries" -ForegroundColor Gray
                Write-Host "  ALL      - Every individual file operation" -ForegroundColor Gray
                Write-Host ""
                $newLevel = Read-Host "Enter new log level (MINIMAL/INFO/DETAILED/ALL) or press Enter to keep current"
                if ($newLevel -and $newLevel.Trim() -ne "" -and $newLevel.ToUpper() -in @("MINIMAL", "INFO", "DETAILED", "ALL")) {
                    $config.LogLevel = $newLevel.ToUpper()
                    Write-Host "Log level updated to: $($config.LogLevel)" -ForegroundColor Green
                } elseif ($newLevel -and $newLevel.Trim() -ne "") {
                    Write-Host "Invalid log level. Please use MINIMAL, INFO, DETAILED, or ALL." -ForegroundColor Red
                }
            }
            "5" {
                Write-Host ""
                Write-Host "Current Logging Options:" -ForegroundColor Cyan
                Write-Host "  Log File Operations: $($config.LogFileOperations)" -ForegroundColor White
                Write-Host "  Log Failures Only: $($config.LogFailuresOnly)" -ForegroundColor White
                Write-Host ""
                
                $logFileOps = Read-Host "Log individual file operations? (true/false) or press Enter to keep current"
                if ($logFileOps -and $logFileOps.ToLower() -in @("true", "false")) {
                    $config.LogFileOperations = [bool]::Parse($logFileOps)
                    Write-Host "Log file operations updated to: $($config.LogFileOperations)" -ForegroundColor Green
                }
                
                $logFailuresOnly = Read-Host "Log failures only? (true/false) or press Enter to keep current"
                if ($logFailuresOnly -and $logFailuresOnly.ToLower() -in @("true", "false")) {
                    $config.LogFailuresOnly = [bool]::Parse($logFailuresOnly)
                    Write-Host "Log failures only updated to: $($config.LogFailuresOnly)" -ForegroundColor Green
                }
            }
            "6" {
                Write-Host ""
                Write-Host "Current Backup Folders:" -ForegroundColor Cyan
                for ($i = 0; $i -lt $config.BackupFolders.Count; $i++) {
                    $folder = $config.BackupFolders[$i]
                    $status = if ($folder.Enabled) { "[ENABLED]" } else { "[DISABLED]" }
                    Write-Host "  $($i+1). $status $($folder.Source) -> $($folder.Destination)" -ForegroundColor White
                }
                Write-Host ""
                $folderNum = Read-Host "Enter folder number to toggle (1-$($config.BackupFolders.Count)) or press Enter to skip"
                if ($folderNum -and $folderNum -match '^\d+$' -and [int]$folderNum -ge 1 -and [int]$folderNum -le $config.BackupFolders.Count) {$' -and [int]$folderNum -ge 1 -and [int]$folderNum -le $config.BackupFolders.Count) {
                    $index = [int]$folderNum - 1
                    $config.BackupFolders[$index].Enabled = -not $config.BackupFolders[$index].Enabled
                    $newStatus = if ($config.BackupFolders[$index].Enabled) { "ENABLED" } else { "DISABLED" }
                    Write-Host "Folder $folderNum is now $newStatus" -ForegroundColor Green
                }
            }
            "7" {
                Write-Host ""
                Write-Host "Add Custom Backup Folder:" -ForegroundColor Cyan
                $sourcePath = Read-Host "Enter source folder path"
                if ($sourcePath -and $sourcePath.Trim() -ne "") {
                    if (Test-Path $sourcePath.Trim()) {
                        $destName = Read-Host "Enter destination name (folder name in S3)"
                        if ($destName -and $destName.Trim() -ne "") {
                            $newFolder = @{
                                Source = $sourcePath.Trim()
                                Destination = $destName.Trim()
                                Enabled = $true
                            }
                            $config.BackupFolders += $newFolder
                            Write-Host "Added new backup folder: $($sourcePath.Trim()) -> $($destName.Trim())" -ForegroundColor Green
                        }
                    } else {
                        Write-Host "Source path does not exist: $sourcePath" -ForegroundColor Red
                    }
                }
            }
            "8" {
                Write-Host ""
                Write-Host "Current Exclude Patterns:" -ForegroundColor Cyan
                for ($i = 0; $i -lt $config.ExcludePatterns.Count; $i++) {
                    Write-Host "  $($i+1). $($config.ExcludePatterns[$i])" -ForegroundColor White
                }
                Write-Host ""
                Write-Host "Options:" -ForegroundColor White
                Write-Host "  A - Add new pattern" -ForegroundColor White
                Write-Host "  R - Remove pattern" -ForegroundColor White
                Write-Host "  Enter - Skip" -ForegroundColor White
                
                $action = Read-Host "Choose action (A/R/Enter)"
                if ($action.ToUpper() -eq "A") {
                    $newPattern = Read-Host "Enter new exclude pattern (e.g., *.tmp, *.bak)"
                    if ($newPattern -and $newPattern.Trim() -ne "") {
                        $config.ExcludePatterns += $newPattern.Trim()
                        Write-Host "Added exclude pattern: $($newPattern.Trim())" -ForegroundColor Green
                    }
                } elseif ($action.ToUpper() -eq "R") {
                    $patternNum = Read-Host "Enter pattern number to remove (1-$($config.ExcludePatterns.Count))"
                    if ($patternNum -and $patternNum -match '^\d+$' -and [int]$patternNum -ge 1 -and [int]$patternNum -le $config.ExcludePatterns.Count) {$' -and [int]$patternNum -ge 1 -and [int]$patternNum -le $config.ExcludePatterns.Count) {
                        $removedPattern = $config.ExcludePatterns[[int]$patternNum - 1]
                        $config.ExcludePatterns = $config.ExcludePatterns | Where-Object { $_ -ne $removedPattern }
                        Write-Host "Removed exclude pattern: $removedPattern" -ForegroundColor Green
                    }
                }
            }
            "9" {
                Write-Host ""
                Write-Host "Advanced Settings:" -ForegroundColor Cyan
                Write-Host "  Use Compression: $($config.UseCompression)" -ForegroundColor White
                Write-Host "  Verify Backups: $($config.VerifyBackups)" -ForegroundColor White
                Write-Host "  Max Backup Versions: $($config.MaxBackupVersions)" -ForegroundColor White
                Write-Host ""
                
                $compression = Read-Host "Use compression? (true/false) or press Enter to keep current"
                if ($compression -and $compression.ToLower() -in @("true", "false")) {
                    $config.UseCompression = [bool]::Parse($compression)
                    Write-Host "Use compression updated to: $($config.UseCompression)" -ForegroundColor Green
                }
                
                $verify = Read-Host "Verify backups? (true/false) or press Enter to keep current"
                if ($verify -and $verify.ToLower() -in @("true", "false")) {
                    $config.VerifyBackups = [bool]::Parse($verify)
                    Write-Host "Verify backups updated to: $($config.VerifyBackups)" -ForegroundColor Green
                }
                
                $maxVersions = Read-Host "Max backup versions (number) or press Enter to keep current"
                if ($maxVersions -and $maxVersions -match '^\d+$') {$') {
                    $config.MaxBackupVersions = [int]$maxVersions
                    Write-Host "Max backup versions updated to: $($config.MaxBackupVersions)" -ForegroundColor Green
                }
            }
            "10" {
                Write-Host ""
                Write-Host "Saving configuration..." -ForegroundColor Yellow
                Save-Config $config
                Write-Host "Configuration saved successfully!" -ForegroundColor Green
                Write-Host ""
                Write-Host "Press any key to return to main menu..." -ForegroundColor Gray
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                return
            }
            default {
                Write-Host ""
                Write-Host "Invalid option. Please select 1-10." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
        
        if ($choice -ne "10") {
            Write-Host ""
            Write-Host "Press any key to continue..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        
    } while ($choice -ne "10")
}

function Show-RecentLogs {
    $logPath = "$env:USERPROFILE\Desktop\BackupEngine.log"
    if (Test-Path $logPath) {
        Write-Host ""
        Write-Host "=== RECENT LOG ENTRIES ===" -ForegroundColor Yellow
        $recentLogs = Get-Content $logPath -Tail 20
        foreach ($line in $recentLogs) {
            if ($line -match "\[ERROR\]") {
                Write-Host $line -ForegroundColor Red
            } elseif ($line -match "\[SUCCESS\]") {
                Write-Host $line -ForegroundColor Green
            } elseif ($line -match "\[WARNING\]") {
                Write-Host $line -ForegroundColor Yellow
            } else {
                Write-Host $line -ForegroundColor White
            }
        }
    } else {
        Write-Host "No log file found." -ForegroundColor Red
    }
    Write-Host ""
}

function Test-AWS {
    Write-Host ""
    Write-Host "=== TESTING AWS CONNECTION ===" -ForegroundColor Yellow
    
    try {
        Write-Host "Testing AWS CLI..." -ForegroundColor White
        $awsVersion = aws --version 2>&1
        Write-Host "[OK] AWS CLI: $awsVersion" -ForegroundColor Green
        
        Write-Host "Testing AWS credentials..." -ForegroundColor White
        $identity = aws sts get-caller-identity --profile default 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] AWS credentials working" -ForegroundColor Green
        } else {
            Write-Host "[FAIL] AWS credentials failed: $identity" -ForegroundColor Red
        }
        
        Write-Host "Testing S3 bucket access..." -ForegroundColor White
        $config = Load-Config
        aws s3api head-bucket --bucket $config.S3Bucket --profile default 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] S3 bucket '$($config.S3Bucket)' accessible" -ForegroundColor Green
        } else {
            Write-Host "[FAIL] S3 bucket '$($config.S3Bucket)' not accessible" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "[FAIL] AWS test failed: $_" -ForegroundColor Red
    }
    Write-Host ""
}

# Main menu loop
do {
    Show-Menu
    $choice = Read-Host "Select an option (1-10)"
    
    switch ($choice) {
        "1" {
            Write-Host ""
            Write-Host "Starting backup operation..." -ForegroundColor Green
            & "$PSScriptRoot\..\core\BackupEngine.ps1" -Operation Backup
            Write-Host ""
            Write-Host "Press any key to continue..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        "2" {
            Write-Host ""
            Write-Host "Starting dry run backup..." -ForegroundColor Green
            & "$PSScriptRoot\..\core\BackupEngine.ps1" -Operation Backup -DryRun
            Write-Host ""
            Write-Host "Press any key to continue..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        "3" {
            Write-Host ""
            Write-Host "Starting restore operation..." -ForegroundColor Green
            & "$PSScriptRoot\..\core\BackupEngine.ps1" -Operation Restore
            Write-Host ""
            Write-Host "Press any key to continue..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        "4" {
            Show-Config
            Write-Host "Press any key to continue..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        "5" {
            Update-Config
        }
        "6" {
            Show-RecentLogs
            Write-Host "Press any key to continue..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        "7" {
            Test-AWS
            Write-Host "Press any key to continue..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        "8" {
            Write-Host ""
            Write-Host "Starting real-time log monitor..." -ForegroundColor Green
            Write-Host "Press Ctrl+C to stop monitoring" -ForegroundColor Yellow
            & "$PSScriptRoot\Watch-BackupLog.ps1"
        }
        "9" {
            Write-Host ""
            $confirm = Read-Host "Are you sure you want to clear the configuration? (y/N)"
            if ($confirm -eq 'y' -or $confirm -eq 'Y') {
                & "$PSScriptRoot\Clear-BackupConfig.ps1"
            }
            Write-Host ""
            Write-Host "Press any key to continue..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        "10" {
            Write-Host ""
            Write-Host "Goodbye!" -ForegroundColor Green
            break
        }
        default {
            Write-Host ""
            Write-Host "Invalid option. Please select 1-10." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
} while ($choice -ne "10")