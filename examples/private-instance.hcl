# Example: Private Instance with No Public IP and Restricted Access

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git::https://github.com/ccl-consulting/aws-ec2-module-terragrunt.git?ref=v0.0.1"
}

inputs = {
  # Instance Configuration
  instance_name    = "private-database-server"
  instance_type    = "t3.medium"
  operating_system = "linux"

  # Network Configuration - Private subnet
  aws_region     = "us-east-1"
  vpc_id         = "vpc-private123"
  subnet_id      = "subnet-private123"
  private_subnet = true

  # No Elastic IP for private instance
  create_eip = false

  # Security - No direct internet access
  # Only allow access from within VPC
  custom_ingress_rules = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"] # Only VPC CIDR
      description = "SSH from VPC"
    },
    {
      from_port   = 3306
      to_port     = 3306
      protocol    = "tcp"
      cidr_blocks = ["10.0.1.0/24"] # Application subnet
      description = "MySQL from app servers"
    }
  ]

  # Restricted egress - only necessary outbound traffic
  restrict_egress = true
  custom_egress_rules = [
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTPS for updates"
    },
    {
      from_port   = 53
      to_port     = 53
      protocol    = "udp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "DNS"
    },
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTP for package updates"
    }
  ]

  # Storage Configuration - Encrypted database storage
  volume_size           = 100
  volume_type           = "gp3"
  enable_ebs_encryption = true

  # Monitoring
  enable_detailed_monitoring = true
  enable_cloudwatch_agent    = true

  # Instance Security
  key_name                = "private-db-key"
  disable_api_termination = true

  # User data for database setup
  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y mysql-server
    systemctl start mysqld
    systemctl enable mysqld
  EOF
  )

  # Tags
  tags = {
    Environment = "Production"
    Application = "Database"
    Owner       = "DatabaseTeam"
    Backup      = "true"
    Security    = "high"
    NetworkTier = "private"
  }
}
