#Requires -Version 5.1
<#
.SYNOPSIS
    Simple AWS CLI test for restore operations
.DESCRIPTION
    Basic test to identify AWS CLI sync issues
#>

# Import shared functions
. "$PSScriptRoot\..\core\BackupSharedFunctions.ps1"

Write-Host "=== SIMPLE AWS CLI TEST ===" -ForegroundColor Yellow
Write-Host ""

# Load configuration
$config = Load-Config
Write-Host "Configuration loaded:" -ForegroundColor Cyan
Write-Host "  S3 Bucket: $($config.S3Bucket)" -ForegroundColor White
Write-Host "  AWS Profile: $($config.AWSProfile)" -ForegroundColor White
Write-Host "  Restore Destination: $($config.RestoreDestination)" -ForegroundColor White
Write-Host ""

# Test 1: AWS CLI version
Write-Host "Test 1: AWS CLI Version" -ForegroundColor Green
try {
    $awsVersion = aws --version 2>&1
    Write-Host "  ✓ AWS CLI: $awsVersion" -ForegroundColor Green
}
catch {
    Write-Host "  ✗ AWS CLI not found: $_" -ForegroundColor Red
    exit 1
}

# Test 2: AWS credentials
Write-Host "Test 2: AWS Credentials" -ForegroundColor Green
try {
    $identity = aws sts get-caller-identity --profile $config.AWSProfile 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ AWS credentials valid" -ForegroundColor Green
    }
    else {
        Write-Host "  ✗ AWS credentials failed: $identity" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "  ✗ Exception: $_" -ForegroundColor Red
    exit 1
}
}

# Test 3: S3 bucket access
Write-Host "Test 3: S3 Bucket Access" -ForegroundColor Green
try {
    aws s3api head-bucket --bucket $config.S3Bucket --profile $config.AWSProfile 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ S3 bucket accessible" -ForegroundColor Green
    }
    else {
        Write-Host "  ✗ S3 bucket not accessible" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "  ✗ Exception: $_" -ForegroundColor Red
    exit 1
}
}

# Test 4: List S3 contents (with timeout)
Write-Host "Test 4: S3 Contents (with 30s timeout)" -ForegroundColor Green
try {
    Write-Host "  Listing S3 contents..." -ForegroundColor Cyan
    
    # Use Start-Process with timeout for better control
    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = "aws"
    $processInfo.Arguments = "s3 ls s3://$($config.S3Bucket)/ --profile $($config.AWSProfile) --recursive"
    $processInfo.RedirectStandardOutput = $true
    $processInfo.RedirectStandardError = $true
    $processInfo.UseShellExecute = $false
    $processInfo.CreateNoWindow = $true
    
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $processInfo
    $process.Start() | Out-Null
    
    $completed = $process.WaitForExit(30000)  # 30 second timeout
    
    if ($completed) {
        $output = $process.StandardOutput.ReadToEnd()
        $error = $process.StandardError.ReadToEnd()
        $exitCode = $process.ExitCode
        
        if ($exitCode -eq 0) {
            $lines = $output -split "`n" | Where-Object { $_.Trim() -ne "" }
            Write-Host "  ✓ Found $($lines.Count) items in S3" -ForegroundColor Green
            
            if ($lines.Count -gt 0) {
                Write-Host "  Sample (first 3 items):" -ForegroundColor Cyan
                $lines | Select-Object -First 3 | ForEach-Object {
                    Write-Host "    $_" -ForegroundColor Gray
                }
            }
        }
        else {
            Write-Host "  ✗ S3 list failed with exit code: $exitCode" -ForegroundColor Red
            Write-Host "  Error: $error" -ForegroundColor Red
        }
    }
    else {
        Write-Host "  ✗ S3 list command timed out after 30 seconds" -ForegroundColor Red
        $process.Kill()
    }
    
    $process.Dispose()
}
catch {
    Write-Host "  ✗ Exception: $_" -ForegroundColor Red
}

# Test 5: Simple sync test with timeout
Write-Host "Test 5: AWS S3 Sync Test (dry run with 60s timeout)" -ForegroundColor Green
$testDest = "C:\temp\RestoreTest"

try {
    # Create test destination
    if (-not (Test-Path $testDest)) {
        New-Item -ItemType Directory -Path $testDest -Force | Out-Null
    }
    
    Write-Host "  Testing sync to: $testDest" -ForegroundColor Cyan
    Write-Host "  Running dry run with timeout..." -ForegroundColor Cyan
    
    # Use Start-Process with timeout for sync command
    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = "aws"
    $processInfo.Arguments = "s3 sync s3://$($config.S3Bucket)/ `"$testDest`" --profile $($config.AWSProfile) --dryrun"
    $processInfo.RedirectStandardOutput = $true
    $processInfo.RedirectStandardError = $true
    $processInfo.UseShellExecute = $false
    $processInfo.CreateNoWindow = $true
    
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $processInfo
    $process.Start() | Out-Null
    
    Write-Host "  Command: aws s3 sync s3://$($config.S3Bucket)/ `"$testDest`" --profile $($config.AWSProfile) --dryrun" -ForegroundColor Gray
    
    $completed = $process.WaitForExit(60000)  # 60 second timeout
    
    if ($completed) {
        $output = $process.StandardOutput.ReadToEnd()
        $error = $process.StandardError.ReadToEnd()
        $exitCode = $process.ExitCode
        
        Write-Host "  Exit code: $exitCode" -ForegroundColor $(if ($exitCode -eq 0) { "Green" } else { "Red" })
        
        if ($output) {
            $outputLines = $output -split "`n" | Where-Object { $_.Trim() -ne "" }
            Write-Host "  Output lines: $($outputLines.Count)" -ForegroundColor Cyan
            
            if ($outputLines.Count -gt 0) {
                Write-Host "  Sample output (first 5 lines):" -ForegroundColor Cyan
                $outputLines | Select-Object -First 5 | ForEach-Object {
                    Write-Host "    $_" -ForegroundColor Gray
                }
            }
        }
        
        if ($error) {
            Write-Host "  Error output:" -ForegroundColor Red
            Write-Host "    $error" -ForegroundColor Red
        }
        
        if ($exitCode -eq 0) {
            Write-Host "  ✓ Sync test completed successfully" -ForegroundColor Green
        }
        else {
            Write-Host "  ✗ Sync test failed" -ForegroundColor Red
        }
    }
    else {
        Write-Host "  ✗ Sync command timed out after 60 seconds" -ForegroundColor Red
        Write-Host "  This suggests AWS CLI is hanging on the sync operation" -ForegroundColor Yellow
        $process.Kill()
    }
    
    $process.Dispose()
}
catch {
    Write-Host "  ✗ Exception: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== TEST COMPLETED ===" -ForegroundColor Yellow
Write-Host ""
Write-Host "If the sync command timed out, this indicates AWS CLI is hanging" -ForegroundColor Cyan
Write-Host "when trying to sync files. This could be due to:" -ForegroundColor Cyan
Write-Host "1. Network connectivity issues" -ForegroundColor White
Write-Host "2. AWS CLI version compatibility" -ForegroundColor White
Write-Host "3. Large number of files causing timeout" -ForegroundColor White
Write-Host "4. S3 bucket region/endpoint issues" -ForegroundColor White
Write-Host ""
Write-Host "Press any key to continue..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")