# =============================================================================
# AWS Systems Manager Agent Installation and Configuration for Windows
# =============================================================================
# This script ensures the SSM agent is installed, updated, and running
# Compatible with Windows Server 2016, 2019, 2022

# Variables
$Region = "${region}"
$LogFile = "C:\Windows\Temp\ssm-setup.log"

# Function to log messages
function Write-Log {
    param([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "$Timestamp - $Message"
    Write-Output $LogMessage
    Add-Content -Path $LogFile -Value $LogMessage
}

Write-Log "Starting SSM Agent setup script for Windows"

# Create log directory if it doesn't exist
$LogDir = Split-Path $LogFile -Parent
if (!(Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force
}

try {
    # Check Windows version
    $OSVersion = (Get-WmiObject -Class Win32_OperatingSystem).Caption
    Write-Log "Detected OS: $OSVersion"

    # Check current SSM agent status
    $SSMService = Get-Service -Name "AmazonSSMAgent" -ErrorAction SilentlyContinue
    if ($SSMService) {
        Write-Log "SSM Agent service found. Current status: $($SSMService.Status)"
        $AgentInstalled = $true
    } else {
        Write-Log "SSM Agent service not found"
        $AgentInstalled = $false
    }

    # Determine architecture
    $Architecture = (Get-WmiObject -Class Win32_Processor).Architecture
    if ($Architecture -eq 9) {
        $ArchSuffix = "amd64"
        Write-Log "Detected architecture: x64"
    } elseif ($Architecture -eq 5) {
        $ArchSuffix = "386"
        Write-Log "Detected architecture: x86"
    } else {
        Write-Log "ERROR: Unsupported architecture: $Architecture"
        throw "Unsupported architecture"
    }

    # Download and install/update SSM agent
    $TempDir = "C:\Windows\Temp"
    $SSMInstallerUrl = "https://s3.$Region.amazonaws.com/amazon-ssm-$Region/latest/windows_$ArchSuffix/AmazonSSMAgentSetup.exe"
    $SSMInstallerPath = "$TempDir\AmazonSSMAgentSetup.exe"

    Write-Log "Downloading SSM Agent from: $SSMInstallerUrl"
    
    # Use TLS 1.2 for secure downloads
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
    try {
        Invoke-WebRequest -Uri $SSMInstallerUrl -OutFile $SSMInstallerPath -UseBasicParsing
        Write-Log "Successfully downloaded SSM Agent installer"
    } catch {
        Write-Log "ERROR: Failed to download SSM Agent installer: $($_.Exception.Message)"
        throw
    }

    # Verify the installer was downloaded
    if (!(Test-Path $SSMInstallerPath)) {
        Write-Log "ERROR: SSM Agent installer not found at $SSMInstallerPath"
        throw "Installer download failed"
    }

    $InstallerSize = (Get-Item $SSMInstallerPath).Length
    Write-Log "Installer downloaded successfully. Size: $InstallerSize bytes"

    # Install or update SSM agent
    if ($AgentInstalled) {
        Write-Log "Updating existing SSM Agent installation..."
        # Stop the service before updating
        try {
            Stop-Service -Name "AmazonSSMAgent" -Force -ErrorAction SilentlyContinue
            Write-Log "Stopped SSM Agent service for update"
        } catch {
            Write-Log "Warning: Could not stop SSM Agent service: $($_.Exception.Message)"
        }
    } else {
        Write-Log "Installing SSM Agent for the first time..."
    }

    # Run the installer
    Write-Log "Running SSM Agent installer..."
    try {
        $InstallProcess = Start-Process -FilePath $SSMInstallerPath -ArgumentList "/S" -Wait -PassThru
        if ($InstallProcess.ExitCode -eq 0) {
            Write-Log "SSM Agent installer completed successfully"
        } else {
            Write-Log "WARNING: SSM Agent installer returned exit code: $($InstallProcess.ExitCode)"
        }
    } catch {
        Write-Log "ERROR: Failed to run SSM Agent installer: $($_.Exception.Message)"
        throw
    }

    # Wait for installation to complete
    Start-Sleep -Seconds 10

    # Verify installation and start service
    $SSMService = Get-Service -Name "AmazonSSMAgent" -ErrorAction SilentlyContinue
    if ($SSMService) {
        Write-Log "SSM Agent service found after installation"
        
        # Configure service to start automatically
        try {
            Set-Service -Name "AmazonSSMAgent" -StartupType Automatic
            Write-Log "Set SSM Agent service to start automatically"
        } catch {
            Write-Log "Warning: Could not set SSM Agent startup type: $($_.Exception.Message)"
        }

        # Start the service if it's not running
        if ($SSMService.Status -ne "Running") {
            try {
                Start-Service -Name "AmazonSSMAgent"
                Write-Log "Started SSM Agent service"
            } catch {
                Write-Log "ERROR: Failed to start SSM Agent service: $($_.Exception.Message)"
                throw
            }
        }

        # Wait for service to fully start
        Start-Sleep -Seconds 15

        # Final verification
        $SSMService = Get-Service -Name "AmazonSSMAgent"
        if ($SSMService.Status -eq "Running") {
            Write-Log "SUCCESS: SSM Agent is running"
            
            # Get SSM Agent version if possible
            try {
                $SSMAgentPath = "$${env:ProgramFiles}\Amazon\SSM\amazon-ssm-agent.exe"
                if (Test-Path $SSMAgentPath) {
                    $VersionInfo = (Get-Item $SSMAgentPath).VersionInfo
                    Write-Log "SSM Agent version: $($VersionInfo.ProductVersion)"
                }
            } catch {
                Write-Log "Could not retrieve SSM Agent version information"
            }

            # Configure Windows Firewall (if enabled) to allow SSM communication
            try {
                $FirewallStatus = Get-NetFirewallProfile -Profile Domain,Public,Private | Where-Object {$_.Enabled -eq $true}
                if ($FirewallStatus) {
                    Write-Log "Windows Firewall is enabled, configuring rules for SSM..."
                    
                    # Allow outbound HTTPS (port 443) for SSM communication
                    New-NetFirewallRule -DisplayName "AWS SSM Agent HTTPS Outbound" -Direction Outbound -Protocol TCP -LocalPort Any -RemotePort 443 -Action Allow -ErrorAction SilentlyContinue
                    Write-Log "Added Windows Firewall rule for SSM HTTPS communication"
                }
            } catch {
                Write-Log "Warning: Could not configure Windows Firewall rules: $($_.Exception.Message)"
            }

            # Check if instance can communicate with SSM (optional verification)
            try {
                Write-Log "Checking SSM connectivity..."
                $InstanceId = (Invoke-WebRequest -Uri "http://169.254.169.254/latest/meta-data/instance-id" -UseBasicParsing -TimeoutSec 5).Content
                Write-Log "Instance ID: $InstanceId"
                
                # This will fail if AWS CLI is not installed, but we'll try anyway
                try {
                    $SSMCheck = aws ssm describe-instance-information --region $Region --filters "Key=InstanceIds,Values=$InstanceId" --query "InstanceInformationList[0].{InstanceId:InstanceId,AgentVersion:AgentVersion,PlatformType:PlatformType,PlatformName:PlatformName}" --output table 2>$null
                    if ($SSMCheck) {
                        Write-Log "SSM registration verified"
                    }
                } catch {
                    Write-Log "SSM registration check skipped (AWS CLI not available or instance not yet registered)"
                }
            } catch {
                Write-Log "Instance metadata check failed (may be normal during boot): $($_.Exception.Message)"
            }

        } else {
            Write-Log "ERROR: SSM Agent service is not running. Status: $($SSMService.Status)"
            
            # Try to get more information about why it failed
            try {
                $EventLogs = Get-WinEvent -LogName Application -MaxEvents 10 | Where-Object {$_.ProviderName -like "*SSM*" -or $_.ProviderName -like "*Amazon*"}
                if ($EventLogs) {
                    Write-Log "Recent SSM-related event logs:"
                    foreach ($Event in $EventLogs) {
                        Write-Log "Event: $($Event.TimeCreated) - $($Event.LevelDisplayName) - $($Event.Message)"
                    }
                }
            } catch {
                Write-Log "Could not retrieve event logs for troubleshooting"
            }
            
            throw "SSM Agent failed to start"
        }
    } else {
        Write-Log "ERROR: SSM Agent service not found after installation"
        throw "SSM Agent installation failed"
    }

    # Clean up installer
    try {
        Remove-Item -Path $SSMInstallerPath -Force -ErrorAction SilentlyContinue
        Write-Log "Cleaned up installer file"
    } catch {
        Write-Log "Warning: Could not clean up installer file: $($_.Exception.Message)"
    }

    Write-Log "SUCCESS: SSM Agent setup completed successfully"

} catch {
    Write-Log "ERROR: SSM Agent setup failed: $($_.Exception.Message)"
    Write-Log "Stack trace: $($_.Exception.StackTrace)"
    
    # Don't throw here as it might prevent other user data scripts from running
    # Just log the error and continue
    Write-Log "Continuing with other initialization tasks..."
}

Write-Log "SSM Agent setup script completed"
