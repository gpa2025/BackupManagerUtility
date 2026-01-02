# Enhanced Backup Manager v2.0

A comprehensive PowerShell-based backup and restore solution with modern GUI interface, real-time progress monitoring, scheduling capabilities, and comprehensive logging.

## 🚀 Quick Start for New Users

### **Easiest Way - Just Double-Click!**
1. **Download all files** to a folder
2. **Double-click `Quick-Launch-GUI.bat`** - Opens GUI instantly
3. **Or double-click `Launch-BackupManager.bat`** - Shows menu with options

### **First Time Setup:**
1. Launch the GUI using either batch file
2. Go to **Configuration tab** → Set up AWS credentials and S3 bucket
3. Go to **Backup Folders tab** → Select folders to backup
4. Go to **Operations tab** → Try a "Dry Run Backup" first
5. Check **Logs & Monitoring tab** for progress and results

## ✨ Enhanced Features (v2.0)

### **Modern GUI Interface**
- **Professional 6-tab interface** with intuitive navigation
- **Real-time progress monitoring** with animated progress bars
- **Dropdown menus** for S3 buckets and AWS profiles with auto-refresh
- **Color-coded status indicators** and operation feedback
- **Built-in Help and About tabs** with comprehensive documentation
- **Background operations** with cancel capability
- **Auto-refreshing logs** with terminal-style display

### **Smart Configuration**
- **AWS integration** with automatic bucket and profile discovery
- **Connection testing** with visual status feedback
- **Flexible folder selection** with check all/uncheck all options
- **Custom folder addition** with browse dialog
- **Configuration validation** and error handling

### **Advanced Operations**
- **Real-time progress tracking** during backup/restore operations
- **Background processing** with live status updates
- **Operation cancellation** capability
- **Dry run mode** for safe testing
- **Comprehensive statistics** and operation summaries

### **Professional Logging**
- **Multi-level logging** (INFO, WARNING, ERROR, SUCCESS)
- **Real-time log monitoring** with auto-refresh
- **Terminal-style log display** with syntax highlighting
- **Operation statistics** and performance metrics
- **Error tracking** with detailed troubleshooting information

## 📁 File Structure

### **User Launch Files**
- **`Quick-Launch-GUI.bat`** - Instant GUI launcher (recommended)
- **`Launch-BackupManager.bat`** - Full menu launcher with options
- **`Launch-BackupManager.ps1`** - PowerShell menu interface

### **Core Application Files**
- **`BackupManagerGUI.ps1`** - Enhanced GUI interface with 6 tabs
- **`BackupEngine.ps1`** - Core backup and restore engine
- **`BackupScheduler.ps1`** - Windows Task Scheduler integration
- **`BackupSharedFunctions.ps1`** - Shared functions and configuration
- **`BackupManager.ps1`** - Main entry point and coordination

### **Configuration**
- **`BackupConfig.json`** - Configuration file (auto-generated)

## 🎯 Launch Options

### **For New Users (Recommended)**
```batch
# Double-click this file - no technical knowledge needed
Quick-Launch-GUI.bat
```

### **For Advanced Users**
```batch
# Full menu with all options
Launch-BackupManager.bat
```

### **PowerShell Direct Launch**
```powershell
# GUI Interface
.\BackupManagerGUI.ps1

# Command Line Menu
.\Launch-BackupManager.ps1

# Direct Operations
.\BackupEngine.ps1 -Operation Backup -DryRun
.\BackupEngine.ps1 -Operation Restore

# Scheduler Configuration
.\BackupScheduler.ps1
```

## 📋 Prerequisites

### **Required**
1. **Windows 10/11** with PowerShell 5.1 or later
2. **AWS CLI** - Install from https://aws.amazon.com/cli/
3. **AWS Account** with S3 access permissions
4. **AWS Credentials** - Configure using `aws configure`

### **Optional**
- **Administrative privileges** for scheduled task creation
- **Network access** for S3 operations
- **.NET Framework 4.5+** (usually pre-installed)

## ⚙️ Configuration

### **AWS Setup**
1. **Install AWS CLI**: Download from https://aws.amazon.com/cli/
2. **Configure credentials**: Run `aws configure` in command prompt
3. **Create S3 bucket** or use existing one
4. **Verify permissions**: Ensure your AWS user has S3 read/write access

### **Application Setup**
1. **Launch GUI**: Use `Quick-Launch-GUI.bat`
2. **Configuration Tab**: 
   - Select S3 bucket (or use "Refresh Buckets")
   - Choose AWS profile (or use "Refresh Profiles")
   - Test connection with "Test AWS Connection"
   - Set restore destination path
3. **Backup Folders Tab**:
   - Check folders you want to backup
   - Add custom folders if needed
   - Use "Check All" for quick selection

## 🔄 Usage Examples

### **GUI Operations**
1. **Configuration**: Set up AWS and paths in Configuration tab
2. **Selection**: Choose folders in Backup Folders tab
3. **Testing**: Use "Dry Run" operations first
4. **Monitoring**: Watch progress in Operations tab
5. **Logging**: Check Logs & Monitoring tab for details

### **Scheduling**
1. **GUI Method**: Operations tab → "Configure Schedule"
2. **Direct Method**: Run `BackupScheduler.ps1`
3. **Options**: Daily, Weekly, or Monthly automated backups
4. **Integration**: Uses Windows Task Scheduler

### **Command Line (Advanced)**
```powershell
# Test backup without transferring files
.\BackupEngine.ps1 -Operation Backup -DryRun

# Actual backup operation
.\BackupEngine.ps1 -Operation Backup

# Restore from S3
.\BackupEngine.ps1 -Operation Restore

# Configure scheduling
.\BackupScheduler.ps1 -Configure
```

## 📊 Monitoring and Logs

### **Real-time Monitoring**
- **Operations tab**: Live progress bars and status updates
- **Background processing**: Operations run without blocking GUI
- **Cancellation**: Stop operations if needed

### **Log Files** (saved to Desktop)
- **`BackupManager.log`** - Main application log
- **`BackupEngine.log`** - Detailed backup/restore operations
- **`BackupScheduler.log`** - Scheduling operations

### **Log Levels**
- **INFO**: General operation information
- **SUCCESS**: Successful operations
- **WARNING**: Non-critical issues
- **ERROR**: Critical errors requiring attention

## 🛠️ Troubleshooting

### **Common Issues**

1. **"AWS CLI not found"**
   - Install AWS CLI from official website
   - Ensure it's in your system PATH
   - Restart command prompt/GUI after installation

2. **"AWS credentials invalid"**
   - Run `aws configure --profile your-profile`
   - Verify credentials with `aws sts get-caller-identity`
   - Check IAM permissions for S3 operations

3. **"S3 bucket access denied"**
   - Verify bucket exists and you have access
   - Check IAM permissions for S3 operations
   - Try "Refresh Buckets" in GUI

4. **"Scheduled task not running"**
   - Verify task exists: Check Windows Task Scheduler
   - Ensure PowerShell execution policy allows scripts
   - Check task history for error details

5. **"GUI won't start"**
   - Ensure .NET Framework 4.5+ is installed
   - Try running as administrator
   - Check Windows Forms assemblies are available

### **Getting Help**
- **Built-in Help**: Use the Help tab in the GUI
- **Log Analysis**: Check log files on Desktop for detailed errors
- **Test Mode**: Always use "Dry Run" first to test configuration
- **Connection Test**: Use "Test AWS Connection" in Configuration tab

## 🔒 Security Considerations

- **AWS credentials** are stored using AWS CLI standard methods
- **Scheduled tasks** run with user privileges (can be elevated if needed)
- **Log files** may contain file paths - review before sharing
- **S3 bucket access** should follow least-privilege principle
- **Network traffic** is encrypted using AWS S3 HTTPS endpoints

## 🚀 Performance Tips

- **Use `--size-only`** for faster sync operations (automatically enabled)
- **Exclude unnecessary files** using the exclude patterns configuration
- **Schedule backups** during off-peak hours to minimize impact
- **Monitor S3 costs** for large datasets and frequent operations
- **Use dry run mode** to estimate transfer times and costs

## 📈 Version History

### **v2.0 (2025-12-23) - Enhanced Edition**
- ✅ Complete GUI redesign with 6 professional tabs
- ✅ Real-time progress monitoring and background operations
- ✅ Dropdown menus with AWS integration
- ✅ Built-in Help and About tabs
- ✅ Batch file launchers for easy access
- ✅ Enhanced error handling and logging
- ✅ Operation cancellation capability
- ✅ Auto-refreshing logs and statistics

### **v1.0 (2024-12-16) - Original**
- ✅ Basic PowerShell backup and restore scripts
- ✅ AWS S3 integration
- ✅ Command-line interface
- ✅ Basic logging and error handling

## 👥 Credits

**Original Backup Scripts**: Gianpaolo Albanese (2024)
**Enhanced GUI & Features**: AI Assistant (2025)
**Technology Stack**: PowerShell, .NET WinForms, AWS CLI

---

## 🎯 Quick Reference

**New User**: Double-click `Quick-Launch-GUI.bat`
**Advanced User**: Double-click `Launch-BackupManager.bat`
**Help**: Launch GUI → Help tab
**Logs**: Check Desktop for .log files
**Support**: Use built-in Help tab and troubleshooting section