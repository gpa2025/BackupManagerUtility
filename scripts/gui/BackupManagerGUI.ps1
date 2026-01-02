#Requires -Version 5.1
<#
.SYNOPSIS
    Enhanced GUI Interface for Backup Manager
.DESCRIPTION
    Provides a Windows Forms-based graphical interface with improved UX including
    dropdown menus, better layout, and real-time progress monitoring.
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

# Import required assemblies FIRST
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Import shared functions
. "$PSScriptRoot\..\core\BackupSharedFunctions.ps1"

# Function to show splash screen
function Show-SplashScreen {
    param([int]$Duration = 3000)
    
    try {
        # Create splash screen form
        $splashForm = New-Object System.Windows.Forms.Form
        $splashForm.Text = "Enhanced Backup Manager"
        $splashForm.Size = New-Object System.Drawing.Size(400, 300)
        $splashForm.StartPosition = "CenterScreen"
        $splashForm.FormBorderStyle = "None"
        $splashForm.BackColor = [System.Drawing.Color]::White
        $splashForm.TopMost = $true
        
        # Try to load splash image
        $splashPath = Join-Path $PSScriptRoot "..\..\assets\SplashScreen.png"
        if (Test-Path $splashPath) {
            $pictureBox = New-Object System.Windows.Forms.PictureBox
            $pictureBox.Size = New-Object System.Drawing.Size(380, 200)
            $pictureBox.Location = New-Object System.Drawing.Point(10, 10)
            $pictureBox.SizeMode = "Zoom"
            $pictureBox.Image = [System.Drawing.Image]::FromFile($splashPath)
            $splashForm.Controls.Add($pictureBox)
        }
        else {
            # Fallback to text logo
            $titleLabel = New-Object System.Windows.Forms.Label
            $titleLabel.Text = "Enhanced Backup Manager"
            $titleLabel.Font = New-Object System.Drawing.Font("Arial", 18, [System.Drawing.FontStyle]::Bold)
            $titleLabel.ForeColor = [System.Drawing.Color]::DarkBlue
            $titleLabel.Size = New-Object System.Drawing.Size(380, 40)
            $titleLabel.Location = New-Object System.Drawing.Point(10, 80)
            $titleLabel.TextAlign = "MiddleCenter"
            $splashForm.Controls.Add($titleLabel)
            
            $versionLabel = New-Object System.Windows.Forms.Label
            $versionLabel.Text = "Version 2.1"
            $versionLabel.Font = New-Object System.Drawing.Font("Arial", 12)
            $versionLabel.ForeColor = [System.Drawing.Color]::Gray
            $versionLabel.Size = New-Object System.Drawing.Size(380, 30)
            $versionLabel.Location = New-Object System.Drawing.Point(10, 120)
            $versionLabel.TextAlign = "MiddleCenter"
            $splashForm.Controls.Add($versionLabel)
        }
        
        # Loading label
        $loadingLabel = New-Object System.Windows.Forms.Label
        $loadingLabel.Text = "Loading..."
        $loadingLabel.Font = New-Object System.Drawing.Font("Arial", 10)
        $loadingLabel.ForeColor = [System.Drawing.Color]::DarkBlue
        $loadingLabel.Size = New-Object System.Drawing.Size(380, 30)
        $loadingLabel.Location = New-Object System.Drawing.Point(10, 220)
        $loadingLabel.TextAlign = "MiddleCenter"
        $splashForm.Controls.Add($loadingLabel)
        
        # Progress bar
        $progressBar = New-Object System.Windows.Forms.ProgressBar
        $progressBar.Size = New-Object System.Drawing.Size(360, 20)
        $progressBar.Location = New-Object System.Drawing.Point(20, 250)
        $progressBar.Style = "Marquee"
        $progressBar.MarqueeAnimationSpeed = 50
        $splashForm.Controls.Add($progressBar)
        
        # Show splash screen
        $splashForm.Show()
        $splashForm.Refresh()
        
        # Keep splash screen visible for specified duration
        Start-Sleep -Milliseconds $Duration
        
        # Close splash screen
        $splashForm.Close()
        $splashForm.Dispose()
    }
    catch {
        # If splash screen fails, just continue silently
        # Don't show error to avoid disrupting the user experience
    }
}

# Global variables for GUI components
$script:MainForm = $null
$script:TabControl = $null
$script:FolderListBox = $null
$script:S3BucketComboBox = $null
$script:AWSProfileComboBox = $null
$script:RestoreDestinationTextBox = $null
$script:LogTextBox = $null
$script:ProgressBar = $null
$script:StatusLabel = $null
$script:OperationProgressBar = $null
$script:OperationStatusLabel = $null
$script:Config = $null
$script:BackgroundJob = $null

# Function to get Windows system icons
function Get-SystemIcon {
    param([string]$IconType, [int]$Width = 16, [int]$Height = 16)
    
    try {
        $icon = $null
        switch ($IconType) {
            "Settings"    { $icon = [System.Drawing.SystemIcons]::WinLogo }
            "Folder"      { $icon = [System.Drawing.SystemIcons]::MyComputer }
            "Backup"      { $icon = [System.Drawing.SystemIcons]::Shield }
            "Logs"        { $icon = [System.Drawing.SystemIcons]::Information }
            "Help"        { $icon = [System.Drawing.SystemIcons]::Question }
            "About"       { $icon = [System.Drawing.SystemIcons]::Information }
            "Restore"     { $icon = [System.Drawing.SystemIcons]::Shield }
            "Schedule"    { $icon = [System.Drawing.SystemIcons]::Exclamation }
            "Cloud"       { $icon = [System.Drawing.SystemIcons]::Application }
            default       { $icon = [System.Drawing.SystemIcons]::Application }
        }
        
        if ($icon) {
            # Convert icon to bitmap and resize if needed
            $bitmap = New-Object System.Drawing.Bitmap($icon.ToBitmap(), $Width, $Height)
            return $bitmap
        }
    }
    catch {
        Write-Log "Failed to load system icon $IconType : $_" -Level "WARNING"
    }
    return $null
}

# Function to create ImageList for tabs using system icons
function Create-TabImageList {
    $imageList = New-Object System.Windows.Forms.ImageList
    $imageList.ImageSize = New-Object System.Drawing.Size(16, 16)
    $imageList.ColorDepth = "Depth32Bit"
    
    # Add tab icons in order using system icons
    $iconTypes = @(
        "Settings",    # Configuration
        "Folder",      # Backup Folders  
        "Backup",      # Operations
        "Logs",        # Logs & Monitoring
        "Help",        # Help
        "About"        # About
    )
    
    foreach ($iconType in $iconTypes) {
        $icon = Get-SystemIcon $iconType 16 16
        if ($icon) {
            $imageList.Images.Add($icon)
        }
        else {
            # Add empty image as placeholder
            $emptyBitmap = New-Object System.Drawing.Bitmap(16, 16)
            $imageList.Images.Add($emptyBitmap)
        }
    }
    
    return $imageList
}

function Initialize-GUI {
    # Load configuration
    $script:Config = Load-Config
    
    # Main Form
    $script:MainForm = New-Object System.Windows.Forms.Form
    $script:MainForm.Text = "Enhanced Backup Manager v2.0"
    $script:MainForm.Size = New-Object System.Drawing.Size(900, 700)
    $script:MainForm.StartPosition = "CenterScreen"
    $script:MainForm.FormBorderStyle = "FixedSingle"
    $script:MainForm.MaximizeBox = $false
    
    # Set custom icon for the form
    try {
        $iconPath = Join-Path $PSScriptRoot "..\..\assets\icon.ico"
        if (Test-Path $iconPath) {
            $script:MainForm.Icon = New-Object System.Drawing.Icon($iconPath)
        }
        else {
            $script:MainForm.Icon = [System.Drawing.SystemIcons]::Application
        }
    }
    catch {
        $script:MainForm.Icon = [System.Drawing.SystemIcons]::Application
    }

    # Tab Control with icons
    $script:TabControl = New-Object System.Windows.Forms.TabControl
    $script:TabControl.Size = New-Object System.Drawing.Size(880, 580)
    $script:TabControl.Location = New-Object System.Drawing.Point(10, 10)
    
    # Create and assign ImageList for tab icons
    $tabImageList = Create-TabImageList
    $script:TabControl.ImageList = $tabImageList

    # Configuration Tab
    $configTab = New-Object System.Windows.Forms.TabPage
    $configTab.Text = "Configuration"
    $configTab.ImageIndex = 0
    Create-ConfigurationTab $configTab

    # Folders Tab
    $foldersTab = New-Object System.Windows.Forms.TabPage
    $foldersTab.Text = "Backup Folders"
    $foldersTab.ImageIndex = 1
    Create-FoldersTab $foldersTab

    # Operations Tab
    $operationsTab = New-Object System.Windows.Forms.TabPage
    $operationsTab.Text = "Operations"
    $operationsTab.ImageIndex = 2
    Create-OperationsTab $operationsTab

    # Logs Tab
    $logsTab = New-Object System.Windows.Forms.TabPage
    $logsTab.Text = "Logs & Monitoring"
    $logsTab.ImageIndex = 3
    Create-LogsTab $logsTab

    # Help Tab
    $helpTab = New-Object System.Windows.Forms.TabPage
    $helpTab.Text = "Help"
    $helpTab.ImageIndex = 4
    Create-HelpTab $helpTab

    # About Tab
    $aboutTab = New-Object System.Windows.Forms.TabPage
    $aboutTab.Text = "About"
    $aboutTab.ImageIndex = 5
    Create-AboutTab $aboutTab

    # Add tabs to control
    $script:TabControl.TabPages.Add($configTab)
    $script:TabControl.TabPages.Add($foldersTab)
    $script:TabControl.TabPages.Add($operationsTab)
    $script:TabControl.TabPages.Add($logsTab)
    $script:TabControl.TabPages.Add($helpTab)
    $script:TabControl.TabPages.Add($aboutTab)

    # Status Bar
    $script:StatusLabel = New-Object System.Windows.Forms.Label
    $script:StatusLabel.Text = "Ready - Enhanced Backup Manager"
    $script:StatusLabel.Location = New-Object System.Drawing.Point(10, 600)
    $script:StatusLabel.Size = New-Object System.Drawing.Size(600, 20)
    $script:StatusLabel.BorderStyle = "Fixed3D"

    # Progress Bar
    $script:ProgressBar = New-Object System.Windows.Forms.ProgressBar
    $script:ProgressBar.Location = New-Object System.Drawing.Point(620, 600)
    $script:ProgressBar.Size = New-Object System.Drawing.Size(250, 20)
    $script:ProgressBar.Style = "Continuous"

    # Add controls to form
    $script:MainForm.Controls.Add($script:TabControl)
    $script:MainForm.Controls.Add($script:StatusLabel)
    $script:MainForm.Controls.Add($script:ProgressBar)
    
    # Load initial configuration
    Load-Configuration
}

function Create-ConfigurationTab($tab) {
    # Backup Type Selection Group
    $backupTypeGroup = New-Object System.Windows.Forms.GroupBox
    $backupTypeGroup.Text = "Backup Destination Type"
    $backupTypeGroup.Location = New-Object System.Drawing.Point(20, 20)
    $backupTypeGroup.Size = New-Object System.Drawing.Size(820, 80)
    $backupTypeGroup.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9, [System.Drawing.FontStyle]::Bold)

    # Backup Type Radio Buttons
    $script:LocalRadioButton = New-Object System.Windows.Forms.RadioButton
    $script:LocalRadioButton.Text = "Local/USB Drive/Network Share"
    $script:LocalRadioButton.Location = New-Object System.Drawing.Point(20, 25)
    $script:LocalRadioButton.Size = New-Object System.Drawing.Size(250, 20)
    $script:LocalRadioButton.Checked = $true
    $script:LocalRadioButton.Add_CheckedChanged({ Update-ConfigurationVisibility })

    $script:NetworkRadioButton = New-Object System.Windows.Forms.RadioButton
    $script:NetworkRadioButton.Text = "Network Location (UNC Path)"
    $script:NetworkRadioButton.Location = New-Object System.Drawing.Point(280, 25)
    $script:NetworkRadioButton.Size = New-Object System.Drawing.Size(200, 20)
    $script:NetworkRadioButton.Add_CheckedChanged({ Update-ConfigurationVisibility })

    $script:S3RadioButton = New-Object System.Windows.Forms.RadioButton
    $script:S3RadioButton.Text = "AWS S3 Cloud Storage"
    $script:S3RadioButton.Location = New-Object System.Drawing.Point(490, 25)
    $script:S3RadioButton.Size = New-Object System.Drawing.Size(180, 20)
    $script:S3RadioButton.Add_CheckedChanged({ Update-ConfigurationVisibility })

    $backupTypeGroup.Controls.AddRange(@($script:LocalRadioButton, $script:NetworkRadioButton, $script:S3RadioButton))

    # Local/Network Configuration Group
    $localGroup = New-Object System.Windows.Forms.GroupBox
    $localGroup.Text = "Local/Network Backup Configuration"
    $localGroup.Location = New-Object System.Drawing.Point(20, 120)
    $localGroup.Size = New-Object System.Drawing.Size(820, 120)
    $localGroup.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9, [System.Drawing.FontStyle]::Bold)
    $script:LocalConfigGroup = $localGroup

    # Backup Destination
    $backupDestLabel = New-Object System.Windows.Forms.Label
    $backupDestLabel.Text = "Backup Destination:"
    $backupDestLabel.Location = New-Object System.Drawing.Point(20, 35)
    $backupDestLabel.Size = New-Object System.Drawing.Size(120, 20)
    $backupDestLabel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9)

    $script:BackupDestinationTextBox = New-Object System.Windows.Forms.TextBox
    $script:BackupDestinationTextBox.Location = New-Object System.Drawing.Point(150, 35)
    $script:BackupDestinationTextBox.Size = New-Object System.Drawing.Size(400, 25)

    $browseBackupButton = New-Object System.Windows.Forms.Button
    $browseBackupButton.Text = "Browse..."
    $browseBackupButton.Location = New-Object System.Drawing.Point(560, 35)
    $browseBackupButton.Size = New-Object System.Drawing.Size(80, 25)
    $browseBackupButton.Add_Click({ Browse-ForBackupDestination })

    # Test Backup Destination Button
    $testBackupButton = New-Object System.Windows.Forms.Button
    $testBackupButton.Text = "Test Backup Destination"
    $testBackupButton.Location = New-Object System.Drawing.Point(20, 75)
    $testBackupButton.Size = New-Object System.Drawing.Size(180, 30)
    $testBackupButton.BackColor = [System.Drawing.Color]::LightBlue
    $testBackupButton.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9, [System.Drawing.FontStyle]::Bold)
    $testBackupButton.Add_Click({ Test-BackupDestination })

    # Backup Destination Status
    $backupStatusLabel = New-Object System.Windows.Forms.Label
    $backupStatusLabel.Text = "Destination Status: Not Tested"
    $backupStatusLabel.Location = New-Object System.Drawing.Point(210, 82)
    $backupStatusLabel.Size = New-Object System.Drawing.Size(300, 20)
    $backupStatusLabel.ForeColor = [System.Drawing.Color]::Gray
    $script:BackupStatusLabel = $backupStatusLabel

    $localGroup.Controls.AddRange(@($backupDestLabel, $script:BackupDestinationTextBox, $browseBackupButton, 
                                   $testBackupButton, $backupStatusLabel))

    # AWS Configuration Group (initially hidden)
    $awsGroup = New-Object System.Windows.Forms.GroupBox
    $awsGroup.Text = "AWS S3 Configuration"
    $awsGroup.Location = New-Object System.Drawing.Point(20, 120)
    $awsGroup.Size = New-Object System.Drawing.Size(820, 180)
    $awsGroup.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9, [System.Drawing.FontStyle]::Bold)
    $awsGroup.Visible = $false
    $script:AWSConfigGroup = $awsGroup

    # S3 Bucket
    $s3Label = New-Object System.Windows.Forms.Label
    $s3Label.Text = "S3 Bucket:"
    $s3Label.Location = New-Object System.Drawing.Point(20, 35)
    $s3Label.Size = New-Object System.Drawing.Size(120, 20)
    $s3Label.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9)

    $script:S3BucketComboBox = New-Object System.Windows.Forms.ComboBox
    $script:S3BucketComboBox.Location = New-Object System.Drawing.Point(150, 35)
    $script:S3BucketComboBox.Size = New-Object System.Drawing.Size(300, 25)
    $script:S3BucketComboBox.DropDownStyle = "DropDown"
    $script:S3BucketComboBox.Items.AddRange(@("gpahpbackup", "my-backup-bucket", "company-backups", "personal-backup"))

    $refreshBucketsButton = New-Object System.Windows.Forms.Button
    $refreshBucketsButton.Text = "Refresh Buckets"
    $refreshBucketsButton.Location = New-Object System.Drawing.Point(460, 35)
    $refreshBucketsButton.Size = New-Object System.Drawing.Size(120, 25)
    $refreshBucketsButton.Add_Click({ Refresh-S3Buckets })

    # AWS Profile
    $profileLabel = New-Object System.Windows.Forms.Label
    $profileLabel.Text = "AWS Profile:"
    $profileLabel.Location = New-Object System.Drawing.Point(20, 75)
    $profileLabel.Size = New-Object System.Drawing.Size(120, 20)
    $profileLabel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9)

    $script:AWSProfileComboBox = New-Object System.Windows.Forms.ComboBox
    $script:AWSProfileComboBox.Location = New-Object System.Drawing.Point(150, 75)
    $script:AWSProfileComboBox.Size = New-Object System.Drawing.Size(300, 25)
    $script:AWSProfileComboBox.DropDownStyle = "DropDown"
    $script:AWSProfileComboBox.Items.AddRange(@("default", "backup", "production", "development"))

    $refreshProfilesButton = New-Object System.Windows.Forms.Button
    $refreshProfilesButton.Text = "Refresh Profiles"
    $refreshProfilesButton.Location = New-Object System.Drawing.Point(460, 75)
    $refreshProfilesButton.Size = New-Object System.Drawing.Size(120, 25)
    $refreshProfilesButton.Add_Click({ Refresh-AWSProfiles })

    # Test AWS Connection Button
    $testAWSButton = New-Object System.Windows.Forms.Button
    $testAWSButton.Text = "Test AWS Connection"
    $testAWSButton.Location = New-Object System.Drawing.Point(20, 120)
    $testAWSButton.Size = New-Object System.Drawing.Size(150, 35)
    $testAWSButton.BackColor = [System.Drawing.Color]::LightBlue
    $testAWSButton.Add_Click({ Test-AWSConnection })

    # AWS Connection Status
    $awsConnectionStatusLabel = New-Object System.Windows.Forms.Label
    $awsConnectionStatusLabel.Text = "Connection Status: Not Tested"
    $awsConnectionStatusLabel.Location = New-Object System.Drawing.Point(180, 130)
    $awsConnectionStatusLabel.Size = New-Object System.Drawing.Size(300, 20)
    $awsConnectionStatusLabel.ForeColor = [System.Drawing.Color]::Gray
    $script:AWSConnectionStatusLabel = $awsConnectionStatusLabel

    $awsGroup.Controls.AddRange(@($s3Label, $script:S3BucketComboBox, $refreshBucketsButton, 
                                 $profileLabel, $script:AWSProfileComboBox, $refreshProfilesButton, 
                                 $testAWSButton, $awsConnectionStatusLabel))

    # Restore Configuration Group
    $restoreGroup = New-Object System.Windows.Forms.GroupBox
    $restoreGroup.Text = "Restore Configuration"
    $restoreGroup.Location = New-Object System.Drawing.Point(20, 320)
    $restoreGroup.Size = New-Object System.Drawing.Size(820, 80)
    $restoreGroup.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9, [System.Drawing.FontStyle]::Bold)

    # Restore Destination
    $restoreLabel = New-Object System.Windows.Forms.Label
    $restoreLabel.Text = "Restore Destination:"
    $restoreLabel.Location = New-Object System.Drawing.Point(20, 35)
    $restoreLabel.Size = New-Object System.Drawing.Size(120, 20)
    $restoreLabel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9)

    $script:RestoreDestinationTextBox = New-Object System.Windows.Forms.TextBox
    $script:RestoreDestinationTextBox.Location = New-Object System.Drawing.Point(150, 35)
    $script:RestoreDestinationTextBox.Size = New-Object System.Drawing.Size(400, 25)

    $browseRestoreButton = New-Object System.Windows.Forms.Button
    $browseRestoreButton.Text = "Browse..."
    $browseRestoreButton.Location = New-Object System.Drawing.Point(560, 35)
    $browseRestoreButton.Size = New-Object System.Drawing.Size(80, 25)
    $browseRestoreButton.Add_Click({ Browse-ForRestoreDestination })

    $restoreGroup.Controls.AddRange(@($restoreLabel, $script:RestoreDestinationTextBox, $browseRestoreButton))

    # Save Configuration Button (moved to bottom)
    $saveButton = New-Object System.Windows.Forms.Button
    $saveButton.Text = "Save Configuration"
    $saveButton.Location = New-Object System.Drawing.Point(280, 420)
    $saveButton.Size = New-Object System.Drawing.Size(150, 40)
    $saveButton.BackColor = [System.Drawing.Color]::LightGreen
    $saveButton.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 10, [System.Drawing.FontStyle]::Bold)
    $saveButton.Add_Click({ Save-Configuration })

    # Clear Configuration Button
    $clearButton = New-Object System.Windows.Forms.Button
    $clearButton.Text = "Clear Configuration"
    $clearButton.Location = New-Object System.Drawing.Point(450, 420)
    $clearButton.Size = New-Object System.Drawing.Size(150, 40)
    $clearButton.BackColor = [System.Drawing.Color]::LightCoral
    $clearButton.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 10, [System.Drawing.FontStyle]::Bold)
    $clearButton.Add_Click({ Clear-Configuration })

    # Add all groups to tab
    $tab.Controls.AddRange(@($backupTypeGroup, $localGroup, $awsGroup, $restoreGroup, $saveButton, $clearButton))
}

function Create-FoldersTab($tab) {
    # Folder selection list
    $foldersLabel = New-Object System.Windows.Forms.Label
    $foldersLabel.Text = "Select folders to backup:"
    $foldersLabel.Location = New-Object System.Drawing.Point(20, 20)
    $foldersLabel.Size = New-Object System.Drawing.Size(200, 20)
    $foldersLabel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 10, [System.Drawing.FontStyle]::Bold)

    $script:FolderListBox = New-Object System.Windows.Forms.CheckedListBox
    $script:FolderListBox.Location = New-Object System.Drawing.Point(20, 50)
    $script:FolderListBox.Size = New-Object System.Drawing.Size(600, 400)
    $script:FolderListBox.CheckOnClick = $true
    $script:FolderListBox.Font = New-Object System.Drawing.Font("Consolas", 9)

    # Button Panel
    $buttonPanel = New-Object System.Windows.Forms.Panel
    $buttonPanel.Location = New-Object System.Drawing.Point(640, 50)
    $buttonPanel.Size = New-Object System.Drawing.Size(200, 400)
    $buttonPanel.BorderStyle = "FixedSingle"

    # Add Folder Button
    $addFolderButton = New-Object System.Windows.Forms.Button
    $addFolderButton.Text = "Add Custom Folder"
    $addFolderButton.Location = New-Object System.Drawing.Point(10, 20)
    $addFolderButton.Size = New-Object System.Drawing.Size(180, 35)
    $addFolderButton.BackColor = [System.Drawing.Color]::LightBlue
    $addFolderButton.Add_Click({ Add-CustomFolder })

    # Remove Folder Button
    $removeFolderButton = New-Object System.Windows.Forms.Button
    $removeFolderButton.Text = "Remove Selected"
    $removeFolderButton.Location = New-Object System.Drawing.Point(10, 70)
    $removeFolderButton.Size = New-Object System.Drawing.Size(180, 35)
    $removeFolderButton.BackColor = [System.Drawing.Color]::LightCoral
    $removeFolderButton.Add_Click({ Remove-SelectedFolder })

    # Refresh Folders Button
    $refreshButton = New-Object System.Windows.Forms.Button
    $refreshButton.Text = "Refresh List"
    $refreshButton.Location = New-Object System.Drawing.Point(10, 120)
    $refreshButton.Size = New-Object System.Drawing.Size(180, 35)
    $refreshButton.Add_Click({ Refresh-FolderList })

    # Check All Button
    $checkAllButton = New-Object System.Windows.Forms.Button
    $checkAllButton.Text = "Check All"
    $checkAllButton.Location = New-Object System.Drawing.Point(10, 170)
    $checkAllButton.Size = New-Object System.Drawing.Size(85, 30)
    $checkAllButton.Add_Click({ Check-AllFolders })

    # Uncheck All Button
    $uncheckAllButton = New-Object System.Windows.Forms.Button
    $uncheckAllButton.Text = "Uncheck All"
    $uncheckAllButton.Location = New-Object System.Drawing.Point(105, 170)
    $uncheckAllButton.Size = New-Object System.Drawing.Size(85, 30)
    $uncheckAllButton.Add_Click({ Uncheck-AllFolders })

    $buttonPanel.Controls.AddRange(@($addFolderButton, $removeFolderButton, $refreshButton, $checkAllButton, $uncheckAllButton))

    $tab.Controls.AddRange(@($foldersLabel, $script:FolderListBox, $buttonPanel))
}

function Create-OperationsTab($tab) {
    # Operation Progress Group (made much larger)
    $progressGroup = New-Object System.Windows.Forms.GroupBox
    $progressGroup.Text = "Operation Progress & Monitoring"
    $progressGroup.Location = New-Object System.Drawing.Point(20, 20)
    $progressGroup.Size = New-Object System.Drawing.Size(820, 200)
    $progressGroup.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9, [System.Drawing.FontStyle]::Bold)

    # Operation Status Label (larger and more visible)
    $script:OperationStatusLabel = New-Object System.Windows.Forms.Label
    $script:OperationStatusLabel.Text = "No operation in progress"
    $script:OperationStatusLabel.Location = New-Object System.Drawing.Point(20, 30)
    $script:OperationStatusLabel.Size = New-Object System.Drawing.Size(780, 25)
    $script:OperationStatusLabel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 10, [System.Drawing.FontStyle]::Bold)
    $script:OperationStatusLabel.ForeColor = [System.Drawing.Color]::DarkBlue

    # Current File Label (shows which file is being processed)
    $script:CurrentFileLabel = New-Object System.Windows.Forms.Label
    $script:CurrentFileLabel.Text = "Ready to start operation..."
    $script:CurrentFileLabel.Location = New-Object System.Drawing.Point(20, 60)
    $script:CurrentFileLabel.Size = New-Object System.Drawing.Size(780, 20)
    $script:CurrentFileLabel.Font = New-Object System.Drawing.Font("Consolas", 9)
    $script:CurrentFileLabel.ForeColor = [System.Drawing.Color]::DarkGreen

    # Operation Progress Bar (larger and more prominent)
    $script:OperationProgressBar = New-Object System.Windows.Forms.ProgressBar
    $script:OperationProgressBar.Location = New-Object System.Drawing.Point(20, 90)
    $script:OperationProgressBar.Size = New-Object System.Drawing.Size(780, 30)
    $script:OperationProgressBar.Style = "Continuous"
    $script:OperationProgressBar.Minimum = 0
    $script:OperationProgressBar.Maximum = 100
    $script:OperationProgressBar.Value = 0

    # Progress Statistics Panel
    $statsPanel = New-Object System.Windows.Forms.Panel
    $statsPanel.Location = New-Object System.Drawing.Point(20, 130)
    $statsPanel.Size = New-Object System.Drawing.Size(780, 35)
    $statsPanel.BorderStyle = "FixedSingle"

    # Files Processed Label
    $script:FilesProcessedLabel = New-Object System.Windows.Forms.Label
    $script:FilesProcessedLabel.Text = "Files: 0 processed"
    $script:FilesProcessedLabel.Location = New-Object System.Drawing.Point(10, 8)
    $script:FilesProcessedLabel.Size = New-Object System.Drawing.Size(150, 20)
    $script:FilesProcessedLabel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9)

    # Speed Label
    $script:SpeedLabel = New-Object System.Windows.Forms.Label
    $script:SpeedLabel.Text = "Speed: -- MB/s"
    $script:SpeedLabel.Location = New-Object System.Drawing.Point(170, 8)
    $script:SpeedLabel.Size = New-Object System.Drawing.Size(120, 20)
    $script:SpeedLabel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9)

    # Time Elapsed Label
    $script:TimeElapsedLabel = New-Object System.Windows.Forms.Label
    $script:TimeElapsedLabel.Text = "Elapsed: 00:00:00"
    $script:TimeElapsedLabel.Location = New-Object System.Drawing.Point(300, 8)
    $script:TimeElapsedLabel.Size = New-Object System.Drawing.Size(120, 20)
    $script:TimeElapsedLabel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9)

    # ETA Label
    $script:ETALabel = New-Object System.Windows.Forms.Label
    $script:ETALabel.Text = "ETA: Calculating..."
    $script:ETALabel.Location = New-Object System.Drawing.Point(430, 8)
    $script:ETALabel.Size = New-Object System.Drawing.Size(120, 20)
    $script:ETALabel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9)

    # Cancel Operation Button (larger and more prominent)
    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = "Cancel Operation"
    $cancelButton.Location = New-Object System.Drawing.Point(600, 5)
    $cancelButton.Size = New-Object System.Drawing.Size(150, 30)
    $cancelButton.BackColor = [System.Drawing.Color]::LightCoral
    $cancelButton.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9, [System.Drawing.FontStyle]::Bold)
    $cancelButton.Enabled = $false
    $script:CancelButton = $cancelButton
    $cancelButton.Add_Click({ Cancel-Operation })

    $statsPanel.Controls.AddRange(@($script:FilesProcessedLabel, $script:SpeedLabel, $script:TimeElapsedLabel, $script:ETALabel, $cancelButton))

    $progressGroup.Controls.AddRange(@($script:OperationStatusLabel, $script:CurrentFileLabel, $script:OperationProgressBar, $statsPanel))

    # Backup Section (moved down and made smaller)
    $backupGroup = New-Object System.Windows.Forms.GroupBox
    $backupGroup.Text = "Backup Operations"
    $backupGroup.Location = New-Object System.Drawing.Point(20, 240)
    $backupGroup.Size = New-Object System.Drawing.Size(400, 150)
    $backupGroup.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9, [System.Drawing.FontStyle]::Bold)

    $backupButton = New-Object System.Windows.Forms.Button
    $backupButton.Text = "  Start Backup"
    $backupButton.Location = New-Object System.Drawing.Point(20, 30)
    $backupButton.Size = New-Object System.Drawing.Size(150, 40)
    $backupButton.BackColor = [System.Drawing.Color]::LightGreen
    $backupButton.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9, [System.Drawing.FontStyle]::Bold)
    $backupButton.TextAlign = "MiddleRight"
    $backupButton.ImageAlign = "MiddleLeft"
    $backupIcon = Get-SystemIcon "Backup" 24 24
    if ($backupIcon) { $backupButton.Image = $backupIcon }
    $backupButton.Add_Click({ Start-Backup })

    $dryRunButton = New-Object System.Windows.Forms.Button
    $dryRunButton.Text = "  Dry Run Backup"
    $dryRunButton.Location = New-Object System.Drawing.Point(200, 30)
    $dryRunButton.Size = New-Object System.Drawing.Size(150, 40)
    $dryRunButton.BackColor = [System.Drawing.Color]::LightYellow
    $dryRunButton.TextAlign = "MiddleRight"
    $dryRunButton.ImageAlign = "MiddleLeft"
    $dryRunIcon = Get-SystemIcon "Backup" 20 20
    if ($dryRunIcon) { $dryRunButton.Image = $dryRunIcon }
    $dryRunButton.Add_Click({ Start-DryRunBackup })

    $scheduleButton = New-Object System.Windows.Forms.Button
    $scheduleButton.Text = "  Configure Schedule"
    $scheduleButton.Location = New-Object System.Drawing.Point(20, 90)
    $scheduleButton.Size = New-Object System.Drawing.Size(330, 35)
    $scheduleButton.BackColor = [System.Drawing.Color]::LightBlue
    $scheduleButton.TextAlign = "MiddleRight"
    $scheduleButton.ImageAlign = "MiddleLeft"
    $scheduleIcon = Get-SystemIcon "Schedule" 20 20
    if ($scheduleIcon) { $scheduleButton.Image = $scheduleIcon }
    $scheduleButton.Add_Click({ Configure-Schedule })

    $backupGroup.Controls.AddRange(@($backupButton, $dryRunButton, $scheduleButton))

    # Restore Section (moved down and made smaller)
    $restoreGroup = New-Object System.Windows.Forms.GroupBox
    $restoreGroup.Text = "Restore Operations"
    $restoreGroup.Location = New-Object System.Drawing.Point(440, 240)
    $restoreGroup.Size = New-Object System.Drawing.Size(400, 150)
    $restoreGroup.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9, [System.Drawing.FontStyle]::Bold)

    $restoreButton = New-Object System.Windows.Forms.Button
    $restoreButton.Text = "  Start Restore"
    $restoreButton.Location = New-Object System.Drawing.Point(20, 30)
    $restoreButton.Size = New-Object System.Drawing.Size(150, 40)
    $restoreButton.BackColor = [System.Drawing.Color]::LightGreen
    $restoreButton.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9, [System.Drawing.FontStyle]::Bold)
    $restoreButton.TextAlign = "MiddleRight"
    $restoreButton.ImageAlign = "MiddleLeft"
    $restoreIcon = Get-SystemIcon "Restore" 24 24
    if ($restoreIcon) { $restoreButton.Image = $restoreIcon }
    $restoreButton.Add_Click({ Start-Restore })

    $dryRunRestoreButton = New-Object System.Windows.Forms.Button
    $dryRunRestoreButton.Text = "  Dry Run Restore"
    $dryRunRestoreButton.Location = New-Object System.Drawing.Point(200, 30)
    $dryRunRestoreButton.Size = New-Object System.Drawing.Size(150, 40)
    $dryRunRestoreButton.BackColor = [System.Drawing.Color]::LightYellow
    $dryRunRestoreButton.TextAlign = "MiddleRight"
    $dryRunRestoreButton.ImageAlign = "MiddleLeft"
    $dryRunRestoreIcon = Get-SystemIcon "Restore" 20 20
    if ($dryRunRestoreIcon) { $dryRunRestoreButton.Image = $dryRunRestoreIcon }
    $dryRunRestoreButton.Add_Click({ Start-DryRunRestore })

    $restoreGroup.Controls.AddRange(@($restoreButton, $dryRunRestoreButton))

    $tab.Controls.AddRange(@($progressGroup, $backupGroup, $restoreGroup))
}

function Create-LogsTab($tab) {
    # Log Display
    $script:LogTextBox = New-Object System.Windows.Forms.RichTextBox
    $script:LogTextBox.Location = New-Object System.Drawing.Point(10, 70)
    $script:LogTextBox.Size = New-Object System.Drawing.Size(850, 420)
    $script:LogTextBox.ReadOnly = $true
    $script:LogTextBox.Font = New-Object System.Drawing.Font("Consolas", 9)
    $script:LogTextBox.BackColor = [System.Drawing.Color]::Black
    $script:LogTextBox.ForeColor = [System.Drawing.Color]::LimeGreen

    # Log Control Panel (made taller for verbosity controls)
    $logControlPanel = New-Object System.Windows.Forms.Panel
    $logControlPanel.Location = New-Object System.Drawing.Point(10, 10)
    $logControlPanel.Size = New-Object System.Drawing.Size(850, 60)
    $logControlPanel.BorderStyle = "FixedSingle"

    # First row of controls
    $refreshLogsButton = New-Object System.Windows.Forms.Button
    $refreshLogsButton.Text = "Refresh Logs"
    $refreshLogsButton.Location = New-Object System.Drawing.Point(10, 5)
    $refreshLogsButton.Size = New-Object System.Drawing.Size(100, 25)
    $refreshLogsButton.Add_Click({ Refresh-Logs })

    $clearLogsButton = New-Object System.Windows.Forms.Button
    $clearLogsButton.Text = "Clear Logs"
    $clearLogsButton.Location = New-Object System.Drawing.Point(120, 5)
    $clearLogsButton.Size = New-Object System.Drawing.Size(100, 25)
    $clearLogsButton.Add_Click({ Clear-Logs })

    $autoRefreshCheckBox = New-Object System.Windows.Forms.CheckBox
    $autoRefreshCheckBox.Text = "Auto-refresh logs"
    $autoRefreshCheckBox.Location = New-Object System.Drawing.Point(230, 8)
    $autoRefreshCheckBox.Size = New-Object System.Drawing.Size(150, 20)
    $autoRefreshCheckBox.Checked = $true
    $script:AutoRefreshCheckBox = $autoRefreshCheckBox

    # Second row - Verbosity controls
    $verbosityLabel = New-Object System.Windows.Forms.Label
    $verbosityLabel.Text = "Log Level:"
    $verbosityLabel.Location = New-Object System.Drawing.Point(10, 35)
    $verbosityLabel.Size = New-Object System.Drawing.Size(70, 20)
    $verbosityLabel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9, [System.Drawing.FontStyle]::Bold)

    $script:VerbosityComboBox = New-Object System.Windows.Forms.ComboBox
    $script:VerbosityComboBox.Location = New-Object System.Drawing.Point(85, 33)
    $script:VerbosityComboBox.Size = New-Object System.Drawing.Size(100, 25)
    $script:VerbosityComboBox.DropDownStyle = "DropDownList"
    $script:VerbosityComboBox.Items.AddRange(@("ERROR", "WARNING", "INFO", "SUCCESS", "ALL"))
    $script:VerbosityComboBox.SelectedItem = "ALL"
    $script:VerbosityComboBox.Add_SelectedIndexChanged({ Refresh-Logs })

    $maxLinesLabel = New-Object System.Windows.Forms.Label
    $maxLinesLabel.Text = "Max Lines:"
    $maxLinesLabel.Location = New-Object System.Drawing.Point(200, 35)
    $maxLinesLabel.Size = New-Object System.Drawing.Size(70, 20)
    $maxLinesLabel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9)

    $script:MaxLinesComboBox = New-Object System.Windows.Forms.ComboBox
    $script:MaxLinesComboBox.Location = New-Object System.Drawing.Point(275, 33)
    $script:MaxLinesComboBox.Size = New-Object System.Drawing.Size(80, 25)
    $script:MaxLinesComboBox.DropDownStyle = "DropDownList"
    $script:MaxLinesComboBox.Items.AddRange(@("50", "100", "200", "500", "1000"))
    $script:MaxLinesComboBox.SelectedItem = "100"
    $script:MaxLinesComboBox.Add_SelectedIndexChanged({ Refresh-Logs })

    $scrollToBottomCheckBox = New-Object System.Windows.Forms.CheckBox
    $scrollToBottomCheckBox.Text = "Auto-scroll to bottom"
    $scrollToBottomCheckBox.Location = New-Object System.Drawing.Point(370, 35)
    $scrollToBottomCheckBox.Size = New-Object System.Drawing.Size(150, 20)
    $scrollToBottomCheckBox.Checked = $true
    $script:ScrollToBottomCheckBox = $scrollToBottomCheckBox

    $logControlPanel.Controls.AddRange(@($refreshLogsButton, $clearLogsButton, $autoRefreshCheckBox, 
                                       $verbosityLabel, $script:VerbosityComboBox, $maxLinesLabel, 
                                       $script:MaxLinesComboBox, $scrollToBottomCheckBox))

    # Statistics Panel (moved down to accommodate larger control panel)
    $statsPanel = New-Object System.Windows.Forms.Panel
    $statsPanel.Location = New-Object System.Drawing.Point(10, 500)
    $statsPanel.Size = New-Object System.Drawing.Size(850, 50)
    $statsPanel.BorderStyle = "FixedSingle"

    $statsLabel = New-Object System.Windows.Forms.Label
    $statsLabel.Text = "Statistics: No operations completed yet"
    $statsLabel.Location = New-Object System.Drawing.Point(10, 15)
    $statsLabel.Size = New-Object System.Drawing.Size(800, 20)
    $script:StatsLabel = $statsLabel

    $statsPanel.Controls.Add($statsLabel)

    $tab.Controls.AddRange(@($logControlPanel, $script:LogTextBox, $statsPanel))
}

function Create-HelpTab($tab) {
    # Help Content Panel
    $helpPanel = New-Object System.Windows.Forms.Panel
    $helpPanel.Location = New-Object System.Drawing.Point(10, 10)
    $helpPanel.Size = New-Object System.Drawing.Size(860, 540)
    $helpPanel.AutoScroll = $true

    # Help Title
    $helpTitle = New-Object System.Windows.Forms.Label
    $helpTitle.Text = "Enhanced Backup Manager - Help & User Guide"
    $helpTitle.Location = New-Object System.Drawing.Point(20, 20)
    $helpTitle.Size = New-Object System.Drawing.Size(800, 30)
    $helpTitle.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 14, [System.Drawing.FontStyle]::Bold)
    $helpTitle.ForeColor = [System.Drawing.Color]::DarkBlue

    # Quick Start Section
    $quickStartLabel = New-Object System.Windows.Forms.Label
    $quickStartLabel.Text = "QUICK START GUIDE"
    $quickStartLabel.Location = New-Object System.Drawing.Point(20, 70)
    $quickStartLabel.Size = New-Object System.Drawing.Size(800, 25)
    $quickStartLabel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 12, [System.Drawing.FontStyle]::Bold)
    $quickStartLabel.ForeColor = [System.Drawing.Color]::DarkGreen

    $quickStartText = New-Object System.Windows.Forms.TextBox
    $quickStartText.Multiline = $true
    $quickStartText.ReadOnly = $true
    $quickStartText.ScrollBars = "Vertical"
    $quickStartText.Location = New-Object System.Drawing.Point(20, 100)
    $quickStartText.Size = New-Object System.Drawing.Size(800, 120)
    $quickStartText.Font = New-Object System.Drawing.Font("Consolas", 9)
    $quickStartText.Text = @"
1. Configuration Tab: Set up your AWS credentials and S3 bucket
   * Select or enter your S3 bucket name
   * Choose your AWS profile
   * Test the connection to ensure everything works
   * Set your restore destination path

2. Backup Folders Tab: Choose which folders to backup
   * Check/uncheck folders you want to backup
   * Add custom folders using 'Add Custom Folder'
   * Use 'Check All' or 'Uncheck All' for quick selection

3. Operations Tab: Run backup and restore operations
   * Use 'Dry Run' first to test without actual file transfer
   * Monitor progress in real-time
   * Cancel operations if needed
"@

    # Configuration Help Section
    $configHelpLabel = New-Object System.Windows.Forms.Label
    $configHelpLabel.Text = "CONFIGURATION HELP"
    $configHelpLabel.Location = New-Object System.Drawing.Point(20, 240)
    $configHelpLabel.Size = New-Object System.Drawing.Size(800, 25)
    $configHelpLabel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 12, [System.Drawing.FontStyle]::Bold)
    $configHelpLabel.ForeColor = [System.Drawing.Color]::DarkGreen

    $configHelpText = New-Object System.Windows.Forms.TextBox
    $configHelpText.Multiline = $true
    $configHelpText.ReadOnly = $true
    $configHelpText.ScrollBars = "Vertical"
    $configHelpText.Location = New-Object System.Drawing.Point(20, 270)
    $configHelpText.Size = New-Object System.Drawing.Size(800, 100)
    $configHelpText.Font = New-Object System.Drawing.Font("Consolas", 9)
    $configHelpText.Text = @"
AWS Setup Requirements:
* Install AWS CLI: https://aws.amazon.com/cli/
* Configure credentials: Run 'aws configure' in command prompt
* Create S3 bucket or use existing one
* Ensure your AWS user has S3 read/write permissions

Troubleshooting:
* If 'Test AWS Connection' fails, check your AWS credentials
* Use 'Refresh Buckets' to load your actual S3 buckets
* Use 'Refresh Profiles' to load your AWS profiles from ~/.aws/config
"@

    # Operations Help Section
    $opsHelpLabel = New-Object System.Windows.Forms.Label
    $opsHelpLabel.Text = "OPERATIONS HELP"
    $opsHelpLabel.Location = New-Object System.Drawing.Point(20, 390)
    $opsHelpLabel.Size = New-Object System.Drawing.Size(800, 25)
    $opsHelpLabel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 12, [System.Drawing.FontStyle]::Bold)
    $opsHelpLabel.ForeColor = [System.Drawing.Color]::DarkGreen

    $opsHelpText = New-Object System.Windows.Forms.TextBox
    $opsHelpText.Multiline = $true
    $opsHelpText.ReadOnly = $true
    $opsHelpText.ScrollBars = "Vertical"
    $opsHelpText.Location = New-Object System.Drawing.Point(20, 420)
    $opsHelpText.Size = New-Object System.Drawing.Size(800, 100)
    $opsHelpText.Font = New-Object System.Drawing.Font("Consolas", 9)
    $opsHelpText.Text = @"
Backup Operations:
* 'Start Backup': Performs actual backup to S3
* 'Dry Run Backup': Shows what would be backed up without transferring files
* Progress is shown in real-time with status updates

Restore Operations:
* 'Start Restore': Downloads files from S3 to restore destination
* 'Dry Run Restore': Shows what would be restored without downloading
* Files are restored to the path specified in Configuration tab

Scheduling:
* Use 'Configure Schedule' to set up automated backups
* Integrates with Windows Task Scheduler
* Can schedule daily, weekly, or monthly backups
"@

    $helpPanel.Controls.AddRange(@($helpTitle, $quickStartLabel, $quickStartText, 
                                  $configHelpLabel, $configHelpText, $opsHelpLabel, $opsHelpText))

    $tab.Controls.Add($helpPanel)
}

function Create-AboutTab($tab) {
    # About Content Panel
    $aboutPanel = New-Object System.Windows.Forms.Panel
    $aboutPanel.Location = New-Object System.Drawing.Point(10, 10)
    $aboutPanel.Size = New-Object System.Drawing.Size(860, 540)
    $aboutPanel.BackColor = [System.Drawing.Color]::WhiteSmoke

    # Logo/Icon Area with actual image
    $logoPictureBox = New-Object System.Windows.Forms.PictureBox
    $logoPictureBox.Location = New-Object System.Drawing.Point(380, 30)
    $logoPictureBox.Size = New-Object System.Drawing.Size(100, 60)
    $logoPictureBox.SizeMode = "Zoom"
    $logoPictureBox.BorderStyle = "FixedSingle"
    
    # Try to load the splash screen as logo
    try {
        $splashPath = Join-Path $PSScriptRoot "..\..\assets\SplashScreen.png"
        if (Test-Path $splashPath) {
            $splashImage = [System.Drawing.Image]::FromFile($splashPath)
            $logoIcon = New-Object System.Drawing.Bitmap($splashImage, 80, 60)
            $splashImage.Dispose()
        }
        else {
            $logoIcon = $null
        }
    }
    catch {
        $logoIcon = $null
    }
    if ($logoIcon) {
        $logoPictureBox.Image = $logoIcon
    }
    else {
        # Fallback to text if image not available
        $logoLabel = New-Object System.Windows.Forms.Label
        $logoLabel.Text = "[BACKUP]"
        $logoLabel.Location = New-Object System.Drawing.Point(380, 30)
        $logoLabel.Size = New-Object System.Drawing.Size(100, 60)
        $logoLabel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 16, [System.Drawing.FontStyle]::Bold)
        $logoLabel.TextAlign = "MiddleCenter"
        $logoLabel.ForeColor = [System.Drawing.Color]::DarkBlue
        $logoLabel.BorderStyle = "FixedSingle"
        $logoPictureBox = $logoLabel
    }

    # Application Title
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "Enhanced Backup Manager"
    $titleLabel.Location = New-Object System.Drawing.Point(200, 100)
    $titleLabel.Size = New-Object System.Drawing.Size(460, 40)
    $titleLabel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 18, [System.Drawing.FontStyle]::Bold)
    $titleLabel.TextAlign = "MiddleCenter"
    $titleLabel.ForeColor = [System.Drawing.Color]::DarkBlue

    # Version Info
    $versionLabel = New-Object System.Windows.Forms.Label
    $versionLabel.Text = "Version 2.0 - Enhanced Edition"
    $versionLabel.Location = New-Object System.Drawing.Point(200, 150)
    $versionLabel.Size = New-Object System.Drawing.Size(460, 25)
    $versionLabel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 12)
    $versionLabel.TextAlign = "MiddleCenter"
    $versionLabel.ForeColor = [System.Drawing.Color]::DarkGreen

    # Description
    $descLabel = New-Object System.Windows.Forms.Label
    $descLabel.Text = "A comprehensive PowerShell-based backup and restore solution with GUI interface, scheduling capabilities, and comprehensive logging."
    $descLabel.Location = New-Object System.Drawing.Point(50, 200)
    $descLabel.Size = New-Object System.Drawing.Size(760, 50)
    $descLabel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 11)
    $descLabel.TextAlign = "MiddleCenter"

    # Features Section
    $featuresLabel = New-Object System.Windows.Forms.Label
    $featuresLabel.Text = "KEY FEATURES"
    $featuresLabel.Location = New-Object System.Drawing.Point(50, 270)
    $featuresLabel.Size = New-Object System.Drawing.Size(200, 25)
    $featuresLabel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 12, [System.Drawing.FontStyle]::Bold)
    $featuresLabel.ForeColor = [System.Drawing.Color]::DarkBlue

    $featuresText = New-Object System.Windows.Forms.TextBox
    $featuresText.Multiline = $true
    $featuresText.ReadOnly = $true
    $featuresText.ScrollBars = "Vertical"
    $featuresText.Location = New-Object System.Drawing.Point(50, 300)
    $featuresText.Size = New-Object System.Drawing.Size(350, 180)
    $featuresText.Font = New-Object System.Drawing.Font("Consolas", 9)
    $featuresText.Text = @"
* Graphical User Interface
* AWS S3 Integration
* Flexible Folder Selection
* Real-time Progress Monitoring
* Dry Run Mode for Testing
* Windows Task Scheduler Integration
* Comprehensive Logging
* Configuration Management
* Background Operations
* Operation Cancellation
* Auto-refresh Logs
* Connection Testing
"@

    # Credits Section
    $creditsLabel = New-Object System.Windows.Forms.Label
    $creditsLabel.Text = "CREDITS"
    $creditsLabel.Location = New-Object System.Drawing.Point(450, 270)
    $creditsLabel.Size = New-Object System.Drawing.Size(200, 25)
    $creditsLabel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 12, [System.Drawing.FontStyle]::Bold)
    $creditsLabel.ForeColor = [System.Drawing.Color]::DarkBlue

    $creditsText = New-Object System.Windows.Forms.TextBox
    $creditsText.Multiline = $true
    $creditsText.ReadOnly = $true
    $creditsText.Location = New-Object System.Drawing.Point(450, 300)
    $creditsText.Size = New-Object System.Drawing.Size(350, 120)
    $creditsText.Font = New-Object System.Drawing.Font("Consolas", 9)
    $creditsText.Text = @"
Original Backup Scripts:
* Gianpaolo Albanese (2024)

Enhanced GUI & Features:
* AI Assistant (2025)
* Enhanced with modern UI
* Added real-time monitoring
* Integrated scheduling
* Comprehensive error handling

Built with PowerShell & .NET WinForms
"@

    # System Info
    $sysInfoLabel = New-Object System.Windows.Forms.Label
    $sysInfoLabel.Text = "SYSTEM INFORMATION"
    $sysInfoLabel.Location = New-Object System.Drawing.Point(450, 430)
    $sysInfoLabel.Size = New-Object System.Drawing.Size(200, 25)
    $sysInfoLabel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 10, [System.Drawing.FontStyle]::Bold)
    $sysInfoLabel.ForeColor = [System.Drawing.Color]::DarkBlue

    $sysInfoText = New-Object System.Windows.Forms.Label
    $sysInfoText.Text = "PowerShell Version: $($PSVersionTable.PSVersion)`nOS: $([System.Environment]::OSVersion.VersionString)`n.NET Framework: $([System.Environment]::Version)"
    $sysInfoText.Location = New-Object System.Drawing.Point(450, 460)
    $sysInfoText.Size = New-Object System.Drawing.Size(350, 60)
    $sysInfoText.Font = New-Object System.Drawing.Font("Consolas", 8)

    $aboutPanel.Controls.AddRange(@($logoPictureBox, $titleLabel, $versionLabel, $descLabel, 
                                   $featuresLabel, $featuresText, $creditsLabel, $creditsText,
                                   $sysInfoLabel, $sysInfoText))

    $tab.Controls.Add($aboutPanel)
}

# Enhanced event handlers and functions
function Load-Configuration {
    # Set backup type radio buttons
    switch ($script:Config.BackupType) {
        "Local" { $script:LocalRadioButton.Checked = $true }
        "Network" { $script:NetworkRadioButton.Checked = $true }
        "AWS_S3" { $script:S3RadioButton.Checked = $true }
        default { $script:LocalRadioButton.Checked = $true }
    }
    
    # Load configuration values
    $script:BackupDestinationTextBox.Text = $script:Config.BackupDestination
    $script:S3BucketComboBox.Text = $script:Config.S3Bucket
    $script:AWSProfileComboBox.Text = $script:Config.AWSProfile
    $script:RestoreDestinationTextBox.Text = $script:Config.RestoreDestination
    
    # Update visibility based on backup type
    Update-ConfigurationVisibility
    
    Refresh-FolderList
    Refresh-Logs
}

function Update-ConfigurationVisibility {
    if ($script:LocalRadioButton.Checked -or $script:NetworkRadioButton.Checked) {
        $script:LocalConfigGroup.Visible = $true
        $script:AWSConfigGroup.Visible = $false
    }
    elseif ($script:S3RadioButton.Checked) {
        $script:LocalConfigGroup.Visible = $false
        $script:AWSConfigGroup.Visible = $true
    }
}

function Refresh-S3Buckets {
    Update-Status "Refreshing S3 buckets..." "INFO"
    try {
        $buckets = aws s3 ls --profile $script:AWSProfileComboBox.Text 2>&1
        if ($LASTEXITCODE -eq 0) {
            $script:S3BucketComboBox.Items.Clear()
            $buckets | ForEach-Object {
                if ($_ -match '\s+(.+)$') {
                    $script:S3BucketComboBox.Items.Add($matches[1])
                }
            }
            Update-Status "S3 buckets refreshed successfully" "SUCCESS"
        } else {
            Update-Status "Failed to refresh S3 buckets" "ERROR"
        }
    }
    catch {
        Update-Status "Error refreshing S3 buckets: $_" "ERROR"
    }
}

function Refresh-AWSProfiles {
    Update-Status "Refreshing AWS profiles..." "INFO"
    try {
        $configPath = "$env:USERPROFILE\.aws\config"
        if (Test-Path $configPath) {
            $profiles = Get-Content $configPath | Where-Object { $_ -match '^\[profile\s+(.+)\]' } | ForEach-Object { $matches[1] }
            $script:AWSProfileComboBox.Items.Clear()
            $script:AWSProfileComboBox.Items.Add("default")
            $profiles | ForEach-Object { $script:AWSProfileComboBox.Items.Add($_) }
            Update-Status "AWS profiles refreshed successfully" "SUCCESS"
        }
    }
    catch {
        Update-Status "Error refreshing AWS profiles: $_" "ERROR"
    }
}

function Start-OperationWithProgress {
    param([string]$Operation, [switch]$DryRun)
    
    # Initialize operation tracking
    $script:OperationStartTime = Get-Date
    $script:TotalFilesProcessed = 0
    $script:CurrentOperation = $Operation
    $script:FolderCompletionTimes = @()  # Track completion times for ETA calculation
    
    # Update UI for operation start
    $script:OperationProgressBar.Style = "Continuous"
    $script:OperationProgressBar.Value = 0
    $script:CancelButton.Enabled = $true
    $script:OperationStatusLabel.Text = "Starting $Operation operation..."
    $script:OperationStatusLabel.ForeColor = [System.Drawing.Color]::DarkBlue
    $script:CurrentFileLabel.Text = "Initializing operation..."
    $script:FilesProcessedLabel.Text = "Files: 0 processed"
    $script:SpeedLabel.Text = "Speed: -- MB/s"
    $script:TimeElapsedLabel.Text = "Elapsed: 00:00:00"
    $script:ETALabel.Text = "ETA: Analyzing..."
    
    # Save configuration first
    Save-Configuration
    
    # Build arguments
    $arguments = "-ExecutionPolicy Bypass -File `"$PSScriptRoot\..\core\BackupEngine.ps1`" -Operation $Operation"
    if ($DryRun) { $arguments += " -DryRun" }
    
    # Start background process with error capture
    try {
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = "powershell.exe"
        $processInfo.Arguments = $arguments
        $processInfo.UseShellExecute = $false
        $processInfo.CreateNoWindow = $true
        $processInfo.RedirectStandardOutput = $true
        $processInfo.RedirectStandardError = $true
        
        $script:BackgroundJob = [System.Diagnostics.Process]::Start($processInfo)
        
        # Start monitoring timer (faster updates for better progress tracking)
        $script:MonitoringTimer = New-Object System.Windows.Forms.Timer
        $script:MonitoringTimer.Interval = 500  # 0.5 seconds for responsive updates
        $script:MonitoringTimer.Add_Tick({
            if ($script:BackgroundJob.HasExited) {
                $script:MonitoringTimer.Stop()
                
                # Check for errors in the process
                $errorOutput = $script:BackgroundJob.StandardError.ReadToEnd()
                if ($errorOutput) {
                    Update-Status "Process error: $errorOutput" "ERROR"
                    Write-Host "BackupEngine Error: $errorOutput" -ForegroundColor Red
                }
                
                $exitCode = $script:BackgroundJob.ExitCode
                if ($exitCode -ne 0) {
                    Update-Status "Process exited with code $exitCode" "ERROR"
                    Write-Host "BackupEngine exited with code: $exitCode" -ForegroundColor Red
                }
                
                Complete-Operation
            } else {
                Update-OperationProgress
            }
        })
        $script:MonitoringTimer.Start()
        
        Update-Status "$Operation operation started" "INFO"
    }
    catch {
        Update-Status "Failed to start $Operation operation: $_" "ERROR"
        Complete-Operation
    }
}

function Update-OperationProgress {
    try {
        # Calculate elapsed time
        $elapsed = (Get-Date) - $script:OperationStartTime
        $script:TimeElapsedLabel.Text = "Elapsed: $($elapsed.ToString('hh\:mm\:ss'))"
        
        # Check if background job is still running
        if ($script:BackgroundJob -and $script:BackgroundJob.HasExited) {
            $script:MonitoringTimer.Stop()
            Complete-Operation
            return
        }
        
        # Read the latest log entries to get progress information
        $engineLogPath = "$env:USERPROFILE\Desktop\BackupEngine.log"
        if (Test-Path $engineLogPath) {
            $recentLogs = Get-Content $engineLogPath -Tail 20 -ErrorAction SilentlyContinue
            
            # Check if operation completed by looking for summary in logs
            $summaryFound = $recentLogs | Where-Object { $_ -match "=== END SUMMARY ===" }
            if ($summaryFound) {
                $script:MonitoringTimer.Stop()
                Complete-Operation
                return
            }
            
            # Parse logs for progress information
            $progressInfo = Parse-LogProgress $recentLogs
            
            if ($progressInfo.CurrentFile) {
                $script:CurrentFileLabel.Text = "Processing: $($progressInfo.CurrentFile)"
            }
            
            if ($progressInfo.FilesProcessed -gt 0) {
                $script:FilesProcessedLabel.Text = "Files: $($progressInfo.FilesProcessed) processed"
                $script:TotalFilesProcessed = $progressInfo.FilesProcessed
            }
            
            if ($progressInfo.CurrentFolder -and $progressInfo.TotalFolders) {
                # Calculate folder-based progress
                $folderProgress = [math]::Round(($progressInfo.CurrentFolder / $progressInfo.TotalFolders) * 100)
                $script:OperationProgressBar.Value = [math]::Min($folderProgress, 100)
                $script:OperationStatusLabel.Text = "Processing folder $($progressInfo.CurrentFolder) of $($progressInfo.TotalFolders)"
            }
            
            # Update status based on recent log entries
            $latestEntry = $recentLogs | Select-Object -Last 1
            if ($latestEntry -match "\[INFO\]\s*(.+)") {
                $script:OperationStatusLabel.Text = $matches[1]
            }
            
            # Calculate speed and ETA
            if ($elapsed.TotalSeconds -gt 5) {
                # Calculate speed if we have file data
                if ($script:TotalFilesProcessed -gt 0) {
                    $filesPerSecond = $script:TotalFilesProcessed / $elapsed.TotalSeconds
                    $script:SpeedLabel.Text = "Speed: $([math]::Round($filesPerSecond, 1)) files/s"
                }
                
                # Calculate ETA based on folder progress
                if ($progressInfo.CurrentFolder -and $progressInfo.TotalFolders -and $progressInfo.CurrentFolder -gt 0 -and $progressInfo.TotalFolders -gt 0) {
                    if ($progressInfo.CurrentFolder -lt $progressInfo.TotalFolders) {
                        # Simple ETA calculation based on folder progress
                        $foldersRemaining = $progressInfo.TotalFolders - $progressInfo.CurrentFolder
                        $foldersPerSecond = $progressInfo.CurrentFolder / $elapsed.TotalSeconds
                        
                        if ($foldersPerSecond -gt 0) {
                            $etaSeconds = $foldersRemaining / $foldersPerSecond
                            $etaTimeSpan = [TimeSpan]::FromSeconds($etaSeconds)
                            $script:ETALabel.Text = "ETA: $($etaTimeSpan.ToString('hh\:mm\:ss'))"
                        }
                    } else {
                        $script:ETALabel.Text = "ETA: Completing..."
                    }
                }
            }
        }
        
        # Force UI refresh
        $script:MainForm.Refresh()
    }
    catch {
        Write-Log "Error updating operation progress: $_" -Level "ERROR"
    }
}
function Parse-LogProgress {
    param([string[]]$logLines)
    
    $progressInfo = @{
        CurrentFile = $null
        FilesProcessed = 0
        CurrentFolder = 0
        TotalFolders = 0
    }
    
    foreach ($line in $logLines) {
        # Look for folder progress indicators like "[1/6] Processing:"
        if ($line -match '\[(\d+)/(\d+)\]\s*Processing:\s*''([^'']+)''') {
            $progressInfo.CurrentFolder = [int]$matches[1]
            $progressInfo.TotalFolders = [int]$matches[2]
            $progressInfo.CurrentFile = $matches[3]
        }
        
        # Look for file count indicators like "Would copy 737 files"
        if ($line -match 'Would copy\s+(\d+)\s+files') {
            $progressInfo.FilesProcessed += [int]$matches[1]
        }
        
        # Look for file count indicators like "Processed 37 files" or "Copied 37 files"
        if ($line -match '(Processed|Copied)\s+(\d+)\s+files') {
            $progressInfo.FilesProcessed += [int]$matches[2]
        }
        
        # Look for upload/download indicators
        if ($line -match '(upload|download):\s*(.+)') {
            $progressInfo.CurrentFile = $matches[2]
            $progressInfo.FilesProcessed++
        }
    }
    
    return $progressInfo
}

function Complete-Operation {
    if ($script:MonitoringTimer) {
        $script:MonitoringTimer.Stop()
        $script:MonitoringTimer.Dispose()
        $script:MonitoringTimer = $null
    }
    
    # Check the final status from logs
    $engineLogPath = "$env:USERPROFILE\Desktop\BackupEngine.log"
    $operationStatus = "Completed"
    $statusColor = [System.Drawing.Color]::DarkGreen
    
    # Check if the process had any issues
    if ($script:BackgroundJob) {
        $exitCode = $script:BackgroundJob.ExitCode
        if ($exitCode -ne 0) {
            $operationStatus = "Failed (Exit Code: $exitCode)"
            $statusColor = [System.Drawing.Color]::Red
            Update-Status "Operation failed with exit code: $exitCode" "ERROR"
        }
    }
    
    if (Test-Path $engineLogPath) {
        $recentLogs = Get-Content $engineLogPath -Tail 30 -ErrorAction SilentlyContinue
        
        # Check for completion status
        $completedWithErrors = $recentLogs | Where-Object { $_ -match "COMPLETED WITH ERRORS" }
        $completedSuccessfully = $recentLogs | Where-Object { $_ -match "COMPLETED SUCCESSFULLY" }
        $fatalError = $recentLogs | Where-Object { $_ -match "Fatal error" }
        
        if ($fatalError) {
            $operationStatus = "Fatal error occurred"
            $statusColor = [System.Drawing.Color]::Red
            Update-Status "Fatal error detected in logs" "ERROR"
        } elseif ($completedWithErrors) {
            $operationStatus = "Completed with errors"
            $statusColor = [System.Drawing.Color]::DarkOrange
        } elseif ($completedSuccessfully) {
            $operationStatus = "Completed successfully"
            $statusColor = [System.Drawing.Color]::DarkGreen
        }
        
        # Extract summary information
        $summaryLines = $recentLogs | Where-Object { $_ -match "Total Files Processed:|Successful Operations:|Failed Operations:" }
        foreach ($line in $summaryLines) {
            if ($line -match "Total Files Processed:\s*(\d+)") {
                $script:TotalFilesProcessed = [int]$matches[1]
            }
        }
        
        # Show recent error messages in the GUI
        $errorLines = $recentLogs | Where-Object { $_ -match "\[ERROR\]" } | Select-Object -Last 3
        foreach ($errorLine in $errorLines) {
            Update-Status $errorLine "ERROR"
        }
    } else {
        $operationStatus = "No log file found - operation may have failed to start"
        $statusColor = [System.Drawing.Color]::Red
        Update-Status "Warning: No log file found at $engineLogPath" "ERROR"
    }
    
    $script:OperationProgressBar.Value = 100
    $script:CancelButton.Enabled = $false
    $script:OperationStatusLabel.Text = $operationStatus
    $script:OperationStatusLabel.ForeColor = $statusColor
    $script:CurrentFileLabel.Text = "Operation finished - check logs for details"
    
    # Calculate final statistics
    if ($script:OperationStartTime) {
        $totalTime = (Get-Date) - $script:OperationStartTime
        $script:TimeElapsedLabel.Text = "Total: $($totalTime.ToString('hh\:mm\:ss'))"
        $script:ETALabel.Text = "Completed"
        
        if ($script:TotalFilesProcessed -gt 0) {
            $avgSpeed = $script:TotalFilesProcessed / $totalTime.TotalSeconds
            $script:SpeedLabel.Text = "Avg: $([math]::Round($avgSpeed, 1)) files/s"
        }
        
        # Update statistics display
        $operationType = if ($script:CurrentOperation) { $script:CurrentOperation } else { "Operation" }
        $filesText = if ($script:TotalFilesProcessed -gt 0) { "$($script:TotalFilesProcessed) files processed" } else { "No files processed" }
        $timeText = "Duration: $($totalTime.ToString('hh\:mm\:ss'))"
        $speedText = if ($script:TotalFilesProcessed -gt 0 -and $totalTime.TotalSeconds -gt 0) { 
            "Avg Speed: $([math]::Round($script:TotalFilesProcessed / $totalTime.TotalSeconds, 1)) files/s" 
        } else { 
            "Speed: N/A" 
        }
        
        $script:StatsLabel.Text = "Last ${operationType}: $filesText | $timeText | $speedText | Status: $operationStatus"
        $script:StatsLabel.ForeColor = $statusColor
    }
    
    $script:BackgroundJob = $null
    Refresh-Logs
    Update-Status "Operation completed" "SUCCESS"
}

function Cancel-Operation {
    if ($script:BackgroundJob -and -not $script:BackgroundJob.HasExited) {
        try {
            $script:BackgroundJob.Kill()
            $script:OperationStatusLabel.Text = "Operation cancelled by user"
            $script:OperationStatusLabel.ForeColor = [System.Drawing.Color]::Red
            $script:CurrentFileLabel.Text = "Operation was cancelled"
            Update-Status "Operation cancelled by user" "WARNING"
            
            # Update statistics for cancelled operation
            if ($script:OperationStartTime) {
                $totalTime = (Get-Date) - $script:OperationStartTime
                $operationType = if ($script:CurrentOperation) { $script:CurrentOperation } else { "Operation" }
                $filesText = if ($script:TotalFilesProcessed -gt 0) { "$($script:TotalFilesProcessed) files processed" } else { "No files processed" }
                $timeText = "Duration: $($totalTime.ToString('hh\:mm\:ss'))"
                
                $script:StatsLabel.Text = "Last ${operationType}: $filesText | $timeText | Status: Cancelled by User"
                $script:StatsLabel.ForeColor = [System.Drawing.Color]::Orange
            }
        }
        catch {
            Update-Status "Error cancelling operation: $_" "ERROR"
        }
    }
    Complete-Operation
}

# Implement all the existing functions with enhancements
function Refresh-FolderList {
    $script:FolderListBox.Items.Clear()
    foreach ($folder in $script:Config.BackupFolders) {
        $displayText = "$($folder.Source) -> $($folder.Destination)"
        $index = $script:FolderListBox.Items.Add($displayText)
        $script:FolderListBox.SetItemChecked($index, $folder.Enabled)
    }
}

function Check-AllFolders {
    for ($i = 0; $i -lt $script:FolderListBox.Items.Count; $i++) {
        $script:FolderListBox.SetItemChecked($i, $true)
    }
}

function Uncheck-AllFolders {
    for ($i = 0; $i -lt $script:FolderListBox.Items.Count; $i++) {
        $script:FolderListBox.SetItemChecked($i, $false)
    }
}

function Save-Configuration {
    try {
        # Determine backup type
        if ($script:LocalRadioButton.Checked) {
            $script:Config.BackupType = "Local"
        }
        elseif ($script:NetworkRadioButton.Checked) {
            $script:Config.BackupType = "Network"
        }
        elseif ($script:S3RadioButton.Checked) {
            $script:Config.BackupType = "AWS_S3"
        }
        
        # Save configuration values
        $script:Config.BackupDestination = $script:BackupDestinationTextBox.Text
        $script:Config.S3Bucket = $script:S3BucketComboBox.Text
        $script:Config.AWSProfile = $script:AWSProfileComboBox.Text
        $script:Config.RestoreDestination = $script:RestoreDestinationTextBox.Text
        
        # Update folder enabled status
        for ($i = 0; $i -lt $script:FolderListBox.Items.Count; $i++) {
            $script:Config.BackupFolders[$i].Enabled = $script:FolderListBox.GetItemChecked($i)
        }
        
        Save-Config $script:Config
        Update-Status "Configuration saved successfully" "SUCCESS"
    }
    catch {
        Update-Status "Failed to save configuration: $_" "ERROR"
    }
}

function Clear-Configuration {
    # Show confirmation dialog
    $result = [System.Windows.Forms.MessageBox]::Show(
        "This will clear all configuration including credentials and paths.`n`nThis is useful before sharing the project or resetting to defaults.`n`nAre you sure you want to continue?",
        "Clear Configuration",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    
    if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
        try {
            # Reset to default configuration
            $script:Config = Get-DefaultConfig
            
            # Clear all form fields
            $script:LocalRadioButton.Checked = $true
            $script:NetworkRadioButton.Checked = $false
            $script:S3RadioButton.Checked = $false
            
            $script:BackupDestinationTextBox.Text = $script:Config.BackupDestination
            $script:S3BucketComboBox.Text = ""
            $script:AWSProfileComboBox.Text = ""
            $script:RestoreDestinationTextBox.Text = $script:Config.RestoreDestination
            
            # Reset status labels
            $script:BackupStatusLabel.Text = "Destination Status: Not Tested"
            $script:BackupStatusLabel.ForeColor = [System.Drawing.Color]::Gray
            $script:AWSConnectionStatusLabel.Text = "Connection Status: Not Tested"
            $script:AWSConnectionStatusLabel.ForeColor = [System.Drawing.Color]::Gray
            
            # Update visibility
            Update-ConfigurationVisibility
            
            # Refresh folder list
            Refresh-FolderList
            
            # Save the cleared configuration
            Save-Config $script:Config
            
            Update-Status "Configuration cleared and reset to defaults" "SUCCESS"
            
            # Show completion message
            [System.Windows.Forms.MessageBox]::Show(
                "Configuration has been cleared successfully!`n`nAll credentials and sensitive information have been removed.`nThe configuration file has been reset to safe defaults.",
                "Configuration Cleared",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
        }
        catch {
            Update-Status "Failed to clear configuration: $_" "ERROR"
            [System.Windows.Forms.MessageBox]::Show(
                "Failed to clear configuration: $_",
                "Error",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
    }
}

function Update-Status([string]$message, [string]$level = "INFO") {
    $script:StatusLabel.Text = $message
    Write-Log $message -Level $level
    if ($script:AutoRefreshCheckBox.Checked) {
        Refresh-Logs
    }
}

function Refresh-Logs {
    if (Test-Path $script:LogPath) {
        try {
            # Get the selected verbosity level and max lines
            $selectedLevel = if ($script:VerbosityComboBox) { $script:VerbosityComboBox.SelectedItem } else { "ALL" }
            $maxLines = if ($script:MaxLinesComboBox) { [int]$script:MaxLinesComboBox.SelectedItem } else { 100 }
            
            # Read all log lines
            $allLogs = Get-Content $script:LogPath -ErrorAction SilentlyContinue
            
            if ($allLogs) {
                # Filter logs based on verbosity level
                $filteredLogs = @()
                
                if ($selectedLevel -eq "ALL") {
                    $filteredLogs = $allLogs
                }
                else {
                    foreach ($line in $allLogs) {
                        # Check if line contains the selected log level
                        if ($line -match "\[$selectedLevel\]") {
                            $filteredLogs += $line
                        }
                        # Always include lines without log level markers (like summaries)
                        elseif ($line -notmatch "\[(INFO|WARNING|ERROR|SUCCESS|PROGRESS)\]") {
                            $filteredLogs += $line
                        }
                    }
                }
                
                # Get the last N lines (newest entries)
                if ($filteredLogs.Count -gt $maxLines) {
                    $displayLogs = $filteredLogs | Select-Object -Last $maxLines
                }
                else {
                    $displayLogs = $filteredLogs
                }
                
                # Convert to string and display
                $logText = $displayLogs -join "`r`n"
                $script:LogTextBox.Text = $logText
                
                # Scroll to bottom if enabled (default behavior for newest entries)
                if (-not $script:ScrollToBottomCheckBox -or $script:ScrollToBottomCheckBox.Checked) {
                    $script:LogTextBox.SelectionStart = $script:LogTextBox.Text.Length
                    $script:LogTextBox.ScrollToCaret()
                }
            }
            else {
                $script:LogTextBox.Text = "No log entries found."
            }
        }
        catch {
            $script:LogTextBox.Text = "Error reading log file: $_"
        }
    }
    else {
        $script:LogTextBox.Text = "Log file not found: $script:LogPath"
    }
}

# Event handlers
function Browse-ForBackupDestination {
    $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderDialog.Description = "Select backup destination folder"
    if ($folderDialog.ShowDialog() -eq "OK") {
        $script:BackupDestinationTextBox.Text = $folderDialog.SelectedPath
    }
}

function Browse-ForRestoreDestination {
    $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderDialog.Description = "Select restore destination folder"
    if ($folderDialog.ShowDialog() -eq "OK") {
        $script:RestoreDestinationTextBox.Text = $folderDialog.SelectedPath
    }
}

function Test-BackupDestination {
    Update-Status "Testing backup destination..." "INFO"
    $script:BackupStatusLabel.ForegroundColor = [System.Drawing.Color]::Orange
    $script:BackupStatusLabel.Text = "Destination Status: Testing..."
    
    try {
        $destination = $script:BackupDestinationTextBox.Text
        if ([string]::IsNullOrWhiteSpace($destination)) {
            $script:BackupStatusLabel.ForegroundColor = [System.Drawing.Color]::Red
            $script:BackupStatusLabel.Text = "Destination Status: No Path Specified"
            Update-Status "No backup destination specified" "ERROR"
            return
        }
        
        # Test if path exists or can be created
        if (Test-Path $destination) {
            # Test write access
            $testFileName = "backup_test_$(Get-Date -Format 'yyyyMMddHHmmss').tmp"
            $testFile = Join-Path $destination $testFileName
            try {
                "test" | Out-File -FilePath $testFile -ErrorAction Stop
                Remove-Item $testFile -ErrorAction SilentlyContinue
                
                $script:BackupStatusLabel.ForegroundColor = [System.Drawing.Color]::Green
                $script:BackupStatusLabel.Text = "Destination Status: Ready (Read/Write Access)"
                Update-Status "Backup destination is accessible and writable" "SUCCESS"
            }
            catch {
                $script:BackupStatusLabel.ForegroundColor = [System.Drawing.Color]::Red
                $script:BackupStatusLabel.Text = "Destination Status: No Write Access"
                Update-Status "Backup destination exists but is not writable" "ERROR"
            }
        }
        else {
            # Try to create the directory
            try {
                New-Item -ItemType Directory -Path $destination -Force -ErrorAction Stop | Out-Null
                $script:BackupStatusLabel.ForegroundColor = [System.Drawing.Color]::Green
                $script:BackupStatusLabel.Text = "Destination Status: Created Successfully"
                Update-Status "Backup destination created successfully" "SUCCESS"
            }
            catch {
                $script:BackupStatusLabel.ForegroundColor = [System.Drawing.Color]::Red
                $script:BackupStatusLabel.Text = "Destination Status: Cannot Create Path"
                Update-Status "Cannot create backup destination: $_" "ERROR"
            }
        }
    }
    catch {
        $script:BackupStatusLabel.ForegroundColor = [System.Drawing.Color]::Red
        $script:BackupStatusLabel.Text = "Destination Status: Test Failed"
        Update-Status "Backup destination test failed: $_" "ERROR"
    }
}

function Test-AWSConnection {
    Update-Status "Testing AWS connection..." "INFO"
    $script:AWSConnectionStatusLabel.ForeColor = [System.Drawing.Color]::Orange
    $script:AWSConnectionStatusLabel.Text = "Connection Status: Testing..."
    
    try {
        $awsVersion = aws --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            aws sts get-caller-identity --profile $script:AWSProfileComboBox.Text | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $script:AWSConnectionStatusLabel.ForeColor = [System.Drawing.Color]::Green
                $script:AWSConnectionStatusLabel.Text = "Connection Status: Connected Successfully"
                Update-Status "AWS connection successful" "SUCCESS"
            } else {
                $script:AWSConnectionStatusLabel.ForeColor = [System.Drawing.Color]::Red
                $script:AWSConnectionStatusLabel.Text = "Connection Status: Authentication Failed"
                Update-Status "AWS authentication failed" "ERROR"
            }
        } else {
            $script:AWSConnectionStatusLabel.ForeColor = [System.Drawing.Color]::Red
            $script:AWSConnectionStatusLabel.Text = "Connection Status: AWS CLI Not Found"
            Update-Status "AWS CLI not found" "ERROR"
        }
    }
    catch {
        $script:AWSConnectionStatusLabel.ForeColor = [System.Drawing.Color]::Red
        $script:AWSConnectionStatusLabel.Text = "Connection Status: Connection Error"
        Update-Status "AWS connection test failed: $_" "ERROR"
    }
}

function Start-Backup { Start-OperationWithProgress "Backup" }
function Start-Restore { Start-OperationWithProgress "Restore" }
function Start-DryRunBackup { Start-OperationWithProgress "Backup" -DryRun }
function Start-DryRunRestore { Start-OperationWithProgress "Restore" -DryRun }

function Configure-Schedule {
    Start-Process -FilePath "powershell.exe" -ArgumentList "-File `"$PSScriptRoot\BackupScheduler.ps1`""
}

function Add-CustomFolder {
    $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($folderDialog.ShowDialog() -eq "OK") {
        $destination = [System.IO.Path]::GetFileName($folderDialog.SelectedPath)
        $newFolder = @{
            Source = $folderDialog.SelectedPath
            Destination = $destination
            Enabled = $true
        }
        $script:Config.BackupFolders += $newFolder
        Refresh-FolderList
    }
}

function Remove-SelectedFolder {
    if ($script:FolderListBox.SelectedIndex -ge 0) {
        $newFolders = @()
        for ($i = 0; $i -lt $script:Config.BackupFolders.Count; $i++) {
            if ($i -ne $script:FolderListBox.SelectedIndex) {
                $newFolders += $script:Config.BackupFolders[$i]
            }
        }
        $script:Config.BackupFolders = $newFolders
        Refresh-FolderList
    }
}

function Clear-Logs {
    if (Test-Path $script:LogPath) {
        Clear-Content $script:LogPath
        $script:LogTextBox.Clear()
        Update-Status "Logs cleared" "INFO"
    }
}

# Show splash screen first
Show-SplashScreen -Duration 3000

# Initialize and show GUI
Initialize-GUI
$script:MainForm.ShowDialog()