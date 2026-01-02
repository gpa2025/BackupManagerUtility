#Requires -Version 5.1
<#
.SYNOPSIS
    Shared Functions for Enhanced Backup Manager
.DESCRIPTION
    Contains shared functions and configuration management for the backup system
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

# Global configuration and logging
$script:LogPath = "$env:USERPROFILE\Desktop\BackupManager.log"
$script:ConfigPath = Join-Path $PSScriptRoot "BackupConfig.json"

# Logging functions
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS", "DETAILED", "FILE")]
        [string]$Level = "INFO",
        [hashtable]$Config = $null
    )
    
    # If no config provided, try to load it
    if (-not $Config) {
        $Config = @{ LogLevel = "INFO"; LogFileOperations = $true; LogFailuresOnly = $false }
    }
    
    # Determine if we should log this message based on log level
    $shouldLog = $false
    switch ($Config.LogLevel) {
        "MINIMAL" { 
            $shouldLog = $Level -in @("ERROR", "SUCCESS") 
        }
        "INFO" { 
            $shouldLog = $Level -in @("INFO", "WARNING", "ERROR", "SUCCESS") 
        }
        "DETAILED" { 
            $shouldLog = $Level -in @("INFO", "WARNING", "ERROR", "SUCCESS", "DETAILED") 
        }
        "ALL" { 
            $shouldLog = $true 
        }
        default { 
            $shouldLog = $Level -in @("INFO", "WARNING", "ERROR", "SUCCESS") 
        }
    }
    
    # Special handling for file operations
    if ($Level -eq "FILE") {
        $shouldLog = $Config.LogFileOperations -and ($Config.LogLevel -in @("DETAILED", "ALL"))
        if ($Config.LogFailuresOnly -and $Message -notmatch "ERROR|FAILED|Access denied") {
            $shouldLog = $false
        }
    }
    
    if (-not $shouldLog) { return }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Write to console with colors
    switch ($Level) {
        "INFO"     { Write-Host $logEntry -ForegroundColor White }
        "WARNING"  { Write-Host $logEntry -ForegroundColor Yellow }
        "ERROR"    { Write-Host $logEntry -ForegroundColor Red }
        "SUCCESS"  { Write-Host $logEntry -ForegroundColor Green }
        "DETAILED" { Write-Host $logEntry -ForegroundColor Cyan }
        "FILE"     { Write-Host $logEntry -ForegroundColor Gray }
    }
    
    # Write to log file
    $logEntry | Out-File -FilePath $script:LogPath -Append -Encoding UTF8
}

function Get-DefaultConfig {
    return @{
        BackupType = "Local"  # Local, AWS_S3, Network
        # AWS S3 Configuration (only used if BackupType = "AWS_S3")
        S3Bucket = "gpahpbackup"
        AWSProfile = "default"
        # Local/Network Configuration
        BackupDestination = "C:\Backups"
        BackupFolders = @(
            @{ Source = "C:\CloudRays"; Destination = "CloudRays"; Enabled = $true }
        )
        RestoreDestination = "$env:USERPROFILE\Restored"
        ExcludePatterns = @("*.tmp", "*.log", "Thumbs.db", ".DS_Store", "desktop.ini", "My Music", "My Pictures", "My Videos")
        ScheduleEnabled = $false
        ScheduleTime = "02:00"
        ScheduleFrequency = "Daily"
        LogRetentionDays = 30
        # Advanced Options
        UseCompression = $false
        VerifyBackups = $true
        MaxBackupVersions = 5
        # Logging Configuration
        LogLevel = "INFO"  # MINIMAL, INFO, DETAILED, ALL
        LogFileOperations = $true
        LogFailuresOnly = $false
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

function Clear-ConfigFile {
    try {
        if (Test-Path $script:ConfigPath) {
            Remove-Item $script:ConfigPath -Force
            Write-Log "Configuration file cleared: $script:ConfigPath" -Level "SUCCESS"
        }
        
        # Create a clean default configuration
        $defaultConfig = Get-DefaultConfig
        Save-Config $defaultConfig
        Write-Log "Default configuration created" -Level "SUCCESS"
        
        return $true
    }
    catch {
        Write-Log "Failed to clear configuration file: $_" -Level "ERROR"
        return $false
    }
}

function ConvertTo-Hashtable {
    param([Parameter(ValueFromPipeline)]$InputObject)
    
    if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
        $collection = @()
        foreach ($item in $InputObject) {
            $collection += ConvertTo-Hashtable $item
        }
        return $collection
    }
    elseif ($InputObject -is [PSCustomObject]) {
        $hash = @{}
        foreach ($property in $InputObject.PSObject.Properties) {
            $hash[$property.Name] = ConvertTo-Hashtable $property.Value
        }
        return $hash
    }
    else {
        return $InputObject
    }
}

function Load-Config {
    if (Test-Path $script:ConfigPath) {
        try {
            $jsonContent = Get-Content $script:ConfigPath -Raw | ConvertFrom-Json
            # Convert PSCustomObject to hashtable recursively
            $config = ConvertTo-Hashtable $jsonContent
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