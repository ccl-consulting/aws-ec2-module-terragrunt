
# Example Terragrunt configuration for deploying an EC2 instance

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git::https://github.com/your-org/aws-ec2-module-terragrunt.git"
}

inputs = {
  # Instance Details
  instance_name     = "example-instance"
  instance_type     = "t3.micro"
  operating_system  = "linux" # change to "windows" if needed

  # AMI Options
  custom_ami_id    = null # Specify your custom AMI ID or leave null
  ami_owners       = ["amazon"]

  # Network Configuration
  aws_region        = "us-east-1"
  vpc_id            = null # Use default VPC, or specify your VPC
  subnet_id         = null # Automatically select a default subnet
  private_subnet    = false

  # Security Configuration
  allowed_ssh_cidrs = ["0.0.0.0/0"] # Customize to restrict SSH access
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
