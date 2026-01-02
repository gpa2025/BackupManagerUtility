#Requires -Version 5.1
<#
.SYNOPSIS
    Test script for diagnosing restore operation issues
.DESCRIPTION
    Helps identify and troubleshoot problems with restore operations
.AUTHOR
    Enhanced by AI Assistant (Kiro)
.VERSION
    1.0
.DATE
    2025-12-30
#>

param(
    [switch]$DryRun = $true,
    [string]$TestDestination = "$env:TEMP\BackupRestoreTest"
)

# Import shared functions
. "$PSScriptRoot\..\core\BackupSharedFunctions.ps1"

Write-Host "=== BACKUP RESTORE OPERATION TEST ===" -ForegroundColor Yellow
Write-Host ""

# Load configuration
$config = Load-Config
Write-Host "Current Configuration:" -ForegroundColor Cyan
Write-Host "  Backup Type: $($config.BackupType)" -ForegroundColor White
Write-Host "  S3 Bucket: $($config.S3Bucket)" -ForegroundColor White
Write-Host "  AWS Profile: $($config.AWSProfile)" -ForegroundColor White
Write-Host "  Restore Destination: $($config.RestoreDestination)" -ForegroundColor White
Write-Host ""

# Test 1: AWS CLI availability
Write-Host "Test 1: AWS CLI Availability" -ForegroundColor Green
try {
    $awsVersion = aws --version 2>&1
    Write-Host "  ✓ AWS CLI found: $awsVersion" -ForegroundColor Green
}
catch {
    Write-Host "  ✗ AWS CLI not found: $_" -ForegroundColor Red
    exit 1
}

# Test 2: AWS Credentials
Write-Host "Test 2: AWS Credentials" -ForegroundColor Green
try {
    aws sts get-caller-identity --profile $config.AWSProfile | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ AWS credentials validated successfully" -ForegroundColor Green
    }
    else {
        Write-Host "  ✗ AWS credentials validation failed" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "  ✗ Error validating AWS credentials: $_" -ForegroundColor Red
    exit 1
}
}

# Test 3: S3 Bucket Access
Write-Host "Test 3: S3 Bucket Access" -ForegroundColor Green
try {
    aws s3api head-bucket --bucket $config.S3Bucket --profile $config.AWSProfile 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ S3 bucket '$($config.S3Bucket)' is accessible" -ForegroundColor Green
    }
    else {
        Write-Host "  ✗ S3 bucket '$($config.S3Bucket)' is not accessible" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "  ✗ Error accessing S3 bucket: $_" -ForegroundColor Red
    exit 1
}

# Test 4: List S3 Contents
Write-Host "Test 4: S3 Bucket Contents" -ForegroundColor Green
try {
    $s3Contents = aws s3 ls s3://$($config.S3Bucket)/ --profile $config.AWSProfile --recursive 2>&1
    if ($LASTEXITCODE -eq 0) {
        $fileCount = ($s3Contents | Measure-Object).Count
        Write-Host "  ✓ Found $fileCount items in S3 bucket" -ForegroundColor Green
        
        if ($fileCount -gt 0) {
            Write-Host "  Sample contents (first 5 items):" -ForegroundColor Cyan
            $s3Contents | Select-Object -First 5 | ForEach-Object {
                Write-Host "    $_" -ForegroundColor Gray
            }
        }
        else {
            Write-Host "  ⚠ S3 bucket is empty - nothing to restore" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "  ✗ Failed to list S3 bucket contents" -ForegroundColor Red
        Write-Host "  Error output: $s3Contents" -ForegroundColor Red
    }
}
catch {
    Write-Host "  ✗ Error listing S3 contents: $_" -ForegroundColor Red
}

# Test 5: Destination Path
Write-Host "Test 5: Restore Destination Path" -ForegroundColor Green
$originalDestination = $config.RestoreDestination

# Use test destination if specified
if ($TestDestination -ne "$env:TEMP\BackupRestoreTest") {
    $testDest = $TestDestination
}
else {
    $testDest = $TestDestination
}

Write-Host "  Testing with destination: $testDest" -ForegroundColor Cyan

try {
    if ($testDest.StartsWith("\\")) {
        Write-Host "  Network path detected" -ForegroundColor Yellow
        if (Test-Path $testDest) {
            Write-Host "  ✓ Network path is accessible" -ForegroundColor Green
        }
        else {
            Write-Host "  ✗ Network path is not accessible" -ForegroundColor Red
            Write-Host "  Trying to create path..." -ForegroundColor Yellow
            New-Item -ItemType Directory -Path $testDest -Force | Out-Null
            if (Test-Path $testDest) {
                Write-Host "  ✓ Network path created successfully" -ForegroundColor Green
            }
            else {
                Write-Host "  ✗ Failed to create network path" -ForegroundColor Red
            }
        }
    }
    else {
        Write-Host "  Local path detected" -ForegroundColor Yellow
        if (-not (Test-Path $testDest)) {
            New-Item -ItemType Directory -Path $testDest -Force | Out-Null
        }
        Write-Host "  ✓ Local path is ready" -ForegroundColor Green
    }
}
catch {
    Write-Host "  ✗ Error with destination path: $_" -ForegroundColor Red
}

# Test 6: Simple AWS S3 Sync Test
Write-Host "Test 6: AWS S3 Sync Test" -ForegroundColor Green
try {
    Write-Host "  Running AWS S3 sync dry run..." -ForegroundColor Cyan
    
    $awsArgs = @(
        "s3", "sync",
        "s3://$($config.S3Bucket)/",
        "`"$testDest`"",
        "--profile", $config.AWSProfile,
        "--dryrun"
    )
    
    $awsCommand = "aws " + ($awsArgs -join ' ')
    Write-Host "  Command: $awsCommand" -ForegroundColor Gray
    
    $output = & aws @awsArgs 2>&1
    $exitCode = $LASTEXITCODE
    
    Write-Host "  Exit code: $exitCode" -ForegroundColor $(if ($exitCode -eq 0) { "Green" } else { "Red" })
    
    if ($output -and $output.Count -gt 0) {
        Write-Host "  Output (first 10 lines):" -ForegroundColor Cyan
        $output | Select-Object -First 10 | ForEach-Object {
            Write-Host "    $_" -ForegroundColor Gray
        }
        
        if ($output.Count -gt 10) {
            Write-Host "    ... and $($output.Count - 10) more lines" -ForegroundColor Gray
        }
    }
    else {
        Write-Host "  No output from AWS CLI" -ForegroundColor Yellow
    }
    
    if ($exitCode -eq 0) {
        Write-Host "  ✓ AWS S3 sync test completed successfully" -ForegroundColor Green
    }
    else {
        Write-Host "  ✗ AWS S3 sync test failed" -ForegroundColor Red
    }
}
catch {
    Write-Host "  ✗ Exception during AWS S3 sync test: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== TEST COMPLETED ===" -ForegroundColor Yellow

if ($testDest -ne $originalDestination) {
    Write-Host ""
    Write-Host "Recommendation: If the test worked with the test destination," -ForegroundColor Cyan
    Write-Host "but fails with your network path, consider:" -ForegroundColor Cyan
    Write-Host "1. Using a local destination first, then copying to network" -ForegroundColor White
    Write-Host "2. Mapping the network drive to a drive letter" -ForegroundColor White
    Write-Host "3. Checking network permissions and connectivity" -ForegroundColor White
}

Write-Host ""
Write-Host "Press any key to continue..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")