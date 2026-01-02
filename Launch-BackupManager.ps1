#Requires -Version 5.1
<#
.SYNOPSIS
    Quick Launcher for Enhanced Backup Manager
.DESCRIPTION
    Provides a simple menu-driven interface to launch different components
    of the Enhanced Backup Manager system.
.AUTHOR
    Gianpaolo Albanese
.VERSION
    2.0
.DATE
    2025-12-23
.NOTES
    Enhanced by AI Assistant (Kiro) based on original work by Gianpaolo Albanese
    Original backup scripts created 2024-12-16
    Enhanced GUI and features added 2025-12-23
#>

function Show-MainMenu {
    Clear-Host
    Write-Host ""
    Write-Host "==============================================================" -ForegroundColor Blue
    Write-Host "                 ENHANCED BACKUP MANAGER                    " -ForegroundColor Green
    Write-Host "                      QUICK LAUNCHER                        " -ForegroundColor Green
    Write-Host "==============================================================" -ForegroundColor Blue
    Write-Host ""
    Write-Host "Please select an option:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Launch GUI Interface" -ForegroundColor White
    Write-Host "2. Configure Scheduled Backups" -ForegroundColor White
    Write-Host "3. Run Manual Backup" -ForegroundColor White
    Write-Host "4. Run Manual Restore" -ForegroundColor White
    Write-Host "5. Run Backup (Dry Run)" -ForegroundColor White
    Write-Host "6. Run Restore (Dry Run)" -ForegroundColor White
    Write-Host "7. View Help" -ForegroundColor White
    Write-Host "8. Exit" -ForegroundColor White
    Write-Host ""
}

function Test-Prerequisites {
    Write-Host "Checking prerequisites..." -ForegroundColor Yellow
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-Host "ERROR: PowerShell 5.1 or later is required" -ForegroundColor Red
        return $false
    }
    
    # Check AWS CLI
    try {
        $awsVersion = aws --version 2>&1
        Write-Host "AWS CLI found: $awsVersion" -ForegroundColor Green
    }
    catch {
        Write-Host "WARNING: AWS CLI not found. Please install AWS CLI for backup operations." -ForegroundColor Yellow
        Write-Host "Download from: https://aws.amazon.com/cli/" -ForegroundColor Cyan
    }
    
    # Check if scripts exist
    $requiredScripts = @("scripts\core\BackupManager.ps1", "scripts\gui\BackupManagerGUI.ps1", "scripts\core\BackupEngine.ps1", "scripts\core\BackupScheduler.ps1")
    $missingScripts = @()
    
    foreach ($script in $requiredScripts) {
        if (-not (Test-Path $script)) {
            $missingScripts += $script
        }
    }
    
    if ($missingScripts.Count -gt 0) {
        Write-Host "ERROR: Missing required scripts:" -ForegroundColor Red
        foreach ($script in $missingScripts) {
            Write-Host "  - $script" -ForegroundColor Red
        }
        return $false
    }
    
    Write-Host "Prerequisites check completed" -ForegroundColor Green
    return $true
}

# Main execution
if (-not (Test-Prerequisites)) {
    Write-Host ""
    Write-Host "Please resolve the issues above before continuing." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

do {
    Show-MainMenu
    $choice = Read-Host "Enter your choice (1-8)"
    
    switch ($choice) {
        "1" {
            Write-Host "Launching GUI Interface..." -ForegroundColor Green
            & ".\scripts\core\BackupManager.ps1" -GUI
        }
        "2" {
            Write-Host "Launching Scheduler Configuration..." -ForegroundColor Green
            & ".\scripts\core\BackupManager.ps1" -Schedule
        }
        "3" {
            Write-Host "Starting Manual Backup..." -ForegroundColor Green
            & ".\scripts\core\BackupManager.ps1" -Backup
        }
        "4" {
            Write-Host "Starting Manual Restore..." -ForegroundColor Green
            & ".\scripts\core\BackupManager.ps1" -Restore
        }
        "5" {
            Write-Host "Starting Backup Dry Run..." -ForegroundColor Green
            & ".\scripts\core\BackupEngine.ps1" -Operation Backup -DryRun
        }
        "6" {
            Write-Host "Starting Restore Dry Run..." -ForegroundColor Green
            & ".\scripts\core\BackupEngine.ps1" -Operation Restore -DryRun
        }
        "7" {
            & ".\scripts\core\BackupManager.ps1" -Help
        }
        "8" {
            Write-Host "Goodbye!" -ForegroundColor Green
            break
        }
        default {
            Write-Host "Invalid choice. Please select 1-8." -ForegroundColor Red
            Start-Sleep 2
        }
    }
    
    if ($choice -ne "8") {
        Write-Host ""
        Read-Host "Press Enter to return to main menu"
    }
    
} while ($choice -ne "8")