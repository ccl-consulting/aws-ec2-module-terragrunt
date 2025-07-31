# Example: Private Instance with NAT Gateway for Internet Access
# This example creates a NAT Gateway to provide outbound internet access
# for private subnet instances while maintaining SSM connectivity.

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git::https://github.com/ccl-consulting/aws-ec2-module-terragrunt.git?ref=v0.0.2"
}

inputs = {
  # Instance Configuration
  instance_name    = "private-instance-with-nat"
  instance_type    = "t3.micro"
  operating_system = "linux"

  # Network Configuration - Private subnet
  aws_region     = "us-east-1"
  vpc_id         = "vpc-12345678"
  subnet_id      = "subnet-private123"  # Your private subnet
  private_subnet = true

  # NAT Gateway Configuration
  create_nat_gateway     = true
  nat_gateway_subnet_id  = "subnet-public456"  # Must be a public subnet in same VPC
  
  # Optional: Use existing Elastic IP for NAT Gateway (otherwise new EIP is created)
  # nat_gateway_allocation_id = "eipalloc-0123456789abcdef0"

  # CRITICAL: Create a private route table to remove internet gateway route
  create_private_route_table = true

  # No Elastic IP for the instance itself (it's private)
  create_eip = false

  # Enable VPC endpoints for SSM (RECOMMENDED for private instances)
  create_vpc_endpoints = true
  # Optional: Specify different subnets for VPC endpoints (e.g., multiple AZs)
  # vpc_endpoint_subnet_ids = ["subnet-private123", "subnet-private789"]

  # Security Configuration - Allow outbound HTTPS for updates and SSM
  custom_ingress_rules = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"] # Only VPC CIDR
      description = "SSH from VPC"
    }
  ]

  # Allow broader egress for Windows Updates, SSM agent updates, etc.
  restrict_egress = true
  custom_egress_rules = [
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"] # Internet access via NAT Gateway
      description = "HTTPS to internet via NAT Gateway"
    },
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"] # HTTP access for package updates
      description = "HTTP to internet via NAT Gateway"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"] # Also allow VPC endpoints
      description = "HTTPS to VPC endpoints"
    },
    {
      from_port   = 53
      to_port     = 53
      protocol    = "udp"
      cidr_blocks = ["10.0.0.0/16"] # DNS within VPC
      description = "DNS resolution"
    },
    {
      from_port   = 53
      to_port     = 53
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"] # DNS over TCP to internet
      description = "DNS over TCP to internet"
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
    Environment    = "Production"
    Application    = "Private-App"
    Owner          = "DevOps"
    NetworkTier    = "private"
    SSMEnabled     = "true"
    InternetAccess = "nat-gateway"
  }
}
