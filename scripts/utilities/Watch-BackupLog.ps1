#Requires -Version 5.1
<#
.SYNOPSIS
    Real-time backup log monitor
.DESCRIPTION
    Monitors the backup log file in real-time to show progress during backup operations
.AUTHOR
    Enhanced by AI Assistant (Kiro)
.VERSION
    1.0
.DATE
    2025-12-23
#>

param(
    [int]$RefreshSeconds = 2,
    [int]$TailLines = 20
)

$logPath = "$env:USERPROFILE\Desktop\BackupEngine.log"

Write-Host "=== BACKUP LOG MONITOR ===" -ForegroundColor Green
Write-Host "Monitoring: $logPath" -ForegroundColor Cyan
Write-Host "Refresh interval: $RefreshSeconds seconds" -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop monitoring" -ForegroundColor Yellow
Write-Host ""

if (-not (Test-Path $logPath)) {
    Write-Host "Log file not found. Starting backup to create log file..." -ForegroundColor Yellow
    Write-Host ""
}

$lastSize = 0
$lastLines = @()

while ($true) {
    try {
        if (Test-Path $logPath) {
            $currentSize = (Get-Item $logPath).Length
            
            if ($currentSize -gt $lastSize) {
                # File has grown, show new content
                $allLines = Get-Content $logPath -ErrorAction SilentlyContinue
                $newLines = $allLines | Select-Object -Skip $lastLines.Count
                
                foreach ($line in $newLines) {
                    # Color code the output based on log level
                    if ($line -match "\[ERROR\]") {
                        Write-Host $line -ForegroundColor Red
                    }
                    elseif ($line -match "\[WARNING\]") {
                        Write-Host $line -ForegroundColor Yellow
                    }
                    elseif ($line -match "\[SUCCESS\]") {
                        Write-Host $line -ForegroundColor Green
                    }
                    elseif ($line -match "\[PROGRESS\]|\[DETAILED\]") {
                        Write-Host $line -ForegroundColor Cyan
                    }
                    elseif ($line -match "\[FILE\]") {
                        Write-Host $line -ForegroundColor Gray
                    }
                    else {
                        Write-Host $line -ForegroundColor White
                    }
                }
                
                $lastSize = $currentSize
                $lastLines = $allLines
            }
        }
        else {
            Write-Host "Waiting for log file to be created..." -ForegroundColor Yellow
        }
        
        Start-Sleep -Seconds $RefreshSeconds
    }
    catch {
        Write-Host "Error reading log file: $_" -ForegroundColor Red
        Start-Sleep -Seconds $RefreshSeconds
    }
}