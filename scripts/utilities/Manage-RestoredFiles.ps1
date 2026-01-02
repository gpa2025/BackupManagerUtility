#Requires -Version 5.1
<#
.SYNOPSIS
    Utility to manage restored files and cleanup unexpected restore locations
.DESCRIPTION
    Helps identify, move, or clean up files that were restored to unexpected locations
.AUTHOR
    Enhanced by AI Assistant (Kiro)
.VERSION
    1.0
.DATE
    2025-12-31
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$SourcePath = "$env:USERPROFILE\Restored",
    
    [Parameter(Mandatory=$false)]
    [string]$TargetPath = "",
    
    [ValidateSet("Analyze", "Move", "Delete")]
    [string]$Action = "Analyze"
)

# Import shared functions
. "$PSScriptRoot\..\core\BackupSharedFunctions.ps1"

function Show-FolderAnalysis {
    param([string]$Path)
    
    Write-Host "=== FOLDER ANALYSIS: $Path ===" -ForegroundColor Yellow
    
    if (-not (Test-Path $Path)) {
        Write-Host "Path does not exist: $Path" -ForegroundColor Red
        return
    }
    
    try {
        # Get folder statistics
        $items = Get-ChildItem -Path $Path -Recurse -ErrorAction SilentlyContinue
        $files = $items | Where-Object { -not $_.PSIsContainer }
        $folders = $items | Where-Object { $_.PSIsContainer }
        
        $totalSize = ($files | Measure-Object -Property Length -Sum).Sum
        $totalSizeGB = [math]::Round($totalSize / 1GB, 2)
        $totalSizeMB = [math]::Round($totalSize / 1MB, 2)
        
        Write-Host ""
        Write-Host "Statistics:" -ForegroundColor Cyan
        Write-Host "  Total Files: $($files.Count)" -ForegroundColor White
        Write-Host "  Total Folders: $($folders.Count)" -ForegroundColor White
        Write-Host "  Total Size: $totalSizeGB GB ($totalSizeMB MB)" -ForegroundColor White
        Write-Host ""
        
        # Show top-level folders
        $topLevelFolders = Get-ChildItem -Path $Path -Directory -ErrorAction SilentlyContinue
        if ($topLevelFolders) {
            Write-Host "Top-level folders:" -ForegroundColor Cyan
            foreach ($folder in $topLevelFolders) {
                $folderItems = Get-ChildItem -Path $folder.FullName -Recurse -File -ErrorAction SilentlyContinue
                $folderSize = ($folderItems | Measure-Object -Property Length -Sum).Sum
                $folderSizeGB = [math]::Round($folderSize / 1GB, 2)
                $folderSizeMB = [math]::Round($folderSize / 1MB, 2)
                
                if ($folderSizeGB -gt 0.1) {
                    Write-Host "  $($folder.Name): $folderSizeGB GB ($($folderItems.Count) files)" -ForegroundColor White
                }
                else {
                    Write-Host "  $($folder.Name): $folderSizeMB MB ($($folderItems.Count) files)" -ForegroundColor White
                }
            }
        }
        
        # Show largest files
        Write-Host ""
        Write-Host "Largest files (top 10):" -ForegroundColor Cyan
        $largestFiles = $files | Sort-Object Length -Descending | Select-Object -First 10
        foreach ($file in $largestFiles) {
            $fileSizeMB = [math]::Round($file.Length / 1MB, 2)
            $relativePath = $file.FullName.Replace($Path, "").TrimStart('\')
            Write-Host "  $fileSizeMB MB - $relativePath" -ForegroundColor Gray
        }
        
        Write-Host ""
        Write-Host "=== END ANALYSIS ===" -ForegroundColor Yellow
    }
    catch {
        Write-Host "Error analyzing folder: $_" -ForegroundColor Red
    }
}

function Move-RestoredFiles {
    param(
        [string]$Source,
        [string]$Target
    )
    
    Write-Host "=== MOVING FILES ===" -ForegroundColor Yellow
    Write-Host "From: $Source" -ForegroundColor Cyan
    Write-Host "To: $Target" -ForegroundColor Cyan
    Write-Host ""
    
    if (-not (Test-Path $Source)) {
        Write-Host "Source path does not exist: $Source" -ForegroundColor Red
        return $false
    }
    
    # Confirm the move
    $confirmation = Read-Host "Are you sure you want to move all files from '$Source' to '$Target'? (y/N)"
    if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
        Write-Host "Move operation cancelled." -ForegroundColor Yellow
        return $false
    }
    
    try {
        # Create target directory if it doesn't exist
        if (-not (Test-Path $Target)) {
            Write-Host "Creating target directory..." -ForegroundColor Yellow
            New-Item -ItemType Directory -Path $Target -Force | Out-Null
        }
        
        # Test write access to target
        $testFile = Join-Path $Target "move_test_$(Get-Date -Format 'yyyyMMddHHmmss').tmp"
        try {
            "test" | Out-File -FilePath $testFile -ErrorAction Stop
            Remove-Item $testFile -ErrorAction SilentlyContinue
        }
        catch {
            Write-Host "Cannot write to target directory: $_" -ForegroundColor Red
            return $false
        }
        
        # Use robocopy for efficient moving
        Write-Host "Starting file move operation..." -ForegroundColor Green
        
        $robocopyArgs = @(
            "`"$Source`"",
            "`"$Target`"",
            "/E",      # Copy subdirectories including empty ones
            "/MOVE",   # Move files and directories (delete from source)
            "/R:3",    # Retry 3 times on failed copies
            "/W:1",    # Wait 1 second between retries
            "/MT:4",   # Multi-threaded copy (4 threads)
            "/V",      # Verbose output
            "/TS",     # Include source file timestamps
            "/FP"      # Include full pathname of files
        )
        
        Write-Host "Executing: robocopy $($robocopyArgs -join ' ')" -ForegroundColor Gray
        
        $output = & robocopy @robocopyArgs 2>&1
        $exitCode = $LASTEXITCODE
        
        # Robocopy exit codes: 0-7 are success, 8+ are errors
        if ($exitCode -le 7) {
            Write-Host "Files moved successfully!" -ForegroundColor Green
            
            # Check if source directory is now empty
            $remainingItems = Get-ChildItem -Path $Source -Recurse -ErrorAction SilentlyContinue
            if (-not $remainingItems) {
                Write-Host "Source directory is now empty. Removing..." -ForegroundColor Yellow
                Remove-Item -Path $Source -Force -Recurse -ErrorAction SilentlyContinue
                Write-Host "Source directory removed." -ForegroundColor Green
            }
            else {
                Write-Host "Some items remain in source directory." -ForegroundColor Yellow
            }
            
            return $true
        }
        else {
            Write-Host "Move operation failed with exit code: $exitCode" -ForegroundColor Red
            Write-Host "Robocopy output:" -ForegroundColor Gray
            $output | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
            return $false
        }
    }
    catch {
        Write-Host "Error during move operation: $_" -ForegroundColor Red
        return $false
    }
}

function Remove-RestoredFiles {
    param([string]$Path)
    
    Write-Host "=== DELETING FILES ===" -ForegroundColor Red
    Write-Host "Path: $Path" -ForegroundColor Cyan
    Write-Host ""
    
    if (-not (Test-Path $Path)) {
        Write-Host "Path does not exist: $Path" -ForegroundColor Red
        return $false
    }
    
    # Show what will be deleted
    Show-FolderAnalysis $Path
    
    Write-Host ""
    Write-Host "WARNING: This will permanently delete all files and folders in the specified path!" -ForegroundColor Red
    $confirmation = Read-Host "Are you absolutely sure you want to delete everything in '$Path'? Type 'DELETE' to confirm"
    
    if ($confirmation -ne 'DELETE') {
        Write-Host "Delete operation cancelled." -ForegroundColor Yellow
        return $false
    }
    
    try {
        Write-Host "Deleting files and folders..." -ForegroundColor Red
        Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
        Write-Host "Files deleted successfully." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Error deleting files: $_" -ForegroundColor Red
        return $false
    }
}

# Main execution
Write-Host "=== RESTORED FILES MANAGER ===" -ForegroundColor Green
Write-Host ""

# Load current configuration to show context
$config = Load-Config
Write-Host "Current restore destination: $($config.RestoreDestination)" -ForegroundColor Cyan
Write-Host "Checking path: $SourcePath" -ForegroundColor Cyan
Write-Host ""

switch ($Action) {
    "Analyze" {
        Show-FolderAnalysis $SourcePath
        
        if (Test-Path $SourcePath) {
            Write-Host ""
            Write-Host "Available actions:" -ForegroundColor Yellow
            Write-Host "1. Move files to intended destination:" -ForegroundColor White
            Write-Host "   .\Manage-RestoredFiles.ps1 -Action Move -TargetPath 'C:\YourIntendedPath'" -ForegroundColor Gray
            Write-Host ""
            Write-Host "2. Move files to current config destination:" -ForegroundColor White
            Write-Host "   .\Manage-RestoredFiles.ps1 -Action Move -TargetPath '$($config.RestoreDestination)'" -ForegroundColor Gray
            Write-Host ""
            Write-Host "3. Delete files (PERMANENT):" -ForegroundColor White
            Write-Host "   .\Manage-RestoredFiles.ps1 -Action Delete" -ForegroundColor Gray
        }
    }
    
    "Move" {
        if ([string]::IsNullOrWhiteSpace($TargetPath)) {
            Write-Host "Target path is required for move operation." -ForegroundColor Red
            Write-Host "Use: .\Manage-RestoredFiles.ps1 -Action Move -TargetPath 'C:\YourPath'" -ForegroundColor Yellow
        }
        else {
            $success = Move-RestoredFiles $SourcePath $TargetPath
            if ($success) {
                Write-Host ""
                Write-Host "Move completed successfully!" -ForegroundColor Green
            }
        }
    }
    
    "Delete" {
        $success = Remove-RestoredFiles $SourcePath
        if ($success) {
            Write-Host ""
            Write-Host "Delete completed successfully!" -ForegroundColor Green
        }
    }
}

Write-Host ""
Write-Host "Press any key to continue..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")