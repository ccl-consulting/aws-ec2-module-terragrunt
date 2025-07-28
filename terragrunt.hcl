
# Example Terragrunt configuration for deploying an EC2 instance

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git::https://github.com/ccl-consulting/aws-ec2-module-terragrunt.git?ref=v0.0.1"
}

inputs = {
  # Instance Details
  instance_name    = "example-instance"
  instance_type    = "t3.micro"
  operating_system = "linux" # change to "windows" if needed

  # AWS Configuration
  aws_region      = "us-east-1"
  assume_role_arn = "arn:aws:iam::123456789012:role/TerraformRole" # CHANGE THIS

  # AMI Options
  custom_ami_id = null # Specify your custom AMI ID or leave null
  ami_owners    = ["amazon"]

  # Network Configuration
  vpc_id         = null # Use default VPC, or specify your VPC
  subnet_id      = null # Automatically select a default subnet
  private_subnet = false

  # Security Configuration - IMPORTANT: Restrict SSH access!
  allowed_ssh_cidrs = [] # CHANGE THIS: Add your specific IP/CIDR blocks
  # Example: allowed_ssh_cidrs = ["203.0.113.0/24", "198.51.100.0/24"]
  security_group_name = null # Auto-generate name from instance name

  # Elastic IP
  create_eip = true

  # KMS Configuration
  enable_ebs_encryption = true
  kms_key_id            = null # Specify KMS key, if required

  # Monitoring
  enable_detailed_monitoring = false
  enable_cloudwatch_agent    = true

  # Storage Configuration
  volume_size = 10
  volume_type = "gp3"

  # Tags
  tags = {
    Environment = "Development"
    Application = "ExampleApp"
  }
}
