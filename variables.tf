# Type of EC2 instance (default: t3.micro)
variable "instance_type" {
  type        = string
  default     = "t3.micro"
  description = "The instance type to launch"
}

# Used as a tag for the instance and for DNS registration
variable "instance_name" {
  type        = string
  description = "The logical customer or instance name"
}

# Name of the Route53 hosted zone to associate with the instance
variable "hosted_zone_name" {
  type        = string
  description = "The Route53 hosted zone where the instance will be registered"
  default     = "example.com" # Replace with your actual hosted zone name
}

variable "aws_region" {
  type = string
}

variable "assume_role_arn" {
  type = string
}

variable "tags" {
  type        = map(string)
  description = "Additional tags to apply to the EC2 instance"
  default     = {}
}

variable "volume_type" {
  type        = string
  description = "The type of volume to create"
  default     = "gp3"
  validation {
    condition     = contains(["gp2", "gp3", "io1", "io2"], var.volume_type)
    error_message = "Volume type must be one of: gp2, gp3, io1, io2."
  }
}

variable "volume_size" {
  type        = number
  description = "The size of the volume in GiB"
  default     = 8
  validation {
    condition     = var.volume_size >= 8 && var.volume_size <= 16384
    error_message = "Volume size must be between 8 and 16384 GiB."
  }
}

variable "iam_role_name" {
  description = "Name of the IAM role to attach to EC2 instance for SSM and CloudWatch"
  type        = string
  default     = "ec2-instance-role"
}

# =============================================================================
# NEW VARIABLES FOR ENHANCED FEATURES
# =============================================================================

# Operating System Configuration
variable "operating_system" {
  type        = string
  description = "Operating system type (linux or windows)"
  default     = "linux"
  validation {
    condition     = contains(["linux", "windows"], var.operating_system)
    error_message = "Operating system must be either 'linux' or 'windows'."
  }
}

variable "custom_ami_id" {
  type        = string
  description = "Custom AMI ID to use instead of the default. If not provided, latest AMI for the selected OS will be used"
  default     = null
}

variable "ami_owners" {
  type        = list(string)
  description = "List of AMI owners to consider when selecting AMI"
  default     = ["amazon"]
}

# Network Configuration
variable "vpc_id" {
  type        = string
  description = "VPC ID where the instance will be deployed. If not provided, default VPC will be used"
  default     = null
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID where the instance will be deployed. If not provided, a public subnet from default VPC will be used"
  default     = null
}

variable "private_subnet" {
  type        = bool
  description = "Whether to deploy in a private subnet (no public IP)"
  default     = false
}

# Security Group Configuration
variable "security_group_name" {
  type        = string
  description = "Name for the security group"
  default     = null
}

variable "allowed_ssh_cidrs" {
  type        = list(string)
  description = "List of CIDR blocks allowed for SSH access (port 22)"
  default     = []
}

variable "allowed_rdp_cidrs" {
  type        = list(string)
  description = "List of CIDR blocks allowed for RDP access (port 3389) - Windows only"
  default     = []
}

variable "allowed_http_cidrs" {
  type        = list(string)
  description = "List of CIDR blocks allowed for HTTP access (port 80)"
  default     = []
}

variable "allowed_https_cidrs" {
  type        = list(string)
  description = "List of CIDR blocks allowed for HTTPS access (port 443)"
  default     = []
}

variable "custom_ingress_rules" {
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = string
  }))
  description = "List of custom ingress rules"
  default     = []
}

variable "custom_egress_rules" {
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = string
  }))
  description = "List of custom egress rules. If empty, default egress (all outbound) will be used"
  default     = []
}

variable "restrict_egress" {
  type        = bool
  description = "Whether to restrict egress traffic (if true, only specified egress rules will be allowed)"
  default     = false
}

# Elastic IP Configuration
variable "create_eip" {
  type        = bool
  description = "Whether to create and associate an Elastic IP"
  default     = true
}

# KMS Encryption
variable "enable_ebs_encryption" {
  type        = bool
  description = "Whether to enable EBS encryption"
  default     = true
}

variable "kms_key_id" {
  type        = string
  description = "KMS key ID for EBS encryption. If not provided, a new key will be created"
  default     = null
}

variable "kms_key_deletion_window" {
  type        = number
  description = "Number of days to wait before deleting KMS key (7-30 days)"
  default     = 7
  validation {
    condition     = var.kms_key_deletion_window >= 7 && var.kms_key_deletion_window <= 30
    error_message = "KMS key deletion window must be between 7 and 30 days."
  }
}

# Monitoring and Logging
variable "enable_detailed_monitoring" {
  type        = bool
  description = "Whether to enable detailed monitoring for the instance"
  default     = false
}

variable "enable_cloudwatch_agent" {
  type        = bool
  description = "Whether to install and configure CloudWatch agent"
  default     = true
}

# Instance Configuration
variable "associate_public_ip_address" {
  type        = bool
  description = "Whether to associate a public IP address with the instance"
  default     = null # Will be determined based on subnet type if not specified
}

variable "key_name" {
  type        = string
  description = "Name of the AWS key pair to use for the instance"
  default     = null
}

variable "user_data" {
  type        = string
  description = "User data script to run on instance initialization"
  default     = null
}

variable "disable_api_termination" {
  type        = bool
  description = "Whether to enable termination protection"
  default     = false
}

variable "create_vpc_endpoints" {
  description = "Whether to create VPC endpoints for SSM"
  type        = bool
  default     = true
}

variable "vpc_endpoint_subnet_ids" {
  description = "Subnet IDs for VPC endpoints (defaults to instance subnet)"
  type        = list(string)
  default     = null
}

variable "create_private_route_table" {
  description = "Whether to create a private route table for the subnet (removes internet gateway route)"
  type        = bool
  default     = false
}

variable "nat_gateway_id" {
  description = "NAT Gateway ID for private subnet route table (optional, for outbound internet access)"
  type        = string
  default     = null
}
