# Example: Private Instance with SSM Connectivity (VPC Endpoints Only)
# This example shows how to deploy a private instance that can connect to SSM
# without internet gateway routes and without NAT Gateway (most secure).
#
# IMPORTANT: For Windows instances or instances requiring internet access for:
# - Windows Updates
# - Package updates (yum, apt, etc.)
# - Certificate validation  
# - SSM agent updates
# Consider using the 'private-instance-with-nat-gateway.hcl' example instead.

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git::https://github.com/ccl-consulting/aws-ec2-module-terragrunt.git?ref=v0.0.1"
}

inputs = {
  # Instance Configuration
  instance_name    = "private-ssm-instance"
  instance_type    = "t3.micro"
  operating_system = "linux"

  # Custom AMI ID (example for SQL Server)
  # custom_ami_id = "ami-0abcdef1234567890"  # Use your specific AMI ID

  # Network Configuration - Private subnet
  aws_region     = "us-east-1"
  vpc_id         = "vpc-12345678"
  subnet_id      = "subnet-private123"
  private_subnet = true

  # CRITICAL: Create a private route table to remove internet gateway route
  create_private_route_table = true
  
  # Optional: If you need outbound internet access, provide NAT Gateway ID
  # nat_gateway_id = "nat-0123456789abcdef0"

  # No Elastic IP for private instance
  create_eip = false

  # Enable VPC endpoints for SSM (REQUIRED for private instances)
  create_vpc_endpoints = true
  # Optional: Specify different subnets for VPC endpoints
  # vpc_endpoint_subnet_ids = ["subnet-endpoint1", "subnet-endpoint2"]

  # Enable Fleet Manager and SSM capabilities
  enable_fleet_manager = true
  fleet_manager_access_level = "admin" # Change to "readonly" if needed
  enable_session_manager = true

  # Configure logging for Session Manager
  session_manager_s3_bucket = "my-ssm-logs" # Specify your S3 bucket name
  session_manager_cloudwatch_log_group = "/aws/ssm/SessionManager"

  # Additional configurations
  enable_patch_manager = true
  patch_group = "prod-patch-group"
  enable_compliance = true
  enable_inventory = true
  inventory_schedule = "rate(30 days)"

  # Security Configuration
  custom_ingress_rules = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"] # Only VPC CIDR
      description = "SSH from VPC"
    }
  ]
  # Restrict egress - only necessary outbound traffic for VPC endpoints
  restrict_egress = true
  custom_egress_rules = [
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"] # Only to VPC endpoints
      description = "HTTPS to VPC endpoints"
    },
    {
      from_port   = 53
      to_port     = 53
      protocol    = "udp"
      cidr_blocks = ["10.0.0.0/16"] # DNS within VPC
      description = "DNS resolution"
    }
  ]

  # Storage Configuration
  volume_size           = 20
  volume_type           = "gp3"
  enable_ebs_encryption = true

  # Monitoring
  enable_detailed_monitoring = true
  enable_cloudwatch_agent    = true

  # Instance Security
  key_name                = "my-private-key"
  disable_api_termination = true

  # Tags
  tags = {
    Environment = "Production"
    Application = "Database"
    Owner       = "DevOps"
    NetworkTier = "private"
    SSMEnabled  = "true"
  }
}
