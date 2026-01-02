#Requires -Version 5.1
<#
.SYNOPSIS
    Clear Backup Manager Configuration
.DESCRIPTION
    Clears all configuration including credentials and sensitive information.
    Useful before sharing the project on GitHub or resetting to defaults.
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

param(
    [switch]$Force,
    [switch]$Help
)

# Import shared functions
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptPath\..\core\BackupSharedFunctions.ps1"

if ($Help) {
    Write-Host "Clear Backup Manager Configuration" -ForegroundColor Green
    Write-Host "Usage: .\Clear-BackupConfig.ps1 [-Force] [-Help]" -ForegroundColor White
    Write-Host ""
    Write-Host "This script clears all configuration including:" -ForegroundColor Yellow
    Write-Host "  - AWS credentials and S3 bucket names" -ForegroundColor White
    Write-Host "  - Backup and restore destination paths" -ForegroundColor White
    Write-Host "  - Custom folder selections" -ForegroundColor White
    Write-Host "  - All sensitive information" -ForegroundColor White
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Yellow
    Write-Host "  -Force    Clear without confirmation prompt" -ForegroundColor White
    Write-Host "  -Help     Show this help message" -ForegroundColor White
    Write-Host ""
    Write-Host "This is useful before:" -ForegroundColor Cyan
    Write-Host "  - Sharing the project on GitHub" -ForegroundColor White
    Write-Host "  - Distributing to other users" -ForegroundColor White
    Write-Host "  - Resetting to default configuration" -ForegroundColor White
    exit 0
}

function Show-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "==============================================================" -ForegroundColor Blue
    Write-Host "           CLEAR BACKUP MANAGER CONFIGURATION               " -ForegroundColor Red
    Write-Host "==============================================================" -ForegroundColor Blue
    Write-Host ""
    Write-Host "  This will clear ALL configuration including credentials!" -ForegroundColor Yellow
    Write-Host "  Use this before sharing the project or resetting." -ForegroundColor White
    Write-Host ""
}

function Clear-AllConfiguration {
    Write-Log "Starting configuration clearing process" -Level "INFO"
    
    # Clear main configuration file
    if (Clear-ConfigFile) {
        Write-Host "✓ Main configuration cleared" -ForegroundColor Green
    } else {
        Write-Host "✗ Failed to clear main configuration" -ForegroundColor Red
        return $false
    }
    
    # Clear any backup configuration files
    $backupConfigFiles = @(
        "BackupConfig.json.bak",
        "BackupConfig.backup",
        "*.config"
    )
    
    foreach ($pattern in $backupConfigFiles) {
        $files = Get-ChildItem -Path $PSScriptRoot -Filter $pattern -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            try {
                Remove-Item $file.FullName -Force
                Write-Host "✓ Removed backup config: $($file.Name)" -ForegroundColor Green
                Write-Log "Removed backup configuration file: $($file.FullName)" -Level "SUCCESS"
            }
            catch {
                Write-Host "✗ Failed to remove: $($file.Name)" -ForegroundColor Red
                Write-Log "Failed to remove backup configuration file: $($file.FullName) - $_" -Level "ERROR"
            }
        }
    }
    
    # Clear any log files that might contain sensitive information
    $logFiles = Get-ChildItem -Path "$env:USERPROFILE\Desktop" -Filter "*Backup*.log" -ErrorAction SilentlyContinue
    if ($logFiles) {
        Write-Host ""
        Write-Host "Found log files that may contain sensitive information:" -ForegroundColor Yellow
        foreach ($logFile in $logFiles) {
            Write-Host "  - $($logFile.Name)" -ForegroundColor White
        }
        
        if ($Force) {
            $clearLogs = "y"
        } else {
            $clearLogs = Read-Host "Clear these log files as well? (y/n) [n]"
        }
        
        if ($clearLogs -eq "y" -or $clearLogs -eq "Y") {
            foreach ($logFile in $logFiles) {
                try {
                    Remove-Item $logFile.FullName -Force
                    Write-Host "✓ Cleared log file: $($logFile.Name)" -ForegroundColor Green
                    Write-Log "Cleared log file: $($logFile.FullName)" -Level "SUCCESS"
                }
                catch {
                    Write-Host "✗ Failed to clear log: $($logFile.Name)" -ForegroundColor Red
                    Write-Log "Failed to clear log file: $($logFile.FullName) - $_" -Level "ERROR"
                }
            }
        }
    }
    
    return $true
}

function Show-Summary {
    Write-Host ""
    Write-Host "==============================================================" -ForegroundColor Blue
    Write-Host "                    CLEARING COMPLETE                       " -ForegroundColor Green
    Write-Host "==============================================================" -ForegroundColor Blue
    Write-Host ""
    Write-Host "Configuration has been cleared successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "What was cleared:" -ForegroundColor Cyan
    Write-Host "  ✓ AWS S3 bucket names and profiles" -ForegroundColor White
    Write-Host "  ✓ Backup and restore destination paths" -ForegroundColor White
    Write-Host "  ✓ Custom folder selections" -ForegroundColor White
    Write-Host "  ✓ All sensitive configuration data" -ForegroundColor White
    Write-Host ""
    Write-Host "The project is now safe to share on GitHub!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Note: Default configuration has been created." -ForegroundColor Yellow
    Write-Host "Users will need to configure their own settings." -ForegroundColor Yellow
    Write-Host ""
}

# Main execution
Show-Banner

if (-not $Force) {
    Write-Host "This will permanently clear all configuration including:" -ForegroundColor Yellow
    Write-Host "  - AWS credentials and S3 bucket information" -ForegroundColor White
    Write-Host "  - Backup and restore paths" -ForegroundColor White
    Write-Host "  - Custom folder selections" -ForegroundColor White
    Write-Host "  - All sensitive information" -ForegroundColor White
    Write-Host ""
    
    $confirm = Read-Host "Are you sure you want to continue? (yes/no)"
    if ($confirm -ne "yes") {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        exit 0
    }
}

Write-Host "Clearing configuration..." -ForegroundColor Yellow
Write-Host ""

if (Clear-AllConfiguration) {
    Show-Summary
} else {
    Write-Host ""
    Write-Host "Some errors occurred during clearing. Check the logs for details." -ForegroundColor Red
    Write-Host ""
}

Write-Host "Press any key to continue..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")