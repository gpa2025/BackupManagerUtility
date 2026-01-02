#Requires -Version 5.1
<#
.SYNOPSIS
    Backup and Restore Engine with Enhanced Logging and Statistics
.DESCRIPTION
    Core engine for performing backup and restore operations with comprehensive
    logging, progress tracking, and error handling.
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
    [Parameter(Mandatory=$true)]
    [ValidateSet("Backup", "Restore")]
    [string]$Operation,
    
    [switch]$DryRun,
    [switch]$VerboseOutput,
    [string]$ConfigFile = "BackupConfig.json"
)

# Import shared functions
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptPath\BackupSharedFunctions.ps1"

class BackupEngine {
    [hashtable]$Config
    [string]$LogPath
    [int]$TotalFiles = 0
    [int64]$TotalBytes = 0
    [int]$SuccessfulOperations = 0
    [int]$FailedOperations = 0
    [datetime]$StartTime
    [datetime]$EndTime

    BackupEngine([hashtable]$config) {
        $this.Config = $config
        $this.LogPath = "$env:USERPROFILE\Desktop\BackupEngine.log"
        $this.StartTime = Get-Date
    }

    [void]WriteLog([string]$message, [string]$level = "INFO") {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "[$timestamp] [$level] $message"
        
        # Determine if we should log this message based on log level
        $shouldLog = $false
        switch ($this.Config.LogLevel) {
            "MINIMAL" { 
                $shouldLog = $level -in @("ERROR", "SUCCESS") 
            }
            "INFO" { 
                $shouldLog = $level -in @("INFO", "WARNING", "ERROR", "SUCCESS") 
            }
            "DETAILED" { 
                $shouldLog = $level -in @("INFO", "WARNING", "ERROR", "SUCCESS", "DETAILED") 
            }
            "ALL" { 
                $shouldLog = $true 
            }
            default { 
                $shouldLog = $level -in @("INFO", "WARNING", "ERROR", "SUCCESS") 
            }
        }
        
        # Special handling for file operations
        if ($level -eq "FILE") {
            $shouldLog = $this.Config.LogFileOperations -and ($this.Config.LogLevel -in @("DETAILED", "ALL"))
            if ($this.Config.LogFailuresOnly -and $message -notmatch "ERROR|FAILED|Access denied") {
                $shouldLog = $false
            }
        }
        
        if (-not $shouldLog) { return }
        
        # Console output with colors
        switch ($level) {
            "INFO"     { Write-Host $logEntry -ForegroundColor White }
            "WARNING"  { Write-Host $logEntry -ForegroundColor Yellow }
            "ERROR"    { Write-Host $logEntry -ForegroundColor Red }
            "SUCCESS"  { Write-Host $logEntry -ForegroundColor Green }
            "PROGRESS" { Write-Host $logEntry -ForegroundColor Cyan }
            "DETAILED" { Write-Host $logEntry -ForegroundColor Cyan }
            "FILE"     { Write-Host $logEntry -ForegroundColor Gray }
        }
        
        # File output
        $logEntry | Out-File -FilePath $this.LogPath -Append -Encoding UTF8
    }

    [bool]ValidateAWSCLI() {
        $this.WriteLog("Validating AWS CLI installation...", "INFO")
        
        try {
            $awsVersion = aws --version 2>&1
            $this.WriteLog("AWS CLI found: $awsVersion", "SUCCESS")
            return $true
        }
        catch {
            $this.WriteLog("AWS CLI not found. Please install AWS CLI first.", "ERROR")
            return $false
        }
    }

    [bool]ValidateAWSCredentials() {
        $this.WriteLog("Validating AWS credentials for profile '$($this.Config.AWSProfile)'...", "INFO")
        
        try {
            aws sts get-caller-identity --profile $this.Config.AWSProfile | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $this.WriteLog("AWS credentials validated successfully", "SUCCESS")
                return $true
            }
            else {
                $this.WriteLog("AWS credentials validation failed", "ERROR")
                return $false
            }
        }
        catch {
            $this.WriteLog("Error validating AWS credentials: $_", "ERROR")
            return $false
        }
    }

    [bool]ValidateS3Bucket() {
        $this.WriteLog("Validating S3 bucket '$($this.Config.S3Bucket)'...", "INFO")
        
        try {
            aws s3api head-bucket --bucket $this.Config.S3Bucket --profile $this.Config.AWSProfile 2>&1 | Out-Null
            
            if ($LASTEXITCODE -eq 0) {
                $this.WriteLog("S3 bucket '$($this.Config.S3Bucket)' is accessible", "SUCCESS")
                return $true
            }
            else {
                $this.WriteLog("S3 bucket '$($this.Config.S3Bucket)' is not accessible", "ERROR")
                return $false
            }
        }
        catch {
            $this.WriteLog("Error validating S3 bucket: $_", "ERROR")
            return $false
        }
    }

    [bool]ValidateRestoreDestination([string]$destination) {
        $this.WriteLog("Validating restore destination '$destination'...", "INFO")
        
        try {
            if ($destination.StartsWith("\\")) {
                # Network path
                $this.WriteLog("Network path detected, testing accessibility...", "INFO")
                
                if (-not (Test-Path $destination)) {
                    $this.WriteLog("Network path is not accessible, attempting to create...", "WARNING")
                    try {
                        New-Item -ItemType Directory -Path $destination -Force | Out-Null
                        if (Test-Path $destination) {
                            $this.WriteLog("Network path created successfully", "SUCCESS")
                            return $true
                        }
                        else {
                            $this.WriteLog("Failed to create network path", "ERROR")
                            return $false
                        }
                    }
                    catch {
                        $this.WriteLog("Cannot create network path: $_", "ERROR")
                        return $false
                    }
                }
                else {
                    # Test write access
                    $testFile = Join-Path $destination "restore_test_$(Get-Date -Format 'yyyyMMddHHmmss').tmp"
                    try {
                        "test" | Out-File -FilePath $testFile -ErrorAction Stop
                        Remove-Item $testFile -ErrorAction SilentlyContinue
                        $this.WriteLog("Network path is accessible and writable", "SUCCESS")
                        return $true
                    }
                    catch {
                        $this.WriteLog("Network path exists but is not writable: $_", "ERROR")
                        return $false
                    }
                }
            }
            else {
                # Local path
                if (-not (Test-Path $destination)) {
                    $this.WriteLog("Creating local restore destination...", "INFO")
                    New-Item -ItemType Directory -Path $destination -Force | Out-Null
                }
                
                # Test write access
                $testFile = Join-Path $destination "restore_test_$(Get-Date -Format 'yyyyMMddHHmmss').tmp"
                "test" | Out-File -FilePath $testFile -ErrorAction Stop
                Remove-Item $testFile -ErrorAction SilentlyContinue
                
                $this.WriteLog("Local restore destination is ready", "SUCCESS")
                return $true
            }
        }
        catch {
            $this.WriteLog("Error validating restore destination: $_", "ERROR")
            return $false
        }
    }

    [bool]ValidateLocalBackupDestination() {
        $destination = $this.Config.BackupDestination
        $this.WriteLog("Validating local backup destination '$destination'...", "INFO")
        
        try {
            if (-not (Test-Path $destination)) {
                $this.WriteLog("Creating local backup destination...", "INFO")
                New-Item -ItemType Directory -Path $destination -Force | Out-Null
            }
            
            # Test write access
            $testFile = Join-Path $destination "backup_test_$(Get-Date -Format 'yyyyMMddHHmmss').tmp"
            "test" | Out-File -FilePath $testFile -Force
            Remove-Item $testFile -Force
            
            $this.WriteLog("Local backup destination is ready", "SUCCESS")
            return $true
        }
        catch {
            $this.WriteLog("Error validating local backup destination: $_", "ERROR")
            return $false
        }
    }

    [void]RunBackup([bool]$dryRun = $false) {
        $this.WriteLog("Starting backup operation (DryRun: $dryRun)", "INFO")
        
        # Check backup type and validate accordingly
        if ($this.Config.BackupType -eq "AWS_S3") {
            # Validate AWS prerequisites
            if (-not $this.ValidateAWSCLI()) { return }
            if (-not $this.ValidateAWSCredentials()) { return }
            if (-not $this.ValidateS3Bucket()) { return }
        }
        else {
            # Validate local/network backup destination
            if (-not $this.ValidateLocalBackupDestination()) { return }
        }

        $enabledFolders = $this.Config.BackupFolders | Where-Object { $_.Enabled -eq $true }
        $totalFolders = $enabledFolders.Count
        $currentFolder = 0

        $this.WriteLog("Found $totalFolders enabled folders for backup", "INFO")
        $this.WriteLog("Backup type: $($this.Config.BackupType)", "INFO")

        foreach ($folder in $enabledFolders) {
            $currentFolder++
            if ($this.Config.BackupType -eq "AWS_S3") {
                $this.ProcessS3BackupFolder($folder, $currentFolder, $totalFolders, $dryRun)
            }
            else {
                $this.ProcessLocalBackupFolder($folder, $currentFolder, $totalFolders, $dryRun)
            }
        }

        $this.EndTime = Get-Date
        $this.GenerateBackupSummary($dryRun)
    }

    [void]ProcessS3BackupFolder([hashtable]$folder, [int]$current, [int]$total, [bool]$dryRun) {
        $this.WriteLog("[$current/$total] Processing: '$($folder.Source)' -> 's3://$($this.Config.S3Bucket)/$($folder.Destination)'", "PROGRESS")
        
        if (-not (Test-Path $folder.Source)) {
            $this.WriteLog("Source folder does not exist: $($folder.Source)", "WARNING")
            $this.FailedOperations = $this.FailedOperations + 1
            return
        }

        # Quick file count estimation
        try {
            $this.WriteLog("Analyzing folder contents...", "INFO")
            $fileCount = (Get-ChildItem -Path $folder.Source -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count
            $this.WriteLog("Found approximately $fileCount files in source folder", "INFO")
        }
        catch {
            $this.WriteLog("Could not estimate file count: $_", "WARNING")
        }

        try {
            # Build AWS CLI arguments first
            $awsArgs = @(
                "s3", "sync", 
                $folder.Source, 
                "s3://$($this.Config.S3Bucket)/$($folder.Destination)",
                "--profile", $this.Config.AWSProfile
            )

            # Add exclude patterns
            foreach ($pattern in $this.Config.ExcludePatterns) {
                $awsArgs += "--exclude", $pattern
            }

            if ($dryRun) {
                $awsArgs += "--dryrun"
                $this.WriteLog("DRY RUN: Scanning files for $($folder.Source)", "INFO")
            }

            # Execute AWS CLI command
            $this.WriteLog("Executing: aws $($awsArgs -join ' ')", "DETAILED")
            $this.WriteLog("Starting AWS S3 sync operation...", "INFO")
            
            try {
                # Execute AWS CLI using the call operator
                $this.WriteLog("Running AWS CLI sync command...", "INFO")
                
                # Execute the command and capture all output
                $output = & aws @awsArgs 2>&1
                $exitCode = $LASTEXITCODE
                
                $this.WriteLog("AWS CLI completed with exit code: $exitCode", "INFO")
                
                # Log some sample output for debugging
                if ($output -and $output.Count -gt 0) {
                    $this.WriteLog("AWS CLI output sample (first 5 lines):", "DETAILED")
                    $sampleOutput = $output | Select-Object -First 5
                    foreach ($line in $sampleOutput) {
                        $this.WriteLog("  $line", "DETAILED")
                    }
                }
                else {
                    $this.WriteLog("AWS CLI produced no output", "INFO")
                }
            }
            catch {
                $this.WriteLog("Exception executing AWS CLI: $_", "ERROR")
                $exitCode = 1
                $output = @("Exception: $_")
            }

            if ($exitCode -eq 0) {
                $this.ProcessAWSOutput($output, $folder.Source, $dryRun)
                $this.SuccessfulOperations = $this.SuccessfulOperations + 1
                $this.WriteLog("Successfully processed: $($folder.Source)", "SUCCESS")
            }
            else {
                $this.WriteLog("Failed to process $($folder.Source) - Exit code: $exitCode", "ERROR")
                $this.FailedOperations = $this.FailedOperations + 1
                $this.LogAWSError($exitCode, $output)
            }
        }
        catch {
            $this.WriteLog("Exception processing $($folder.Source): $_", "ERROR")
            $this.FailedOperations = $this.FailedOperations + 1
        }
    }

    [void]ProcessLocalBackupFolder([hashtable]$folder, [int]$current, [int]$total, [bool]$dryRun) {
        $destination = Join-Path $this.Config.BackupDestination $folder.Destination
        $this.WriteLog("[$current/$total] Processing: '$($folder.Source)' -> '$destination'", "PROGRESS")
        
        if (-not (Test-Path $folder.Source)) {
            $this.WriteLog("Source folder does not exist: $($folder.Source)", "WARNING")
            $this.FailedOperations = $this.FailedOperations + 1
            return
        }

        try {
            if ($dryRun) {
                $this.WriteLog("DRY RUN: Scanning files for $($folder.Source)", "INFO")
                $files = Get-ChildItem -Path $folder.Source -Recurse -File | Where-Object { -not $this.IsExcluded($_.FullName) }
                $fileCount = $files.Count
                $totalSize = ($files | Measure-Object -Property Length -Sum).Sum
                
                $this.WriteLog("Would copy $fileCount files ($([math]::Round($totalSize/1MB, 2)) MB)", "INFO")
                $newTotalFiles = $this.TotalFiles + $fileCount
                $newTotalBytes = $this.TotalBytes + $totalSize
                $this.TotalFiles = $newTotalFiles
                $this.TotalBytes = $newTotalBytes
            }
            else {
                # Create destination directory if it doesn't exist
                if (-not (Test-Path $destination)) {
                    New-Item -ItemType Directory -Path $destination -Force | Out-Null
                }
                
                # Use robocopy for efficient copying with progress
                $this.WriteLog("Starting file copy operation...", "INFO")
                $robocopyArgs = @(
                    "`"$($folder.Source)`"",
                    "`"$destination`"",
                    "/E",  # Copy subdirectories including empty ones
                    "/R:3", # Retry 3 times on failed copies
                    "/W:1", # Wait 1 second between retries
                    "/MT:4", # Multi-threaded copy (4 threads)
                    "/V",   # Verbose output showing skipped files
                    "/TS",  # Include source file timestamps
                    "/FP"   # Include full pathname of files
                )
                
                # Add more verbose logging if detailed logging is enabled
                if ($this.Config.LogLevel -in @("DETAILED", "ALL")) {
                    $robocopyArgs += "/L"  # List only mode for detailed analysis
                    $this.WriteLog("Running in list-only mode first for detailed file analysis...", "DETAILED")
                    
                    # First pass: list only to get detailed file information
                    $listOutput = & robocopy @robocopyArgs 2>&1
                    $this.ProcessRobocopyListOutput($listOutput, $folder.Source)
                    
                    # Remove /L flag for actual copy
                    $robocopyArgs = $robocopyArgs | Where-Object { $_ -ne "/L" }
                }
                
                # Add exclude patterns for robocopy
                foreach ($pattern in $this.Config.ExcludePatterns) {
                    $robocopyPattern = $pattern.Replace("*.", "*.").Replace("*", "*.*")
                    $robocopyArgs += "/XF"
                    $robocopyArgs += $robocopyPattern
                }
                
                $this.WriteLog("Executing: robocopy $($robocopyArgs -join ' ')", "INFO")
                
                # Execute robocopy and capture output
                $output = & robocopy @robocopyArgs 2>&1
                $exitCode = $LASTEXITCODE
                
                # Robocopy exit codes: 0-7 are success, 8+ are errors
                if ($exitCode -le 7) {
                    $this.ProcessRobocopyOutput($output, $folder.Source)
                    $this.SuccessfulOperations = $this.SuccessfulOperations + 1
                    $this.WriteLog("Successfully processed: $($folder.Source)", "SUCCESS")
                }
                else {
                    $this.WriteLog("Failed to process $($folder.Source) - Robocopy exit code: $exitCode", "ERROR")
                    $this.FailedOperations = $this.FailedOperations + 1
                    $this.LogRobocopyError($exitCode, $output)
                }
            }
        }
        catch {
            $this.WriteLog("Exception processing $($folder.Source): $_", "ERROR")
            $this.FailedOperations = $this.FailedOperations + 1
        }
    }

    [bool]IsExcluded([string]$filePath) {
        $fileName = [System.IO.Path]::GetFileName($filePath)
        foreach ($pattern in $this.Config.ExcludePatterns) {
            if ($fileName -like $pattern) {
                return $true
            }
        }
        return $false
    }

    [void]ProcessRobocopyListOutput([string[]]$output, [string]$source) {
        $this.WriteLog("=== DETAILED FILE ANALYSIS FOR $source ===", "DETAILED")
        
        $newFiles = @()
        $newerFiles = @()
        $olderFiles = @()
        $sameFiles = @()
        
        foreach ($line in $output) {
            if ($line -match "^\s*New File\s+\d+\s+(.+)$") {
                $newFiles += $matches[1].Trim()
            }
            elseif ($line -match "^\s*Newer\s+\d+\s+(.+)$") {
                $newerFiles += $matches[1].Trim()
            }
            elseif ($line -match "^\s*Older\s+\d+\s+(.+)$") {
                $olderFiles += $matches[1].Trim()
            }
            elseif ($line -match "^\s*Same\s+\d+\s+(.+)$") {
                $sameFiles += $matches[1].Trim()
            }
        }
        
        if ($newFiles.Count -gt 0) {
            $this.WriteLog("Files to be copied (NEW): $($newFiles.Count)", "DETAILED")
            foreach ($file in $newFiles) {
                $this.WriteLog("  NEW: $file", "FILE")
            }
        }
        
        if ($newerFiles.Count -gt 0) {
            $this.WriteLog("Files to be updated (NEWER): $($newerFiles.Count)", "DETAILED")
            foreach ($file in $newerFiles) {
                $this.WriteLog("  NEWER: $file", "FILE")
            }
        }
        
        if ($olderFiles.Count -gt 0) {
            $this.WriteLog("Files that would be overwritten (OLDER): $($olderFiles.Count)", "DETAILED")
            foreach ($file in $olderFiles) {
                $this.WriteLog("  OLDER: $file", "FILE")
            }
        }
        
        if ($sameFiles.Count -gt 0) {
            $this.WriteLog("Files that are up-to-date (SAME): $($sameFiles.Count)", "DETAILED")
            if ($this.Config.LogLevel -eq "ALL") {
                foreach ($file in $sameFiles) {
                    $this.WriteLog("  SAME: $file", "FILE")
                }
            }
        }
        
        $this.WriteLog("=== END DETAILED FILE ANALYSIS ===", "DETAILED")
    }

    [void]ProcessRobocopyOutput([string[]]$output, [string]$source) {
        $fileCount = 0
        $localTotalBytes = 0
        $copiedFiles = @()
        $skippedFiles = @()
        $errorFiles = @()
        
        # Parse robocopy output for detailed file information
        $inFileSection = $false
        foreach ($line in $output) {
            # Detect file operation lines
            if ($line -match "^\s*(New File|Newer|Older|\*EXTRA File)\s+\d+\s+(.+)$") {
                $operation = $matches[1].Trim()
                $filePath = $matches[2].Trim()
                $copiedFiles += "$operation`: $filePath"
                $fileCount++
            }
            elseif ($line -match "^\s*Same\s+\d+\s+(.+)$") {
                $filePath = $matches[1].Trim()
                $skippedFiles += "Same: $filePath"
            }
            elseif ($line -match "ERROR|FAILED|Access denied") {
                $errorFiles += $line.Trim()
            }
            # Look for summary lines in robocopy output
            elseif ($line -match "Files\s*:\s*(\d+)") {
                $summaryFileCount = [int]$matches[1]
                if ($summaryFileCount -gt $fileCount) {
                    $fileCount = $summaryFileCount
                }
            }
            elseif ($line -match "Bytes\s*:\s*([\d,]+)") {
                $bytesStr = $matches[1] -replace ",", ""
                $localTotalBytes = [int64]$bytesStr
            }
        }
        
        if ($fileCount -gt 0) {
            $newTotalFiles = $this.TotalFiles + $fileCount
            $newTotalBytes = $this.TotalBytes + $localTotalBytes
            $this.TotalFiles = $newTotalFiles
            $this.TotalBytes = $newTotalBytes
            $sizeMB = [math]::Round($localTotalBytes / 1MB, 2)
            $this.WriteLog("Copied $fileCount files ($sizeMB MB) from $source", "INFO")
            
            # Log detailed file operations if enabled
            if ($this.Config.LogLevel -in @("DETAILED", "ALL") -and $copiedFiles.Count -gt 0) {
                $this.WriteLog("=== COPIED FILES FROM $source ===", "DETAILED")
                foreach ($file in $copiedFiles) {
                    $this.WriteLog("  $file", "FILE")
                }
                $this.WriteLog("=== END COPIED FILES ===", "DETAILED")
            }
            
            # Log skipped files if detailed logging is enabled
            if ($this.Config.LogLevel -eq "ALL" -and $skippedFiles.Count -gt 0) {
                $this.WriteLog("=== SKIPPED FILES FROM $source ===", "DETAILED")
                foreach ($file in $skippedFiles) {
                    $this.WriteLog("  $file", "FILE")
                }
                $this.WriteLog("=== END SKIPPED FILES ===", "DETAILED")
            }
        }
        else {
            $this.WriteLog("No new files to copy from $source", "INFO")
        }
        
        # Always log errors regardless of log level
        if ($errorFiles.Count -gt 0) {
            $this.WriteLog("=== ROBOCOPY ERRORS FROM $source ===", "ERROR")
            foreach ($errorLine in $errorFiles) {
                $this.WriteLog("  $errorLine", "ERROR")
            }
            $this.WriteLog("=== END ERRORS ===", "ERROR")
        }
        
        # Log summary for skipped files
        if ($skippedFiles.Count -gt 0) {
            $this.WriteLog("Files skipped (already up to date): $($skippedFiles.Count)", "INFO")
        }
    }

    [void]LogRobocopyError([int]$exitCode, [string[]]$output) {
        $errorMessage = switch ($exitCode) {
            8 { "Some files or directories could not be copied" }
            16 { "Serious error. Robocopy did not copy any files" }
            default { "Unknown robocopy error code: $exitCode" }
        }
        
        $this.WriteLog("Robocopy Error: $errorMessage", "ERROR")
        
        # Log error lines from output
        $errorLines = $output | Where-Object { $_ -match "ERROR|FAILED|Access denied" }
        foreach ($errorLine in $errorLines) {
            $this.WriteLog("Robocopy: $errorLine", "ERROR")
        }
    }

    [void]RunRestore([bool]$dryRun = $false) {
        $this.WriteLog("Starting restore operation (DryRun: $dryRun)", "INFO")
        
        # Check backup type - restore only works with AWS S3
        if ($this.Config.BackupType -ne "AWS_S3") {
            $this.WriteLog("Restore operation only supports AWS S3 backup type", "ERROR")
            return
        }
        
        # Validate prerequisites
        if (-not $this.ValidateAWSCLI()) { return }
        if (-not $this.ValidateAWSCredentials()) { return }
        if (-not $this.ValidateS3Bucket()) { return }

        # Validate and prepare destination path
        $restoreDestination = $this.Config.RestoreDestination
        $tempDrive = $null
        $actualDestination = $restoreDestination
        
        if (-not $this.ValidateRestoreDestination($restoreDestination)) {
            $this.WriteLog("Restore destination validation failed", "ERROR")
            return
        }
        
        # Handle UNC paths by mapping to a temporary drive letter for AWS CLI compatibility
        if ($restoreDestination.StartsWith("\\")) {
            $this.WriteLog("Network path detected - mapping to temporary drive for AWS CLI compatibility", "INFO")
            
            # Find an available drive letter
            $availableDrives = 90..65 | ForEach-Object { [char]$_ } | Where-Object { -not (Test-Path "$_`:") }
            if ($availableDrives.Count -eq 0) {
                $this.WriteLog("No available drive letters for temporary mapping", "ERROR")
                return
            }
            
            $tempDrive = $availableDrives[0]
            $tempDrivePath = "$tempDrive`:"
            
            try {
                $this.WriteLog("Mapping network path to drive $tempDrivePath", "INFO")
                
                # Use net use command for mapping
                $netUseOutput = & net use $tempDrivePath $restoreDestination 2>&1
                if ($LASTEXITCODE -eq 0) {
                    $actualDestination = $tempDrivePath
                    $this.WriteLog("Successfully mapped to drive $tempDrivePath", "SUCCESS")
                }
                else {
                    $this.WriteLog("Failed to map network drive: $netUseOutput", "ERROR")
                    return
                }
            }
            catch {
                $this.WriteLog("Exception mapping network drive: $_", "ERROR")
                return
            }
        }

        try {
            # Try alternative restore approach due to AWS CLI sync timeout issues
            $this.WriteLog("Using alternative restore approach due to AWS CLI sync timeout issues", "INFO")
            
            if ($dryRun) {
                $this.WriteLog("DRY RUN: Would restore from S3 bucket to $actualDestination", "INFO")
                $this.SuccessfulOperations = 1
            }
            else {
                # Use AWS CLI with timeout and chunked approach
                $success = $this.RestoreWithTimeout($actualDestination)
                
                if ($success) {
                    $this.SuccessfulOperations = 1
                    $this.WriteLog("Restore operation completed successfully", "SUCCESS")
                }
                else {
                    $this.FailedOperations = 1
                    $this.WriteLog("Restore operation failed", "ERROR")
                }
            }
        }
        catch {
            $this.WriteLog("Exception during restore operation: $_", "ERROR")
            $this.FailedOperations = $this.FailedOperations + 1
        }
        finally {
            # Clean up temporary drive mapping if used
            if ($tempDrive) {
                try {
                    $this.WriteLog("Cleaning up temporary drive mapping: $tempDrive`:", "INFO")
                    & net use "$tempDrive`:" /delete /y 2>&1 | Out-Null
                    $this.WriteLog("Temporary drive mapping cleaned up", "SUCCESS")
                }
                catch {
                    $this.WriteLog("Warning: Could not clean up temporary drive mapping: $_", "WARNING")
                }
            }
        }

        $this.EndTime = Get-Date
        $this.GenerateRestoreSummary($dryRun)
    }

    [bool]RestoreWithTimeout([string]$destination) {
        $this.WriteLog("Starting restore with timeout handling", "INFO")
        
        try {
            # First, get a list of objects to restore
            $this.WriteLog("Getting list of objects from S3 bucket...", "INFO")
            
            $listArgs = @(
                "s3api", "list-objects-v2",
                "--bucket", $this.Config.S3Bucket,
                "--profile", $this.Config.AWSProfile,
                "--output", "json"
            )
            
            $listOutput = & aws @listArgs 2>&1
            if ($LASTEXITCODE -ne 0) {
                $this.WriteLog("Failed to list S3 objects: $listOutput", "ERROR")
                return $false
            }
            
            # Parse JSON output
            try {
                $s3Objects = $listOutput | ConvertFrom-Json
                $objectCount = 0
                if ($s3Objects.Contents) {
                    $objectCount = $s3Objects.Contents.Count
                }
                
                $this.WriteLog("Found $objectCount objects in S3 bucket", "INFO")
                
                if ($objectCount -eq 0) {
                    $this.WriteLog("No objects to restore", "WARNING")
                    return $true
                }
                
                # Restore objects in batches to avoid timeout
                $batchSize = 50
                $batches = [math]::Ceiling($objectCount / $batchSize)
                $this.WriteLog("Restoring in $batches batches of $batchSize objects each", "INFO")
                
                $restoredCount = 0
                for ($batch = 0; $batch -lt $batches; $batch++) {
                    $startIndex = $batch * $batchSize
                    $endIndex = [math]::Min(($batch + 1) * $batchSize - 1, $objectCount - 1)
                    
                    $this.WriteLog("Processing batch $($batch + 1)/$batches (objects $($startIndex + 1)-$($endIndex + 1))", "PROGRESS")
                    
                    # Process batch of objects
                    for ($i = $startIndex; $i -le $endIndex; $i++) {
                        $obj = $s3Objects.Contents[$i]
                        $key = $obj.Key
                        $localPath = Join-Path $destination $key
                        
                        # Create directory if needed
                        $localDir = Split-Path $localPath -Parent
                        if ($localDir -and -not (Test-Path $localDir)) {
                            try {
                                New-Item -ItemType Directory -Path $localDir -Force | Out-Null
                                $this.WriteLog("Created directory: $localDir", "DETAILED")
                            }
                            catch {
                                $this.WriteLog("Failed to create directory $localDir`: $_", "ERROR")
                                continue
                            }
                        }
                        
                        # Download individual file with timeout
                        $success = $this.DownloadFileWithTimeout($key, $localPath)
                        if ($success) {
                            $restoredCount++
                            $this.WriteLog("Restored: $key", "FILE")
                        }
                        else {
                            $this.WriteLog("Failed to restore: $key", "ERROR")
                        }
                    }
                    
                    # Brief pause between batches
                    Start-Sleep -Milliseconds 100
                }
                
                $this.TotalFiles = $restoredCount
                $this.WriteLog("Successfully restored $restoredCount out of $objectCount files", "SUCCESS")
                return $true
            }
            catch {
                $this.WriteLog("Error parsing S3 object list: $_", "ERROR")
                return $false
            }
        }
        catch {
            $this.WriteLog("Exception in RestoreWithTimeout: $_", "ERROR")
            return $false
        }
    }

    [bool]DownloadFileWithTimeout([string]$s3Key, [string]$localPath) {
        try {
            # Use aws s3 cp for individual file download with timeout
            $s3Uri = "s3://$($this.Config.S3Bucket)/$s3Key"
            
            # Use Start-Process for timeout control
            $processInfo = New-Object System.Diagnostics.ProcessStartInfo
            $processInfo.FileName = "aws"
            $processInfo.RedirectStandardOutput = $true
            $processInfo.RedirectStandardError = $true
            $processInfo.UseShellExecute = $false
            $processInfo.CreateNoWindow = $true
            
            # Build arguments string with proper quoting
            $argString = "s3 cp `"$s3Uri`" `"$localPath`" --profile `"$($this.Config.AWSProfile)`""
            $processInfo.Arguments = $argString
            
            # Log the command being executed for debugging
            $this.WriteLog("Executing: aws $argString", "DETAILED")
            
            $process = New-Object System.Diagnostics.Process
            $process.StartInfo = $processInfo
            $process.Start() | Out-Null
            
            # 30 second timeout per file
            $completed = $process.WaitForExit(30000)
            
            if ($completed) {
                $exitCode = $process.ExitCode
                if ($exitCode -eq 0) {
                    $process.Dispose()
                    return $true
                }
                else {
                    $errorOutput = $process.StandardError.ReadToEnd()
                    $this.WriteLog("Download failed for $s3Key`: $errorOutput", "ERROR")
                    $process.Dispose()
                    return $false
                }
            }
            else {
                $this.WriteLog("Download timeout for $s3Key", "WARNING")
                $process.Kill()
                $process.Dispose()
                return $false
            }
        }
        catch {
            $this.WriteLog("Exception downloading $s3Key`: $_", "ERROR")
            return $false
        }
    }

    [void]ProcessAWSOutput([string[]]$output, [string]$operation, [bool]$dryRun) {
        $uploadLines = $output | Where-Object { $_ -match "upload:|download:|copy:" }
        $skipLines = $output | Where-Object { $_ -match "skip:" }
        $errorLines = $output | Where-Object { $_ -match "failed|error" -and $_ -notmatch "upload:|download:|copy:" }
        
        $fileCount = $uploadLines.Count
        $skippedCount = $skipLines.Count
        
        if ($fileCount -gt 0) {
            $newTotalFiles = $this.TotalFiles + $fileCount
            $this.TotalFiles = $newTotalFiles
            $this.WriteLog("Processed $fileCount files for $operation", "INFO")
            
            # Log all files if detailed logging is enabled
            if ($this.Config.LogLevel -in @("DETAILED", "ALL")) {
                $this.WriteLog("=== FILE OPERATIONS FOR $operation ===", "DETAILED")
                foreach ($file in $uploadLines) {
                    $this.WriteLog("  $file", "FILE")
                }
                if ($skippedCount -gt 0) {
                    $this.WriteLog("=== SKIPPED FILES ===", "DETAILED")
                    foreach ($file in $skipLines) {
                        $this.WriteLog("  $file", "FILE")
                    }
                }
                $this.WriteLog("=== END FILE OPERATIONS ===", "DETAILED")
            }
            else {
                # Log sample of files processed (first 5) for INFO level
                $sampleFiles = $uploadLines | Select-Object -First 5
                foreach ($file in $sampleFiles) {
                    $this.WriteLog("  $file", "INFO")
                }
                
                if ($uploadLines.Count -gt 5) {
                    $this.WriteLog("  ... and $($uploadLines.Count - 5) more files", "INFO")
                }
            }
        }
        else {
            $this.WriteLog("No files to process for $operation", "INFO")
        }
        
        # Log any errors found in AWS output
        if ($errorLines.Count -gt 0) {
            $this.WriteLog("=== AWS OPERATION ERRORS ===", "ERROR")
            foreach ($errorLine in $errorLines) {
                $this.WriteLog("  $errorLine", "ERROR")
            }
            $this.WriteLog("=== END ERRORS ===", "ERROR")
        }
        
        # Log summary statistics
        if ($skippedCount -gt 0) {
            $this.WriteLog("Files skipped (already up to date): $skippedCount", "INFO")
        }
    }

    [void]LogAWSError([int]$exitCode, [string[]]$output) {
        switch ($exitCode) {
            1 { $this.WriteLog("AWS Error: One or more S3 transfers failed", "ERROR") }
            2 { $this.WriteLog("AWS Error: Command line parsing error or invalid parameters", "ERROR") }
            130 { $this.WriteLog("AWS Error: Process interrupted (Ctrl+C)", "ERROR") }
            default { $this.WriteLog("AWS Error: Unknown exit code $exitCode", "ERROR") }
        }
        
        # Log error output
        $errorLines = $output | Where-Object { $_ -match "error|Error|ERROR" }
        foreach ($errorLine in $errorLines) {
            $this.WriteLog("AWS Output: $errorLine", "ERROR")
        }
    }

    [void]GenerateBackupSummary([bool]$dryRun) {
        $duration = $this.EndTime - $this.StartTime
        
        $this.WriteLog("=== BACKUP OPERATION SUMMARY ===", "INFO")
        $this.WriteLog("Operation Type: $(if ($dryRun) { 'DRY RUN BACKUP' } else { 'BACKUP' })", "INFO")
        $this.WriteLog("Start Time: $($this.StartTime.ToString('yyyy-MM-dd HH:mm:ss'))", "INFO")
        $this.WriteLog("End Time: $($this.EndTime.ToString('yyyy-MM-dd HH:mm:ss'))", "INFO")
        $this.WriteLog("Duration: $($duration.ToString('hh\:mm\:ss'))", "INFO")
        $this.WriteLog("Total Files Processed: $($this.TotalFiles)", "INFO")
        $this.WriteLog("Successful Operations: $($this.SuccessfulOperations)", "INFO")
        $this.WriteLog("Failed Operations: $($this.FailedOperations)", "INFO")
        $this.WriteLog("S3 Bucket: $($this.Config.S3Bucket)", "INFO")
        $this.WriteLog("AWS Profile: $($this.Config.AWSProfile)", "INFO")
        
        if ($this.FailedOperations -eq 0) {
            $this.WriteLog("BACKUP COMPLETED SUCCESSFULLY!", "SUCCESS")
        }
        else {
            $this.WriteLog("BACKUP COMPLETED WITH ERRORS - Check logs for details", "WARNING")
        }
        
        $this.WriteLog("=== END SUMMARY ===", "INFO")
    }

    [void]GenerateRestoreSummary([bool]$dryRun) {
        $duration = $this.EndTime - $this.StartTime
        
        $this.WriteLog("=== RESTORE OPERATION SUMMARY ===", "INFO")
        $this.WriteLog("Operation Type: $(if ($dryRun) { 'DRY RUN RESTORE' } else { 'RESTORE' })", "INFO")
        $this.WriteLog("Start Time: $($this.StartTime.ToString('yyyy-MM-dd HH:mm:ss'))", "INFO")
        $this.WriteLog("End Time: $($this.EndTime.ToString('yyyy-MM-dd HH:mm:ss'))", "INFO")
        $this.WriteLog("Duration: $($duration.ToString('hh\:mm\:ss'))", "INFO")
        $this.WriteLog("Total Files Processed: $($this.TotalFiles)", "INFO")
        $this.WriteLog("Restore Destination: $($this.Config.RestoreDestination)", "INFO")
        $this.WriteLog("S3 Bucket: $($this.Config.S3Bucket)", "INFO")
        $this.WriteLog("AWS Profile: $($this.Config.AWSProfile)", "INFO")
        
        if ($this.FailedOperations -eq 0) {
            $this.WriteLog("RESTORE COMPLETED SUCCESSFULLY!", "SUCCESS")
        }
        else {
            $this.WriteLog("RESTORE COMPLETED WITH ERRORS - Check logs for details", "WARNING")
        }
        
        $this.WriteLog("=== END SUMMARY ===", "INFO")
    }
}

# Main execution
try {
    $config = Load-Config
    $engine = [BackupEngine]::new($config)
    
    switch ($Operation) {
        "Backup" {
            $engine.RunBackup($DryRun)
        }
        "Restore" {
            $engine.RunRestore($DryRun)
        }
    }
}
catch {
    Write-Host "Fatal error in BackupEngine: $_" -ForegroundColor Red
    exit 1
}

# Keep console open if running interactively
if ($Host.Name -eq "ConsoleHost") {
    Write-Host "Press any key to continue..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}