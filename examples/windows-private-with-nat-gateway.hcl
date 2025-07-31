# Example: Windows Private Instance with NAT Gateway
# Windows instances in private subnets REQUIRE internet access for:
# - Windows Updates (critical for security patches)
# - SSM agent updates and certificate validation
# - PowerShell module downloads
# - Microsoft service communication

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git::https://github.com/ccl-consulting/aws-ec2-module-terragrunt.git?ref=v0.0.2"
}

inputs = {
  # Instance Configuration
  instance_name    = "windows-private-instance"
  instance_type    = "t3.medium"  # Windows needs more resources
  operating_system = "windows"

  # Network Configuration - Private subnet
  aws_region     = "us-east-1"
  vpc_id         = "vpc-12345678"
  subnet_id      = "subnet-private123"  # Your private subnet
  private_subnet = true

  # NAT Gateway Configuration (REQUIRED for Windows)
  create_nat_gateway     = true
  nat_gateway_subnet_id  = "subnet-public456"  # Must be a public subnet

  # Create private route table with NAT Gateway route
  create_private_route_table = true

  # No Elastic IP for the instance itself
  create_eip = false

  # Enable VPC endpoints for SSM (RECOMMENDED)
  create_vpc_endpoints = true

  # Security Configuration - Windows-specific ports
  custom_ingress_rules = [
    {
      from_port   = 3389
      to_port     = 3389
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"] # RDP from VPC
      description = "RDP from VPC"
    },
    {
      from_port   = 5985
      to_port     = 5986
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"] # WinRM for PowerShell remoting
      description = "WinRM from VPC"
    }
  ]

  # Windows requires broad egress for proper operation
  restrict_egress = true
  custom_egress_rules = [
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"] # HTTPS to internet for Windows Updates
      description = "HTTPS to internet for Windows Updates"
    },
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"] # HTTP for some Windows services
      description = "HTTP to internet for Windows services"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"] # HTTPS to VPC endpoints
      description = "HTTPS to VPC endpoints"
    },
    {
      from_port   = 53
      to_port     = 53
      protocol    = "udp"
      cidr_blocks = ["0.0.0.0/0"] # DNS resolution
      description = "DNS resolution"
    },
    {
      from_port   = 53
      to_port     = 53
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"] # DNS over TCP
      description = "DNS over TCP"
    },
    {
      from_port   = 123
      to_port     = 123
      protocol    = "udp"
      cidr_blocks = ["0.0.0.0/0"] # NTP for time synchronization
      description = "NTP time synchronization"
    }
  ]

  # Storage Configuration - Windows needs more space
  volume_size           = 50
  volume_type           = "gp3"
  enable_ebs_encryption = true

  # Monitoring
  enable_detailed_monitoring = true
  enable_cloudwatch_agent    = true

  # Instance Security
  key_name                = "my-windows-key"
  disable_api_termination = true

  # Windows-specific user data for initial setup
  user_data = base64encode(<<-EOF
    <powershell>
    # Enable PSRemoting
    Enable-PSRemoting -Force
    
    # Configure Windows Firewall for SSM
    New-NetFirewallRule -DisplayName "Allow SSM" -Direction Inbound -Protocol TCP -LocalPort 443 -Action Allow
    
    # Set timezone
    Set-TimeZone -Id "Eastern Standard Time"
    
    # Install Windows Updates PowerShell module
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    Install-Module -Name PSWindowsUpdate -Force
    
    # Log completion
    Write-Output "Windows instance initialization completed" | Out-File C:\temp\init-complete.log
    </powershell>
    EOF
  )

  # Tags
  tags = {
    Environment    = "Production"
    Application    = "Windows-App"
    Owner          = "DevOps"
    NetworkTier    = "private"
    SSMEnabled     = "true"
    InternetAccess = "nat-gateway"
    OS             = "Windows"
  }
}
