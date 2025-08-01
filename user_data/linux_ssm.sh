#!/bin/bash

# =============================================================================
# AWS Systems Manager Agent Installation and Configuration for Linux
# =============================================================================
# This script ensures the SSM agent is installed, updated, and running
# Compatible with Amazon Linux 2, Ubuntu, CentOS, and RHEL

# Variables
REGION="${region}"
LOG_FILE="/var/log/ssm-setup.log"

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "Starting SSM Agent setup script"

# Update system packages
log "Updating system packages..."
if command -v yum &> /dev/null; then
    # Amazon Linux 2, CentOS, RHEL
    yum update -y
    PACKAGE_MANAGER="yum"
elif command -v apt-get &> /dev/null; then
    # Ubuntu, Debian
    apt-get update -y
    PACKAGE_MANAGER="apt"
else
    log "ERROR: Unsupported package manager"
    exit 1
fi

# Install required packages
log "Installing required packages..."
if [[ "$PACKAGE_MANAGER" == "yum" ]]; then
    yum install -y curl wget unzip
elif [[ "$PACKAGE_MANAGER" == "apt" ]]; then
    apt-get install -y curl wget unzip awscli
fi

# Detect architecture
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
    ARCH_SUFFIX="amd64"
elif [[ "$ARCH" == "aarch64" ]]; then
    ARCH_SUFFIX="arm64"
else
    log "ERROR: Unsupported architecture: $ARCH"
    exit 1
fi

# Check if SSM agent is already installed and running
if systemctl is-active --quiet amazon-ssm-agent; then
    log "SSM Agent is already running"
    SSM_STATUS="running"
else
    SSM_STATUS="not_running"
fi

# Install or update SSM agent based on OS
if [[ -f /etc/amazon-linux-release ]] || [[ -f /etc/system-release ]] && grep -q "Amazon Linux" /etc/system-release; then
    # Amazon Linux 2 - SSM agent is pre-installed
    log "Detected Amazon Linux 2 - SSM agent should be pre-installed"
    if [[ "$SSM_STATUS" != "running" ]]; then
        log "Starting SSM agent..."
        systemctl enable amazon-ssm-agent
        systemctl start amazon-ssm-agent
    fi
    
    # Update SSM agent to latest version
    log "Updating SSM agent to latest version..."
    yum update -y amazon-ssm-agent
    
elif [[ -f /etc/ubuntu-release ]] || grep -q "Ubuntu" /etc/os-release; then
    # Ubuntu
    log "Detected Ubuntu - Installing SSM agent..."
    
    # Download and install SSM agent
    cd /tmp
    wget "https://s3.$REGION.amazonaws.com/amazon-ssm-$REGION/latest/debian_$ARCH_SUFFIX/amazon-ssm-agent.deb"
    dpkg -i amazon-ssm-agent.deb
    
    # Enable and start the service
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent
    
elif [[ -f /etc/centos-release ]] || [[ -f /etc/redhat-release ]]; then
    # CentOS/RHEL
    log "Detected CentOS/RHEL - Installing SSM agent..."
    
    # Download and install SSM agent
    cd /tmp
    wget "https://s3.$REGION.amazonaws.com/amazon-ssm-$REGION/latest/linux_$ARCH_SUFFIX/amazon-ssm-agent.rpm"
    rpm -i amazon-ssm-agent.rpm
    
    # Enable and start the service
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent
    
else
    log "WARNING: Unrecognized Linux distribution. Attempting generic installation..."
    
    # Generic installation method
    cd /tmp
    wget "https://s3.$REGION.amazonaws.com/amazon-ssm-$REGION/latest/linux_$ARCH_SUFFIX/amazon-ssm-agent.rpm"
    rpm -i amazon-ssm-agent.rpm || {
        log "RPM installation failed, trying tarball method..."
        wget "https://s3.$REGION.amazonaws.com/amazon-ssm-$REGION/latest/linux_$ARCH_SUFFIX/amazon-ssm-agent.tar.gz"
        tar -xzf amazon-ssm-agent.tar.gz
        # Manual installation would require more complex setup
        log "Manual installation required - please check AWS documentation"
    }
fi

# Wait a moment for the service to initialize
sleep 10

# Verify SSM agent is running
if systemctl is-active --quiet amazon-ssm-agent; then
    log "SUCCESS: SSM Agent is running"
    systemctl status amazon-ssm-agent --no-pager
else
    log "ERROR: SSM Agent failed to start"
    systemctl status amazon-ssm-agent --no-pager
    journalctl -u amazon-ssm-agent --no-pager -n 20
fi

# Configure SSM agent region (optional)
log "Configuring SSM agent region to $REGION"
mkdir -p /etc/amazon/ssm
cat > /etc/amazon/ssm/seelog.xml << EOF
<seelog minlevel="info">
    <outputs formatid="fmtinfo">
        <console />
        <rollingfile type="size" filename="/var/log/amazon/ssm/amazon-ssm-agent.log" maxsize="30000000" maxrolls="5"/>
        <filter levels="error,critical" formatid="fmterror">
            <rollingfile type="size" filename="/var/log/amazon/ssm/errors.log" maxsize="10000000" maxrolls="5"/>
        </filter>
    </outputs>
    <formats>
        <format id="fmterror" format="%Date %Time %LEVEL [%FuncShort @ %File.%Line] %Msg%n"/>
        <format id="fmtdebug" format="%Date %Time %LEVEL [%FuncShort @ %File.%Line] %Msg%n"/>
        <format id="fmtinfo" format="%Date %Time %LEVEL %Msg%n"/>
    </formats>
</seelog>
EOF

# Restart SSM agent to pick up configuration changes
log "Restarting SSM agent to apply configuration..."
systemctl restart amazon-ssm-agent

# Final verification
sleep 5
if systemctl is-active --quiet amazon-ssm-agent; then
    log "SUCCESS: SSM Agent setup completed successfully"
    
    # Display agent version and status
    if command -v amazon-ssm-agent &> /dev/null; then
        log "SSM Agent version: $(amazon-ssm-agent -version 2>/dev/null || echo 'Version check failed')"
    fi
    
    # Check if instance is registered with SSM
    log "Checking SSM registration status..."
    aws ssm describe-instance-information --region "$REGION" --filters "Key=InstanceIds,Values=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)" --query 'InstanceInformationList[0].{InstanceId:InstanceId,AgentVersion:AgentVersion,PlatformType:PlatformType,PlatformName:PlatformName}' --output table 2>/dev/null || log "SSM registration check failed (may take a few minutes to appear)"
    
else
    log "ERROR: SSM Agent failed to start after configuration"
    exit 1
fi

log "SSM Agent setup script completed"
