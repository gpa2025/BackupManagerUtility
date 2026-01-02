# Enhanced Logging Guide

## Overview
The backup system now includes comprehensive logging with configurable verbosity levels and detailed file operation tracking.

## Log Levels

### MINIMAL
- Only shows ERROR and SUCCESS messages
- Best for automated/scheduled backups where you only want to know if something failed
- Minimal log file size

### INFO (Default)
- Shows INFO, WARNING, ERROR, and SUCCESS messages
- Provides operation summaries and basic progress information
- Good balance between detail and log size

### DETAILED
- All INFO level messages plus DETAILED messages
- Shows file operation summaries and analysis
- Includes pre-operation file scanning results
- Good for troubleshooting and understanding what will be processed

### ALL
- Maximum verbosity - shows every individual file operation
- Includes all skipped files, copied files, and detailed error information
- Best for debugging specific file issues
- Can generate large log files with many files

## Configuration

### In BackupConfig.json
```json
{
    "LogLevel": "ALL",
    "LogFileOperations": true,
    "LogFailuresOnly": false
}
```

### Configuration Options

- **LogLevel**: "MINIMAL", "INFO", "DETAILED", or "ALL"
- **LogFileOperations**: true/false - Whether to log individual file operations
- **LogFailuresOnly**: true/false - When true, only logs failed file operations (useful with ALL level)

## What You'll See at Each Level

### AWS S3 Operations
- **INFO**: Summary of files processed, sample of first 5 files
- **DETAILED**: All uploaded/downloaded files, skipped files summary
- **ALL**: Every single file operation, including skipped files

### Local/Robocopy Operations
- **INFO**: Summary statistics (file count, total size)
- **DETAILED**: Pre-scan analysis showing what will be copied/updated
- **ALL**: Every individual file copy operation, including unchanged files

### Error Reporting
- All levels show errors, but higher levels provide more context
- **ALL** level shows the exact file that failed and why

## Log File Locations
- Main log: `%USERPROFILE%\Desktop\BackupManager.log`
- Engine log: `%USERPROFILE%\Desktop\BackupEngine.log`

## Testing the New Logging

1. **Test different log levels:**
   ```powershell
   .\Test-EnhancedLogging.ps1 -LogLevel ALL
   ```

2. **Run a dry-run backup to see file analysis:**
   ```powershell
   .\BackupEngine.ps1 -Operation Backup -DryRun
   ```

3. **Run actual backup with detailed logging:**
   ```powershell
   .\BackupEngine.ps1 -Operation Backup
   ```

## Performance Considerations

- **ALL** level can significantly increase log file size with large backups
- Use **LogFailuresOnly** with **ALL** level to focus on problems
- **DETAILED** level provides good insight without excessive file-by-file logging
- Log files are automatically rotated based on **LogRetentionDays** setting

## Troubleshooting Common Issues

### "No files being logged"
- Check that `LogFileOperations` is set to `true`
- Ensure `LogLevel` is set to "DETAILED" or "ALL"
- Verify the backup operation is actually processing files

### "Too much logging"
- Set `LogLevel` to "INFO" or "MINIMAL"
- Enable `LogFailuresOnly` to focus on problems
- Reduce `LogRetentionDays` to clean up old logs faster

### "Missing error details"
- Set `LogLevel` to "ALL" for maximum error detail
- Check both console output and log files
- Errors are always logged regardless of level

## Example Log Output

### MINIMAL Level
```
[2025-12-23 10:30:15] [SUCCESS] BACKUP COMPLETED SUCCESSFULLY!
```

### INFO Level
```
[2025-12-23 10:30:10] [INFO] Starting backup operation (DryRun: False)
[2025-12-23 10:30:12] [INFO] Processed 150 files for Documents
[2025-12-23 10:30:15] [SUCCESS] BACKUP COMPLETED SUCCESSFULLY!
```

### ALL Level
```
[2025-12-23 10:30:10] [INFO] Starting backup operation (DryRun: False)
[2025-12-23 10:30:11] [DETAILED] === FILE OPERATIONS FOR Documents ===
[2025-12-23 10:30:11] [FILE] upload: Documents/report.pdf to s3://bucket/Documents/report.pdf
[2025-12-23 10:30:11] [FILE] upload: Documents/data.xlsx to s3://bucket/Documents/data.xlsx
[2025-12-23 10:30:12] [FILE] skip: Documents/old_file.txt (already up to date)
[2025-12-23 10:30:12] [DETAILED] === END FILE OPERATIONS ===
[2025-12-23 10:30:15] [SUCCESS] BACKUP COMPLETED SUCCESSFULLY!
```