# Example: Production-Ready Secure Instance Configuration
# This example follows security best practices

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git::https://github.com/ccl-consulting/aws-ec2-module-terragrunt.git?ref=v1.0.0"
}

# Use dependency to get VPC/subnet information dynamically
# dependency "vpc" {
#   config_path = "../vpc"
# }

inputs = {
  # Instance Configuration
  instance_name    = "prod-web-server"
  instance_type    = "t3.small"
  operating_system = "linux"
  
  # AWS Configuration - Use variables or dependency outputs
  aws_region      = "us-west-2"
  assume_role_arn = "arn:aws:iam::${get_aws_account_id()}:role/TerraformExecutionRole"
  
  # Network Configuration - Use dependency outputs in real scenarios
  # vpc_id    = dependency.vpc.outputs.vpc_id
  # subnet_id = dependency.vpc.outputs.private_subnet_ids[0]
  vpc_id         = null # Will use default VPC
  subnet_id      = null # Will auto-select subnet
  private_subnet = false
  
  # Security Configuration - Restrictive by design
  security_group_name = "prod-web-server-sg"
  
  # SSH access only from bastion host or VPN
  allowed_ssh_cidrs = [
    "10.0.100.0/24" # Bastion subnet
  ]
  
  # Web traffic from load balancer subnet only
  allowed_http_cidrs  = ["10.0.0.0/24"]  # ALB subnet
  allowed_https_cidrs = ["10.0.0.0/24"]  # ALB subnet
  
  # Custom rules for application monitoring
  custom_ingress_rules = [
    {
      from_port   = 9090
      to_port     = 9090
      protocol    = "tcp"
      cidr_blocks = ["10.0.200.0/24"] # Monitoring subnet
      description = "Prometheus metrics"
    }
  ]
  
  # Restrict egress to only necessary services
  restrict_egress = true
  custom_egress_rules = [
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTPS for package updates and API calls"
    },
    {
      from_port   = 53
      to_port     = 53
      protocol    = "udp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "DNS resolution"
    },
    {
      from_port   = 3306
      to_port     = 3306
      protocol    = "tcp"
      cidr_blocks = ["10.0.50.0/24"] # Database subnet
      description = "Database access"
    }
  ]
  
  # Storage Configuration
  volume_size           = 30
  volume_type           = "gp3"
  enable_ebs_encryption = true
  # Use organization's KMS key
  # kms_key_id = "arn:aws:kms:us-west-2:123456789012:key/12345678-1234-1234-1234-123456789012"
  
  # Production Monitoring
  enable_detailed_monitoring = true
  enable_cloudwatch_agent    = true
  
  # Instance Security
  key_name                = "prod-web-server-key"
  disable_api_termination = true
  create_eip              = false # Use ALB instead
  
  # User data from file (better security practice)
  # user_data = filebase64("${get_parent_terragrunt_dir()}/user-data/web-server-init.sh")
  
  # Comprehensive tagging for governance
  tags = {
    Environment        = "Production"
    Application        = "WebServer"
    Owner             = "WebTeam"
    CostCenter        = "Engineering"
    Backup            = "true"
    Monitoring        = "true"
    Security          = "high"
    DataClassification = "internal"
    Compliance        = "SOC2"
  }
}
