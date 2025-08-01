# Example: Fleet Manager Enabled Instance
# This example shows how to deploy an EC2 instance with full Fleet Manager capabilities
# including Session Manager, file system access, user management, and Windows Registry management

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git::https://github.com/ccl-consulting/aws-ec2-module-terragrunt.git?ref=v0.0.1"
}

inputs = {
  # Instance Configuration
  instance_name    = "fleet-manager-instance"
  instance_type    = "t3.medium" # Slightly larger for Fleet Manager operations
  operating_system = "windows"   # Fleet Manager works great with Windows

  # Network Configuration
  aws_region     = "us-east-1"
  vpc_id         = "vpc-12345678"
  subnet_id      = "subnet-12345678"
  private_subnet = false # Public subnet for easier access initially

  # Enable Elastic IP for consistent access
  create_eip = true

  # Enable VPC endpoints for SSM (recommended for private communication)
  create_vpc_endpoints = true

  # Fleet Manager Configuration - FULL ADMIN ACCESS
  enable_fleet_manager         = true
  fleet_manager_access_level   = "admin" # Full administrative access
  enable_session_manager       = true

  # Session Manager Logging Configuration
  session_manager_s3_bucket           = "my-session-manager-logs-bucket"
  session_manager_s3_key_prefix       = "fleet-manager-sessions/"
  session_manager_cloudwatch_log_group = "/aws/ssm/fleet-manager/sessions"

  # Enhanced SSM Features
  enable_patch_manager = true
  patch_group         = "fleet-manager-windows-group"
  enable_compliance   = true
  enable_inventory    = true
  inventory_schedule  = "rate(1 day)" # Daily inventory for better visibility

  # Default Host Management (automatic SSM registration)
  enable_default_host_management = true

  # Security Configuration
  custom_ingress_rules = [
    {
      from_port   = 3389
      to_port     = 3389
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"] # RDP access from VPC
      description = "RDP access for Windows"
    },
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"] # HTTP for web applications
      description = "HTTP access"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"] # HTTPS for web applications
      description = "HTTPS access"
    }
  ]

  # Storage Configuration
  volume_size           = 50 # Larger volume for Windows and applications
  volume_type           = "gp3"
  enable_ebs_encryption = true

  # Monitoring
  enable_detailed_monitoring = true
  enable_cloudwatch_agent    = true

  # Instance Security
  key_name                = "my-fleet-manager-key"
  disable_api_termination = false # Allow termination for testing

  # Tags for better organization and Fleet Manager filtering
  tags = {
    Environment     = "Development"
    Application     = "Fleet-Manager-Demo"
    Owner          = "DevOps-Team"
    FleetManager   = "enabled"
    AdminAccess    = "true"
    SessionManager = "enabled"
    PatchGroup     = "fleet-manager-windows-group"
    Purpose        = "Fleet-Manager-Testing"
  }
}
