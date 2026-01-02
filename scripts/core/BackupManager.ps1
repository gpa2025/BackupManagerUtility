#Requires -Version 5.1
<#
.SYNOPSIS
    Enhanced Backup Manager with GUI, Scheduling, and Comprehensive Logging
.DESCRIPTION
    A comprehensive backup and restore solution that provides:
    - Interactive GUI for folder selection and configuration
    - Windows Task Scheduler integration for automated backups
    - Comprehensive logging with success/failure tracking
    - Flexible source and destination selection
    - Progress monitoring and statistics
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
    [switch]$GUI,
    [switch]$Schedule,
    [switch]$Backup,
    [switch]$Restore,
    [switch]$Help,
    [string]$ConfigFile = "BackupConfig.json"
)

# Import required assemblies for GUI
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Global configuration and logging
$script:LogPath = "$env:USERPROFILE\Desktop\BackupManager.log"
$script:ConfigPath = Join-Path $PSScriptRoot $ConfigFile

# Logging functions
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Write to console with colors
    switch ($Level) {
        "INFO"    { Write-Host $logEntry -ForegroundColor White }
        "WARNING" { Write-Host $logEntry -ForegroundColor Yellow }
        "ERROR"   { Write-Host $logEntry -ForegroundColor Red }
        "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
    }
    
    # Write to log file
    $logEntry | Out-File -FilePath $script:LogPath -Append -Encoding UTF8
}

function Show-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "==============================================================" -ForegroundColor Blue
    Write-Host "                 ENHANCED BACKUP MANAGER                    " -ForegroundColor Green
    Write-Host "==============================================================" -ForegroundColor Blue
    Write-Host ""
    Write-Host "  Features:    GUI Interface, Scheduling, Comprehensive Logging" -ForegroundColor White
    Write-Host "  Enhanced:    2025-12-22" -ForegroundColor Cyan
    Write-Host ""
}

if ($Help) {
    Write-Host "Enhanced Backup Manager" -ForegroundColor Green
    Write-Host "Usage: .\BackupManager.ps1 [switches]" -ForegroundColor White
    Write-Host ""
    Write-Host "Available switches:" -ForegroundColor Yellow
    Write-Host "  -GUI         Launch graphical user interface" -ForegroundColor White
    Write-Host "  -Schedule    Configure scheduled backups" -ForegroundColor White
    Write-Host "  -Backup      Run backup operation" -ForegroundColor White
    Write-Host "  -Restore     Run restore operation" -ForegroundColor White
    Write-Host "  -Help        Show this help message" -ForegroundColor White
    Write-Host "  -ConfigFile  Specify custom config file (default: BackupConfig.json)" -ForegroundColor White
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  .\BackupManager.ps1 -GUI                    # Launch GUI interface" -ForegroundColor White
    Write-Host "  .\BackupManager.ps1 -Schedule               # Configure scheduled backups" -ForegroundColor White
    Write-Host "  .\BackupManager.ps1 -Backup                 # Run backup with saved config" -ForegroundColor White
    exit 0
}

# Configuration management
function Get-DefaultConfig {
    return @{
        S3Bucket = "gpahpbackup"
        AWSProfile = "default"
        BackupFolders = @(
            @{ Source = "$env:USERPROFILE\Documents"; Destination = "Documents"; Enabled = $true },
            @{ Source = "$env:USERPROFILE\Desktop"; Destination = "Desktop"; Enabled = $true },
            @{ Source = "$env:USERPROFILE\Music"; Destination = "Music"; Enabled = $false },
            @{ Source = "$env:USERPROFILE\Pictures"; Destination = "Pictures"; Enabled = $true },
            @{ Source = "$env:USERPROFILE\Videos"; Destination = "Videos"; Enabled = $false }
        )
        RestoreDestination = "\\DXP4800-0E0F\personal_folder\WORK"
        ExcludePatterns = @("*.tmp", "*.log", "Thumbs.db", ".DS_Store", "desktop.ini", "My Music", "My Pictures", "My Videos")
        ScheduleEnabled = $false
        ScheduleTime = "02:00"
        ScheduleFrequency = "Daily"
        LogRetentionDays = 30
    }
}

function Save-Config {
    param($Config)
    try {
        $Config | ConvertTo-Json -Depth 10 | Out-File -FilePath $script:ConfigPath -Encoding UTF8
        Write-Log "Configuration saved to $script:ConfigPath" -Level "SUCCESS"
    }
    catch {
        Write-Log "Failed to save configuration: $_" -Level "ERROR"
    }
}

function Load-Config {
    if (Test-Path $script:ConfigPath) {
        try {
            $config = Get-Content $script:ConfigPath -Raw | ConvertFrom-Json
            Write-Log "Configuration loaded from $script:ConfigPath" -Level "INFO"
            return $config
        }
        catch {
            Write-Log "Failed to load configuration, using defaults: $_" -Level "WARNING"
            return Get-DefaultConfig
        }
    }
    else {
        Write-Log "No configuration file found, using defaults" -Level "INFO"
        return Get-DefaultConfig
    }
}

# Main execution logic
if (-not $GUI -and -not $Schedule -and -not $Backup -and -not $Restore) {
    Show-Banner
    Write-Host "No operation specified. Use -Help for usage information." -ForegroundColor Yellow
    Write-Host "Quick start: Use -GUI to launch the graphical interface." -ForegroundColor Cyan
    exit 0
}

# Initialize logging
Write-Log "BackupManager started with parameters: GUI=$GUI, Schedule=$Schedule, Backup=$Backup, Restore=$Restore" -Level "INFO"

# Route to appropriate function based on parameters
if ($GUI) {
    # GUI implementation will be in separate file
    Write-Log "Launching GUI interface..." -Level "INFO"
    & "$PSScriptRoot\..\gui\BackupManagerGUI.ps1"
}
elseif ($Schedule) {
    # Scheduling implementation will be in separate file
    Write-Log "Launching scheduler configuration..." -Level "INFO"
    & "$PSScriptRoot\BackupScheduler.ps1"
}
elseif ($Backup) {
    # Backup implementation will be in separate file
    Write-Log "Starting backup operation..." -Level "INFO"
    & "$PSScriptRoot\BackupEngine.ps1" -Operation "Backup"
}
elseif ($Restore) {
    # Restore implementation will be in separate file
    Write-Log "Starting restore operation..." -Level "INFO"
    & "$PSScriptRoot\BackupEngine.ps1" -Operation "Restore"
}

Write-Log "BackupManager session completed" -Level "INFO"