# Enhanced Backup Manager v2.1

A comprehensive PowerShell-based backup and restore solution with modern GUI interface, real-time progress monitoring, scheduling capabilities, comprehensive logging, and command-line configuration management.

## 🚀 Quick Start

### **Easiest Way - Just Double-Click!**
1. **Download all files** to a folder
2. **Double-click `Quick-Launch-GUI.bat`** - Opens GUI instantly
3. **Or double-click `Launch-BackupManager.bat`** - Shows menu with options

## 📁 Organized File Structure

```
Enhanced-Backup-Manager/
├── Quick-Launch-GUI.bat          # Instant GUI launcher (recommended)
├── Launch-BackupManager.bat      # Full menu launcher with options
├── Launch-BackupManager.ps1      # PowerShell menu interface
├── BackupConfig.json             # Configuration file (auto-generated)
├── assets/                       # Icons and images
│   ├── icon.ico
│   └── SplashScreen.png
├── scripts/
│   ├── core/                     # Core backup engine scripts
│   │   ├── BackupEngine.ps1      # Main backup/restore engine
│   │   ├── BackupManager.ps1     # Entry point and coordination
│   │   ├── BackupScheduler.ps1   # Windows Task Scheduler integration
│   │   └── BackupSharedFunctions.ps1  # Shared functions and config
│   ├── gui/                      # GUI interface scripts
│   │   ├── BackupManagerGUI.ps1  # Enhanced GUI with 6 tabs
│   │   └── Backup-Menu.ps1       # Command-line menu interface
│   └── utilities/                # Utility and test scripts
│       ├── Simple-AWS-Test.ps1   # AWS connection testing
│       ├── Test-RestoreOperation.ps1  # Restore operation testing
│       ├── Manage-RestoredFiles.ps1   # File management utilities
│       ├── Clear-BackupConfig.ps1     # Configuration reset
│       └── Watch-BackupLog.ps1        # Log monitoring
└── docs/                         # Documentation
    ├── README.md                 # Detailed documentation
    ├── LOGGING_GUIDE.md          # Logging configuration guide
    └── VISUAL_ENHANCEMENTS.md    # GUI enhancement details
```

## ✨ Enhanced Features (v2.1)

- **Professional 6-tab GUI interface** with intuitive navigation
- **Real-time progress monitoring** with animated progress bars
- **AWS integration** with automatic bucket and profile discovery
- **Background operations** with cancel capability
- **Multi-level logging** with real-time monitoring
- **Scheduled backup** support via Windows Task Scheduler
- **Command-line configuration management** with review and update options

## 📋 Prerequisites

1. **Windows 10/11** with PowerShell 5.1 or later
2. **AWS CLI** - Install from https://aws.amazon.com/cli/
3. **AWS Account** with S3 access permissions
4. **AWS Credentials** - Configure using `aws configure`

## ⚙️ Initial Setup

### **First Time Configuration**
1. **Configure AWS CLI**: Run `aws configure` to set up your credentials
2. **Create S3 Bucket**: Create a bucket in your AWS account for backups
3. **Launch GUI**: Double-click `Quick-Launch-GUI.bat` to start the application
4. **Configure Settings**: Use the Configuration tab to set up your S3 bucket and backup folders

### **Configuration Files**
- `BackupConfig.json` - Main configuration (auto-generated on first run)
- `BackupConfig.example.json` - Template with examples and documentation
- Configuration is automatically created with safe defaults when you first run the GUI

## 🎯 Launch Options

### **For New Users (Recommended)**
```batch
# Double-click this file - no technical knowledge needed
Quick-Launch-GUI.bat
```

### **For Advanced Users**
```batch
# Full menu with configuration management
Launch-BackupManager.bat
```

### **Launch-BackupManager.bat Menu Options**
```
=== MAIN OPERATIONS ===
1. Launch GUI Interface (Recommended for new users)
2. Launch Quick Menu (Command line interface)
3. Run Backup (Direct backup with current settings)
4. Run Restore (Direct restore with current settings)

=== CONFIGURATION ===
5. Review Current Configuration
6. Update Configuration Settings
7. Configure Scheduled Backups

=== HELP & SUPPORT ===
8. View Help and Exit
```

### **Configuration Management Features**
- **Review Configuration** (Option 5): View all current settings in organized sections
- **Update Configuration** (Option 6): Modify specific settings:
  - AWS Settings (S3 bucket, profile, backup type)
  - Backup Folders (launches GUI for easy management)
  - Restore Destination paths
  - Logging Settings (MINIMAL/INFO/DETAILED/ALL)
  - Exclude Patterns management
  - Direct file editing with JSON validation
  - Reset to defaults with confirmation

### **PowerShell Direct Launch**
```powershell
# GUI Interface
.\scripts\gui\BackupManagerGUI.ps1

# Command Line Menu
.\Launch-BackupManager.ps1

# Direct Operations
.\scripts\core\BackupEngine.ps1 -Operation Backup -DryRun
.\scripts\core\BackupEngine.ps1 -Operation Restore

# Scheduler Configuration
.\scripts\core\BackupScheduler.ps1
```

## 📊 Monitoring and Logs

### **Log Files** (saved to Desktop)
- **`BackupManager.log`** - Main application log
- **`BackupEngine.log`** - Detailed backup/restore operations
- **`BackupScheduler.log`** - Scheduling operations

## 🛠️ Configuration Management

### **Quick Configuration Review**
Use `Launch-BackupManager.bat` → Option 5 to view:
- Current backup type and destinations
- Enabled/disabled backup folders
- AWS settings (S3 bucket, profile)
- Logging and scheduling settings
- Exclude patterns

### **Easy Configuration Updates**
Use `Launch-BackupManager.bat` → Option 6 for:
- **AWS Settings**: Update S3 bucket, AWS profile, backup type
- **Backup Folders**: Launch GUI for visual folder management
- **Restore Destination**: Change where files are restored
- **Logging Settings**: Adjust verbosity (MINIMAL/INFO/DETAILED/ALL)
- **Exclude Patterns**: Manage files/folders to skip
- **Direct Editing**: Open config file in Notepad with validation
- **Reset to Defaults**: Start fresh with confirmation

### **Configuration File Location**
- Main config: `BackupConfig.json` (in root folder)
- Automatically created on first GUI launch
- JSON format with validation checking

## 🛠️ Troubleshooting

### **Common Issues**

1. **"AWS CLI not found"**
   - Install AWS CLI from official website
   - Ensure it's in your system PATH

2. **"AWS credentials invalid"**
   - Run `aws configure --profile your-profile`
   - Verify credentials with `aws sts get-caller-identity`

3. **"GUI won't start"**
   - Ensure .NET Framework 4.5+ is installed
   - Try running as administrator

4. **"Configuration issues"**
   - Use `Launch-BackupManager.bat` → Option 5 to review settings
   - Use Option 6 to update specific settings
   - Use Option 6 → 7 to reset to defaults if needed

5. **"Large backup taking too long"**
   - Your backup may be processing many files (this is normal)
   - Check `%USERPROFILE%\Desktop\BackupEngine.log` for progress
   - Consider reducing backup scope in configuration
   - Use dry run first to estimate time and data size

For detailed documentation, see `docs/README.md`

## 👥 Credits

**Original Backup Scripts**: Gianpaolo Albanese (2024)  
**Enhanced GUI & Organization**: AI Assistant (2025)  
**Configuration Management**: AI Assistant (2025)  
**Technology Stack**: PowerShell, .NET WinForms, AWS CLI, Batch Scripts