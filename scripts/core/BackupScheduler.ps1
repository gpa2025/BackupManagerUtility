#Requires -Version 5.1
<#
.SYNOPSIS
    Windows Task Scheduler Integration for Automated Backups
.DESCRIPTION
    Provides functionality to create, modify, and manage scheduled backup tasks
    using Windows Task Scheduler with comprehensive logging and error handling.
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
    [switch]$Configure,
    [switch]$Remove,
    [switch]$List,
    [switch]$GUI,
    [string]$TaskName = "EnhancedBackupManager"
)

# Import required assemblies for GUI
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Import shared functions
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptPath\BackupSharedFunctions.ps1"

class BackupScheduler {
    [string]$TaskName
    [hashtable]$Config
    [string]$LogPath

    BackupScheduler([string]$taskName) {
        $this.TaskName = $taskName
        $this.Config = Load-Config
        $this.LogPath = "$env:USERPROFILE\Desktop\BackupScheduler.log"
    }

    [void]WriteLog([string]$message, [string]$level = "INFO") {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "[$timestamp] [$level] $message"
        
        switch ($level) {
            "INFO"    { Write-Host $logEntry -ForegroundColor White }
            "WARNING" { Write-Host $logEntry -ForegroundColor Yellow }
            "ERROR"   { Write-Host $logEntry -ForegroundColor Red }
            "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
        }
        
        $logEntry | Out-File -FilePath $this.LogPath -Append -Encoding UTF8
    }

    [bool]IsTaskSchedulerAvailable() {
        try {
            Get-Command "schtasks.exe" -ErrorAction Stop | Out-Null
            $this.WriteLog("Task Scheduler is available", "SUCCESS")
            return $true
        }
        catch {
            $this.WriteLog("Task Scheduler is not available", "ERROR")
            return $false
        }
    }

    [bool]TaskExists() {
        try {
            $result = schtasks.exe /query /tn $this.TaskName 2>&1
            return $LASTEXITCODE -eq 0
        }
        catch {
            return $false
        }
    }

    [void]CreateScheduledTask([string]$frequency, [string]$time, [string]$description = "Enhanced Backup Manager Scheduled Task") {
        $this.WriteLog("Creating scheduled task: $($this.TaskName)", "INFO")
        
        if (-not $this.IsTaskSchedulerAvailable()) {
            return
        }

        # Remove existing task if it exists
        if ($this.TaskExists()) {
            $this.WriteLog("Removing existing task", "INFO")
            $this.RemoveScheduledTask()
        }

        try {
            # Get current script directory
            $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
            $backupScript = Join-Path $scriptDir "BackupEngine.ps1"
            
            # Create the action (what the task will do)
            $action = "powershell.exe"
            $arguments = "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$backupScript`" -Operation Backup"
            
            # Build schtasks command based on frequency
            switch ($frequency.ToLower()) {
                "daily" {
                    $scheduleArgs = "/sc daily /st $time"
                }
                "weekly" {
                    $scheduleArgs = "/sc weekly /d SUN /st $time"
                }
                "monthly" {
                    $scheduleArgs = "/sc monthly /d 1 /st $time"
                }
                default {
                    $scheduleArgs = "/sc daily /st $time"
                }
            }

            # Create the scheduled task
            $createCommand = "schtasks.exe /create /tn `"$($this.TaskName)`" /tr `"$action $arguments`" $scheduleArgs /f /rl HIGHEST"
            
            $this.WriteLog("Executing: $createCommand", "INFO")
            
            $result = Invoke-Expression $createCommand 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                $this.WriteLog("Scheduled task created successfully", "SUCCESS")
                $this.WriteLog("Task will run $frequency at $time", "INFO")
                
                # Update configuration
                $this.Config.ScheduleEnabled = $true
                $this.Config.ScheduleTime = $time
                $this.Config.ScheduleFrequency = $frequency
                Save-Config $this.Config
            }
            else {
                $this.WriteLog("Failed to create scheduled task: $result", "ERROR")
            }
        }
        catch {
            $this.WriteLog("Exception creating scheduled task: $_", "ERROR")
        }
    }

    [void]RemoveScheduledTask() {
        $this.WriteLog("Removing scheduled task: $($this.TaskName)", "INFO")
        
        if (-not $this.TaskExists()) {
            $this.WriteLog("Task does not exist", "WARNING")
            return
        }

        try {
            $result = schtasks.exe /delete /tn $this.TaskName /f 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                $this.WriteLog("Scheduled task removed successfully", "SUCCESS")
                
                # Update configuration
                $this.Config.ScheduleEnabled = $false
                Save-Config $this.Config
            }
            else {
                $this.WriteLog("Failed to remove scheduled task: $result", "ERROR")
            }
        }
        catch {
            $this.WriteLog("Exception removing scheduled task: $_", "ERROR")
        }
    }

    [void]ListScheduledTasks() {
        $this.WriteLog("Listing backup-related scheduled tasks", "INFO")
        
        try {
            $result = schtasks.exe /query /fo table /v | Where-Object { $_ -match "Backup|backup" }
            
            if ($result) {
                $this.WriteLog("Found backup-related tasks:", "INFO")
                foreach ($line in $result) {
                    $this.WriteLog($line, "INFO")
                }
            }
            else {
                $this.WriteLog("No backup-related scheduled tasks found", "INFO")
            }
        }
        catch {
            $this.WriteLog("Exception listing scheduled tasks: $_", "ERROR")
        }
    }

    [hashtable]GetTaskInfo() {
        if (-not $this.TaskExists()) {
            return @{ Exists = $false }
        }

        try {
            $result = schtasks.exe /query /tn $this.TaskName /fo list /v 2>&1
            
            $taskInfo = @{ Exists = $true }
            
            foreach ($line in $result) {
                if ($line -match "Next Run Time:\s*(.+)") {
                    $taskInfo.NextRun = $matches[1]
                }
                if ($line -match "Last Run Time:\s*(.+)") {
                    $taskInfo.LastRun = $matches[1]
                }
                if ($line -match "Status:\s*(.+)") {
                    $taskInfo.Status = $matches[1]
                }
                if ($line -match "Schedule:\s*(.+)") {
                    $taskInfo.Schedule = $matches[1]
                }
            }
            
            return $taskInfo
        }
        catch {
            $this.WriteLog("Exception getting task info: $_", "ERROR")
            return @{ Exists = $false }
        }
    }

    [void]ShowSchedulerGUI() {
        $form = New-Object System.Windows.Forms.Form
        $form.Text = "Backup Scheduler Configuration"
        $form.Size = New-Object System.Drawing.Size(500, 400)
        $form.StartPosition = "CenterScreen"
        $form.FormBorderStyle = "FixedSingle"
        $form.MaximizeBox = $false

        # Current Status Group
        $statusGroup = New-Object System.Windows.Forms.GroupBox
        $statusGroup.Text = "Current Schedule Status"
        $statusGroup.Location = New-Object System.Drawing.Point(20, 20)
        $statusGroup.Size = New-Object System.Drawing.Size(450, 120)

        $statusLabel = New-Object System.Windows.Forms.Label
        $statusLabel.Location = New-Object System.Drawing.Point(10, 25)
        $statusLabel.Size = New-Object System.Drawing.Size(430, 80)
        $statusLabel.Font = New-Object System.Drawing.Font("Consolas", 9)

        # Update status
        $taskInfo = $this.GetTaskInfo()
        if ($taskInfo.Exists) {
            $statusText = "Task Status: $($taskInfo.Status)`n"
            $statusText += "Schedule: $($taskInfo.Schedule)`n"
            $statusText += "Last Run: $($taskInfo.LastRun)`n"
            $statusText += "Next Run: $($taskInfo.NextRun)"
        }
        else {
            $statusText = "No scheduled backup task found"
        }
        $statusLabel.Text = $statusText

        $statusGroup.Controls.Add($statusLabel)

        # Configuration Group
        $configGroup = New-Object System.Windows.Forms.GroupBox
        $configGroup.Text = "Schedule Configuration"
        $configGroup.Location = New-Object System.Drawing.Point(20, 160)
        $configGroup.Size = New-Object System.Drawing.Size(450, 120)

        # Frequency
        $freqLabel = New-Object System.Windows.Forms.Label
        $freqLabel.Text = "Frequency:"
        $freqLabel.Location = New-Object System.Drawing.Point(20, 30)
        $freqLabel.Size = New-Object System.Drawing.Size(80, 20)

        $freqCombo = New-Object System.Windows.Forms.ComboBox
        $freqCombo.Location = New-Object System.Drawing.Point(110, 30)
        $freqCombo.Size = New-Object System.Drawing.Size(100, 20)
        $freqCombo.DropDownStyle = "DropDownList"
        $freqCombo.Items.AddRange(@("Daily", "Weekly", "Monthly"))
        $freqCombo.SelectedItem = $this.Config.ScheduleFrequency

        # Time
        $timeLabel = New-Object System.Windows.Forms.Label
        $timeLabel.Text = "Time:"
        $timeLabel.Location = New-Object System.Drawing.Point(230, 30)
        $timeLabel.Size = New-Object System.Drawing.Size(50, 20)

        $timeTextBox = New-Object System.Windows.Forms.TextBox
        $timeTextBox.Location = New-Object System.Drawing.Point(290, 30)
        $timeTextBox.Size = New-Object System.Drawing.Size(80, 20)
        $timeTextBox.Text = $this.Config.ScheduleTime

        $configGroup.Controls.AddRange(@($freqLabel, $freqCombo, $timeLabel, $timeTextBox))

        # Buttons
        $createButton = New-Object System.Windows.Forms.Button
        $createButton.Text = "Create/Update Schedule"
        $createButton.Location = New-Object System.Drawing.Point(20, 300)
        $createButton.Size = New-Object System.Drawing.Size(150, 30)
        $createButton.Add_Click({
            $this.CreateScheduledTask($freqCombo.SelectedItem, $timeTextBox.Text)
            $form.Close()
        })

        $removeButton = New-Object System.Windows.Forms.Button
        $removeButton.Text = "Remove Schedule"
        $removeButton.Location = New-Object System.Drawing.Point(190, 300)
        $removeButton.Size = New-Object System.Drawing.Size(120, 30)
        $removeButton.Add_Click({
            $this.RemoveScheduledTask()
            $form.Close()
        })

        $closeButton = New-Object System.Windows.Forms.Button
        $closeButton.Text = "Close"
        $closeButton.Location = New-Object System.Drawing.Point(330, 300)
        $closeButton.Size = New-Object System.Drawing.Size(80, 30)
        $closeButton.Add_Click({ $form.Close() })

        # Add controls to form
        $form.Controls.AddRange(@($statusGroup, $configGroup, $createButton, $removeButton, $closeButton))

        # Show form
        $form.ShowDialog()
    }

    [void]RunInteractiveConfiguration() {
        Write-Host ""
        Write-Host "=== Backup Scheduler Configuration ===" -ForegroundColor Green
        Write-Host ""

        # Show current status
        $taskInfo = $this.GetTaskInfo()
        if ($taskInfo.Exists) {
            Write-Host "Current scheduled task status:" -ForegroundColor Cyan
            Write-Host "  Status: $($taskInfo.Status)" -ForegroundColor White
            Write-Host "  Schedule: $($taskInfo.Schedule)" -ForegroundColor White
            Write-Host "  Last Run: $($taskInfo.LastRun)" -ForegroundColor White
            Write-Host "  Next Run: $($taskInfo.NextRun)" -ForegroundColor White
        }
        else {
            Write-Host "No scheduled backup task currently exists" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "Available options:" -ForegroundColor Cyan
        Write-Host "1. Create/Update scheduled backup" -ForegroundColor White
        Write-Host "2. Remove scheduled backup" -ForegroundColor White
        Write-Host "3. View all backup-related tasks" -ForegroundColor White
        Write-Host "4. Exit" -ForegroundColor White

        $choice = Read-Host "Enter your choice (1-4)"

        switch ($choice) {
            "1" {
                Write-Host ""
                Write-Host "Schedule Configuration:" -ForegroundColor Green
                
                $frequency = Read-Host "Enter frequency (Daily/Weekly/Monthly) [Daily]"
                if (-not $frequency) { $frequency = "Daily" }
                
                $time = Read-Host "Enter time (HH:MM format) [02:00]"
                if (-not $time) { $time = "02:00" }
                
                $this.CreateScheduledTask($frequency, $time)
            }
            "2" {
                $this.RemoveScheduledTask()
            }
            "3" {
                $this.ListScheduledTasks()
            }
            "4" {
                Write-Host "Exiting scheduler configuration" -ForegroundColor Green
            }
            default {
                Write-Host "Invalid choice" -ForegroundColor Red
            }
        }
    }
}

# Main execution
$scheduler = [BackupScheduler]::new($TaskName)

if ($GUI) {
    $scheduler.ShowSchedulerGUI()
}
elseif ($Configure) {
    $scheduler.RunInteractiveConfiguration()
}
elseif ($Remove) {
    $scheduler.RemoveScheduledTask()
}
elseif ($List) {
    $scheduler.ListScheduledTasks()
}
else {
    # Default to interactive configuration
    $scheduler.RunInteractiveConfiguration()
}