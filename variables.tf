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
# New variables to add to the module
variable "vpc_endpoint_ssm_id" {
  description = "Existing SSM VPC endpoint ID to use (optional)"
  type        = string
  default     = null
}

variable "vpc_endpoint_ec2messages_id" {
  description = "Existing EC2Messages VPC endpoint ID to use (optional)"
  type        = string
  default     = null
}

variable "vpc_endpoint_ssmmessages_id" {
  description = "Existing SSMMessages VPC endpoint ID to use (optional)"
  type        = string
  default     = null
}

variable "create_shared_vpc_endpoints" {
  description = "Create VPC endpoints (only set to true for one instance per VPC)"
  type        = bool
  default     = false
}
variable "vpc_endpoint_subnet_ids" {
  description = "Subnet IDs for VPC endpoints (defaults to instance subnet)"
  type        = list(string)
  default     = null
}

variable "check_for_existing_vpc_endpoints" {
  description = "Whether to check for existing VPC endpoints before creating new ones"
  type        = bool
  default     = true
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

variable "create_nat_gateway" {
  description = "Whether to create a NAT Gateway for outbound internet access from private subnet"
  type        = bool
  default     = false
}

variable "nat_gateway_subnet_id" {
  description = "Subnet ID for NAT Gateway (must be a public subnet). Required if create_nat_gateway is true"
  type        = string
  default     = null
}

variable "nat_gateway_allocation_id" {
  description = "Allocation ID of existing Elastic IP for NAT Gateway. If not provided, a new EIP will be created"
  type        = string
  default     = null
}

# =============================================================================
# FLEET MANAGER AND ENHANCED SSM VARIABLES
# =============================================================================

variable "enable_fleet_manager" {
  description = "Whether to enable Fleet Manager capabilities with enhanced IAM permissions"
  type        = bool
  default     = false
}

variable "fleet_manager_access_level" {
  description = "Fleet Manager access level: 'admin' for full access, 'readonly' for read-only access"
  type        = string
  default     = "readonly"
  validation {
    condition     = contains(["admin", "readonly"], var.fleet_manager_access_level)
    error_message = "Fleet Manager access level must be either 'admin' or 'readonly'."
  }
}

variable "enable_session_manager" {
  description = "Whether to enable Session Manager for browser-based shell access"
  type        = bool
  default     = true
}

variable "session_manager_s3_bucket" {
  description = "S3 bucket name for Session Manager logs (optional)"
  type        = string
  default     = null
}

variable "session_manager_s3_key_prefix" {
  description = "S3 key prefix for Session Manager logs"
  type        = string
  default     = "session-manager-logs/"
}

variable "session_manager_cloudwatch_log_group" {
  description = "CloudWatch log group name for Session Manager logs (optional)"
  type        = string
  default     = null
}

variable "enable_patch_manager" {
  description = "Whether to enable Patch Manager for automated patching"
  type        = bool
  default     = false
}

variable "patch_group" {
  description = "Patch group name for Patch Manager"
  type        = string
  default     = "default"
}

variable "enable_compliance" {
  description = "Whether to enable Systems Manager Compliance"
  type        = bool
  default     = false
}

variable "enable_inventory" {
  description = "Whether to enable Systems Manager Inventory collection"
  type        = bool
  default     = true
}

variable "inventory_schedule" {
  description = "Cron expression for inventory collection schedule"
  type        = string
  default     = "rate(30 days)"
}

variable "enable_association_compliance_severity" {
  description = "Compliance severity level for associations"
  type        = string
  default     = "UNSPECIFIED"
  validation {
    condition     = contains(["CRITICAL", "HIGH", "MEDIUM", "LOW", "INFORMATIONAL", "UNSPECIFIED"], var.enable_association_compliance_severity)
    error_message = "Compliance severity must be one of: CRITICAL, HIGH, MEDIUM, LOW, INFORMATIONAL, UNSPECIFIED."
  }
}

variable "custom_ssm_documents" {
  description = "List of custom SSM documents to create for this instance"
  type = list(object({
    name            = string
    document_type   = string
    document_format = string
    content         = string
    tags            = optional(map(string), {})
  }))
  default = []
}

variable "ssm_associations" {
  description = "List of SSM associations to create for this instance"
  type = list(object({
    name                        = string
    schedule_expression         = optional(string)
    parameters                  = optional(map(string), {})
    compliance_severity         = optional(string, "UNSPECIFIED")
    max_concurrency             = optional(string, "1")
    max_errors                  = optional(string, "0")
    apply_only_at_cron_interval = optional(bool, false)
  }))
  default = []
}

variable "enable_default_host_management" {
  description = "Whether to enable Default Host Management Configuration for EC2 instances"
  type        = bool
  default     = false
}

# =============================================================================
# SESSION MANAGER ENHANCED PERMISSIONS
# =============================================================================

variable "enable_session_manager_permissions" {
  description = "Whether to add enhanced Session Manager permissions for ssmmessages and S3 access"
  type        = bool
  default     = true
}

# =============================================================================
# KEY PAIR CREATION FOR WINDOWS INSTANCES
# =============================================================================

variable "create_key_pair" {
  description = "Whether to create a new key pair for the instance (required for Windows password retrieval)"
  type        = bool
  default     = false
}

variable "key_pair_name" {
  description = "Name for the created key pair. If not provided, will use instance_name-key"
  type        = string
  default     = null
}

variable "public_key" {
  description = "Public key material to use for key pair creation. If not provided, a key pair will be generated"
  type        = string
  default     = null
  sensitive   = false
}

variable "save_private_key" {
  description = "Whether to save the generated private key to SSM Parameter Store (only when generating key pair)"
  type        = bool
  default     = true
}

# =============================================================================
# ADDITIONAL VPC ENDPOINTS FOR COMPLETE SSM FUNCTIONALITY
# =============================================================================

variable "create_s3_vpc_endpoint" {
  description = "Whether to create S3 VPC endpoint for Session Manager S3 logging"
  type        = bool
  default     = false
}

variable "create_kms_vpc_endpoint" {
  description = "Whether to create KMS VPC endpoint for Session Manager encryption"
  type        = bool
  default     = false
}

variable "create_logs_vpc_endpoint" {
  description = "Whether to create CloudWatch Logs VPC endpoint for Session Manager logging"
  type        = bool
  default     = false
}

variable "create_monitoring_vpc_endpoint" {
  description = "Whether to create CloudWatch Monitoring VPC endpoint for metrics"
  type        = bool
  default     = false
}

variable "enable_private_dns" {
  description = "Whether to enable private DNS resolution for VPC endpoints"
  type        = bool
  default     = true
}

variable "s3_vpc_endpoint_route_table_ids" {
  description = "Route table IDs for S3 gateway VPC endpoint (required if create_s3_vpc_endpoint is true)"
  type        = list(string)
  default     = null
}
