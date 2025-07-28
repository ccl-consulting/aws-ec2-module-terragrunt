# Example: Secure Linux Web Server with Custom VPC

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "git::https://github.com/your-org/aws-ec2-module-terragrunt.git"
}

inputs = {
  # Instance Configuration
  instance_name    = "secure-web-server"
  instance_type    = "t3.small"
  operating_system = "linux"

  # Custom AMI (if you have a hardened image)
  # custom_ami_id = "ami-0abcdef1234567890"

  # Network Configuration
  aws_region = "eu-west-1"
  vpc_id     = "vpc-87654321"
  subnet_id  = "subnet-87654321"

  # Security Configuration
  security_group_name = "secure-web-sg"

  # Allow SSH only from specific IPs
  allowed_ssh_cidrs = [
    "203.0.113.0/24" # Admin network
  ]

  # Allow HTTP/HTTPS from anywhere
  allowed_http_cidrs  = ["0.0.0.0/0"]
  allowed_https_cidrs = ["0.0.0.0/0"]

  # Custom application ports
  custom_ingress_rules = [
    {
      from_port   = 8443
      to_port     = 8443
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/8"]
      description = "Management interface"
    }
  ]

  # Storage Configuration
  volume_size           = 20
  volume_type           = "gp3"
  enable_ebs_encryption = true

  # Use existing KMS key for encryption
  kms_key_id = "arn:aws:kms:eu-west-1:123456789012:key/12345678-1234-1234-1234-123456789012"

  # Monitoring and Logging
  enable_detailed_monitoring = true
  enable_cloudwatch_agent    = true

  # Instance Options
  key_name                = "web-server-key"
  disable_api_termination = true
  create_eip              = true

  # User data script for initial setup
  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>Secure Web Server</h1>" > /var/www/html/index.html
  EOF
  )

  # Tags
  tags = {
    Environment = "Production"
    Application = "WebServer"
    Owner       = "WebTeam"
    Backup      = "true"
    Security    = "high"
  }
}
