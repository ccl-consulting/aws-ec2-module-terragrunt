# Example: Windows Server Instance with Enhanced Security

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git::https://github.com/ccl-consulting/aws-ec2-module-terragrunt.git?ref=v0.0.1"
}

inputs = {
  # Instance Configuration
  instance_name    = "windows-server-01"
  instance_type    = "t3.medium"
  operating_system = "windows"

  # Network Configuration
  aws_region = "us-west-2"
  vpc_id     = "vpc-12345678"
  subnet_id  = "subnet-12345678"

  # Security Configuration - Restrict RDP access
  allowed_rdp_cidrs = [
    "10.0.0.0/8",    # Corporate network
    "203.0.113.0/24" # Admin access
  ]

  # Custom security rules for application ports
  custom_ingress_rules = [
    {
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/8"]
      description = "Application port from internal network"
    }
  ]

  # Restrict egress traffic
  restrict_egress = true
  custom_egress_rules = [
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTPS outbound"
    },
    {
      from_port   = 53
      to_port     = 53
      protocol    = "udp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "DNS outbound"
    }
  ]

  # Storage and Encryption
  volume_size           = 50
  volume_type           = "gp3"
  enable_ebs_encryption = true

  # Monitoring
  enable_detailed_monitoring = true
  enable_cloudwatch_agent    = true

  # Instance Options
  key_name                = "my-windows-key"
  disable_api_termination = true
  create_eip              = true

  # Tags
  tags = {
    Environment = "Production"
    OS          = "Windows"
    Application = "WebServer"
    Owner       = "DevOps"
    Backup      = "true"
  }
}
