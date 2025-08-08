terraform {
  backend "s3" {}
}

# =============================================================================
# DATA SOURCES
# =============================================================================

# Needed for Chine partition (i.e. :aws-cn:)
data "aws_partition" "current" {}

# Linux AMI data source
data "aws_ami" "linux" {
  count       = var.operating_system == "linux" && var.custom_ami_id == null ? 1 : 0
  most_recent = true
  owners      = var.ami_owners

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# Windows AMI data source
data "aws_ami" "windows" {
  count       = var.operating_system == "windows" && var.custom_ami_id == null ? 1 : 0
  most_recent = true
  owners      = var.ami_owners

  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# Get VPC information
data "aws_vpc" "selected" {
  id      = var.vpc_id
  default = var.vpc_id == null ? true : null
}

# Get subnet information if subnet_id is provided
data "aws_subnet" "selected" {
  count = var.subnet_id != null ? 1 : 0
  id    = var.subnet_id
}

# Get default subnets if no subnet is specified
data "aws_subnets" "default" {
  count = var.subnet_id == null ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

# Get current caller identity for KMS key policy
data "aws_caller_identity" "current" {}

# Get current region
data "aws_region" "current" {}

# =============================================================================
# LOCALS
# =============================================================================

locals {
  # Determine which AMI to use
  ami_id = var.custom_ami_id != null ? var.custom_ami_id : (
    var.operating_system == "linux" ? data.aws_ami.linux[0].id : data.aws_ami.windows[0].id
  )

  # Determine subnet to use
  subnet_id = var.subnet_id != null ? var.subnet_id : data.aws_subnets.default[0].ids[0]

  # Determine if public IP should be associated
  associate_public_ip = var.associate_public_ip_address != null ? var.associate_public_ip_address : (
    var.private_subnet ? false : true
  )

  # Security group name
  security_group_name = var.security_group_name != null ? var.security_group_name : "${var.instance_name}-sg"

  # KMS key to use
  kms_key_id = var.enable_ebs_encryption ? (
    var.kms_key_id != null ? var.kms_key_id : aws_kms_key.ebs[0].arn
  ) : null

  # Determine NAT Gateway ID to use - prefer created NAT Gateway over provided ID
  nat_gateway_id = var.create_nat_gateway ? aws_nat_gateway.this[0].id : var.nat_gateway_id

  # VPC endpoint existence checks using try() to handle errors gracefully
  existing_ssm_endpoint_exists = var.create_vpc_endpoints && var.check_for_existing_vpc_endpoints ? (
    try(data.aws_vpc_endpoint.existing_ssm[0].id, null) != null
  ) : false
  existing_ec2messages_endpoint_exists = var.create_vpc_endpoints && var.check_for_existing_vpc_endpoints ? (
    try(data.aws_vpc_endpoint.existing_ec2messages[0].id, null) != null
  ) : false
  existing_ssmmessages_endpoint_exists = var.create_vpc_endpoints && var.check_for_existing_vpc_endpoints ? (
    try(data.aws_vpc_endpoint.existing_ssmmessages[0].id, null) != null
  ) : false

  # Determine if we need to create security group for VPC endpoints
  create_vpc_endpoint_sg = var.create_vpc_endpoints && (
    var.check_for_existing_vpc_endpoints ? (
      !local.existing_ssm_endpoint_exists ||
      !local.existing_ec2messages_endpoint_exists ||
      !local.existing_ssmmessages_endpoint_exists
    ) : true
  )

  # User data script to ensure SSM agent is installed and running
  user_data_with_ssm = var.user_data != null ? var.user_data : (
    var.operating_system == "linux" ? base64encode(templatefile("${path.module}/user_data/linux_ssm.sh", {
      region = data.aws_region.current.region
      })) : base64encode(templatefile("${path.module}/user_data/windows_ssm.ps1", {
      region = data.aws_region.current.region
      s3Domain  = contains(["cn-north-1", "cn-northwest-1"], data.aws_region.current.region) ? "amazonaws.com.cn" : "amazonaws.com"
      ssmDomain = contains(["cn-north-1", "cn-northwest-1"], data.aws_region.current.region) ? "amazonaws.com.cn" : "amazonaws.com"
    }))
  )
}

# =============================================================================
# KMS KEY FOR EBS ENCRYPTION
# =============================================================================

resource "aws_kms_key" "ebs" {
  count                   = var.enable_ebs_encryption && var.kms_key_id == null ? 1 : 0
  description             = "KMS key for EBS encryption - ${var.instance_name}"
  deletion_window_in_days = var.kms_key_deletion_window
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow EC2 Service"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey*",
          "kms:CreateGrant",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(
    {
      Name = "${var.instance_name}-ebs-key"
    },
    var.tags
  )
}

resource "aws_kms_alias" "ebs" {
  count         = var.enable_ebs_encryption && var.kms_key_id == null ? 1 : 0
  name          = "alias/${var.instance_name}-ebs-key"
  target_key_id = aws_kms_key.ebs[0].key_id
}

resource "aws_kms_key" "cloudwatch" {
  count                   = var.enable_cloudwatch_agent ? 1 : 0
  description             = "KMS key for CloudWatch Agent - ${var.instance_name}"
  deletion_window_in_days = var.kms_key_deletion_window
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow SSM Parameter Store"
        Effect = "Allow"
        Principal = {
          Service = "ssm.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey*",
          "kms:CreateGrant",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(
    {
      Name = "${var.instance_name}-parameter-store-key"
    },
    var.tags
  )
}

resource "aws_kms_alias" "cloudwatch" {
  count         = var.enable_cloudwatch_agent ? 1 : 0
  name          = "alias/${var.instance_name}-parameter-store-key"
  target_key_id = aws_kms_key.cloudwatch[0].key_id
}


# =============================================================================
# EC2 INSTANCE
# =============================================================================

resource "aws_instance" "this" {
  ami                         = local.ami_id
  instance_type               = var.instance_type
  subnet_id                   = local.subnet_id
  vpc_security_group_ids      = [aws_security_group.this.id]
  associate_public_ip_address = local.associate_public_ip
  iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name
  key_name                    = var.create_key_pair ? aws_key_pair.this[0].key_name : var.key_name
  user_data                   = local.user_data_with_ssm
  disable_api_termination     = var.disable_api_termination
  monitoring                  = var.enable_detailed_monitoring
  ebs_optimized               = true

  # Secure Instance Metadata Service (IMDSv2)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = var.volume_type
    volume_size           = var.volume_size
    encrypted             = var.enable_ebs_encryption
    kms_key_id            = local.kms_key_id
    delete_on_termination = true

    tags = merge(
      {
        Name = "${var.instance_name}-root-volume"
      },
      var.tags
    )
  }

  tags = merge(
    {
      Name            = var.instance_name
      OperatingSystem = var.operating_system
    },
    var.tags
  )

}

# =============================================================================
# ELASTIC IP (OPTIONAL)
# =============================================================================

resource "aws_eip" "eip" {
  count    = var.create_eip ? 1 : 0
  instance = aws_instance.this.id
  domain   = "vpc"

  tags = merge(
    {
      Name = "${var.instance_name}-eip"
    },
    var.tags
  )

  depends_on = [aws_instance.this]
}

# =============================================================================
# IAM ROLE AND POLICIES
# =============================================================================

resource "aws_iam_role" "ssm_role" {
  name = var.iam_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    {
      Name = var.iam_role_name
    },
    var.tags
  )
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  count      = var.enable_cloudwatch_agent ? 1 : 0
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Additional policy for Windows instances
resource "aws_iam_role_policy_attachment" "ec2_role_for_ssm" {
  count      = var.operating_system == "windows" ? 1 : 0
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMDirectoryServiceAccess"
}

resource "aws_iam_role_policy_attachment" "s3_access" {
  count      = var.enable_s3_access ? 1 : 0
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "${var.iam_role_name}-profile"
  role = aws_iam_role.ssm_role.name

  tags = merge(
    {
      Name = "${var.iam_role_name}-profile"
    },
    var.tags
  )
}

# Fleet Manager IAM Policy for Admin Access
resource "aws_iam_policy" "fleet_manager_admin" {
  count       = var.enable_fleet_manager && var.fleet_manager_access_level == "admin" ? 1 : 0
  name        = "${var.iam_role_name}-fleet-manager-admin"
  path        = "/"
  description = "Fleet Manager administrator access policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2"
        Effect = "Allow"
        Action = [
          "ec2:CreateTags",
          "ec2:DeleteTags",
          "ec2:DescribeInstances",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      },
      {
        Sid    = "General"
        Effect = "Allow"
        Action = [
          "ssm:AddTagsToResource",
          "ssm:DescribeInstanceAssociationsStatus",
          "ssm:DescribeInstancePatches",
          "ssm:DescribeInstancePatchStates",
          "ssm:DescribeInstanceProperties",
          "ssm:GetCommandInvocation",
          "ssm:GetServiceSetting",
          "ssm:GetInventorySchema",
          "ssm:ListComplianceItems",
          "ssm:ListInventoryEntries",
          "ssm:ListTagsForResource",
          "ssm:ListCommandInvocations",
          "ssm:ListAssociations",
          "ssm:RemoveTagsFromResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "SendCommand"
        Effect = "Allow"
        Action = [
          "ssm:GetDocument",
          "ssm:SendCommand",
          "ssm:StartSession"
        ]
        Resource = [
          "arn:${data.aws_partition.current.partition}:ec2:*:${data.aws_caller_identity.current.account_id}:instance/*",
          "arn:${data.aws_partition.current.partition}:ssm:*:${data.aws_caller_identity.current.account_id}:managed-instance/*",
          "arn:${data.aws_partition.current.partition}:ssm:*:${data.aws_caller_identity.current.account_id}:document/SSM-SessionManagerRunShell",
          "arn:${data.aws_partition.current.partition}:ssm:*:*:document/AWS-PasswordReset",
          "arn:${data.aws_partition.current.partition}:ssm:*:*:document/AWSFleetManager-*"
        ]
      },
      {
        Sid    = "TerminateSession"
        Effect = "Allow"
        Action = [
          "ssm:TerminateSession"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "ssm:resourceTag/aws:ssmmessages:session-id" = [
              "$${aws:userid}"
            ]
          }
        }
      }
    ]
  })

  tags = merge(
    {
      Name = "${var.iam_role_name}-fleet-manager-admin"
    },
    var.tags
  )
}

# Fleet Manager IAM Policy for Read-Only Access
resource "aws_iam_policy" "fleet_manager_readonly" {
  count       = var.enable_fleet_manager && var.fleet_manager_access_level == "readonly" ? 1 : 0
  name        = "${var.iam_role_name}-fleet-manager-readonly"
  path        = "/"
  description = "Fleet Manager read-only access policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      },
      {
        Sid    = "General"
        Effect = "Allow"
        Action = [
          "ssm:DescribeInstanceAssociationsStatus",
          "ssm:DescribeInstancePatches",
          "ssm:DescribeInstancePatchStates",
          "ssm:DescribeInstanceProperties",
          "ssm:GetCommandInvocation",
          "ssm:GetServiceSetting",
          "ssm:GetInventorySchema",
          "ssm:ListComplianceItems",
          "ssm:ListInventoryEntries",
          "ssm:ListTagsForResource",
          "ssm:ListCommandInvocations",
          "ssm:ListAssociations"
        ]
        Resource = "*"
      },
      {
        Sid    = "SendCommand"
        Effect = "Allow"
        Action = [
          "ssm:GetDocument",
          "ssm:SendCommand",
          "ssm:StartSession"
        ]
        Resource = [
          "arn:${data.aws_partition.current.partition}:ec2:*:${data.aws_caller_identity.current.account_id}:instance/*",
          "arn:${data.aws_partition.current.partition}:ssm:*:${data.aws_caller_identity.current.account_id}:managed-instance/*",
          "arn:${data.aws_partition.current.partition}:ssm:*:${data.aws_caller_identity.current.account_id}:document/SSM-SessionManagerRunShell",
          "arn:${data.aws_partition.current.partition}:ssm:*:*:document/AWSFleetManager-GetDiskInformation",
          "arn:${data.aws_partition.current.partition}:ssm:*:*:document/AWSFleetManager-GetFileContent",
          "arn:${data.aws_partition.current.partition}:ssm:*:*:document/AWSFleetManager-GetFileSystemContent",
          "arn:${data.aws_partition.current.partition}:ssm:*:*:document/AWSFleetManager-GetGroups",
          "arn:${data.aws_partition.current.partition}:ssm:*:*:document/AWSFleetManager-GetPerformanceCounters",
          "arn:${data.aws_partition.current.partition}:ssm:*:*:document/AWSFleetManager-GetProcessDetails",
          "arn:${data.aws_partition.current.partition}:ssm:*:*:document/AWSFleetManager-GetUsers",
          "arn:${data.aws_partition.current.partition}:ssm:*:*:document/AWSFleetManager-GetWindowsEvents",
          "arn:${data.aws_partition.current.partition}:ssm:*:*:document/AWSFleetManager-GetWindowsRegistryContent"
        ]
      },
      {
        Sid    = "TerminateSession"
        Effect = "Allow"
        Action = [
          "ssm:TerminateSession"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "ssm:resourceTag/aws:ssmmessages:session-id" = [
              "$${aws:userid}"
            ]
          }
        }
      }
    ]
  })

  tags = merge(
    {
      Name = "${var.iam_role_name}-fleet-manager-readonly"
    },
    var.tags
  )
}

# Attach Fleet Manager policies to the IAM role
resource "aws_iam_role_policy_attachment" "fleet_manager_admin" {
  count      = var.enable_fleet_manager && var.fleet_manager_access_level == "admin" ? 1 : 0
  role       = aws_iam_role.ssm_role.name
  policy_arn = aws_iam_policy.fleet_manager_admin[0].arn
}

resource "aws_iam_role_policy_attachment" "fleet_manager_readonly" {
  count      = var.enable_fleet_manager && var.fleet_manager_access_level == "readonly" ? 1 : 0
  role       = aws_iam_role.ssm_role.name
  policy_arn = aws_iam_policy.fleet_manager_readonly[0].arn
}

# Session Manager logging permissions
resource "aws_iam_policy" "session_manager_logging" {
  count       = var.enable_session_manager && (var.session_manager_s3_bucket != null || var.session_manager_cloudwatch_log_group != null) ? 1 : 0
  name        = "${var.iam_role_name}-session-manager-logging"
  path        = "/"
  description = "Session Manager logging permissions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      var.session_manager_s3_bucket != null ? [
        {
          Effect = "Allow"
          Action = [
            "s3:PutObject",
            "s3:GetEncryptionConfiguration"
          ]
          Resource = [
            "arn:${data.aws_partition.current.partition}:s3:::${var.session_manager_s3_bucket}/*"
          ]
        }
      ] : [],
      var.session_manager_cloudwatch_log_group != null ? [
        {
          Effect = "Allow"
          Action = [
            "logs:CreateLogStream",
            "logs:PutLogEvents",
            "logs:DescribeLogGroups",
            "logs:DescribeLogStreams"
          ]
          Resource = [
            "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:${var.session_manager_cloudwatch_log_group}:*"
          ]
        }
      ] : []
    )
  })

  tags = merge(
    {
      Name = "${var.iam_role_name}-session-manager-logging"
    },
    var.tags
  )
}

resource "aws_iam_role_policy_attachment" "session_manager_logging" {
  count      = var.enable_session_manager && (var.session_manager_s3_bucket != null || var.session_manager_cloudwatch_log_group != null) ? 1 : 0
  role       = aws_iam_role.ssm_role.name
  policy_arn = aws_iam_policy.session_manager_logging[0].arn
}

# Enhanced Session Manager permissions policy
resource "aws_iam_policy" "session_manager_enhanced" {
  count       = var.enable_session_manager_permissions ? 1 : 0
  name        = "${var.iam_role_name}-session-manager-enhanced"
  path        = "/"
  description = "Enhanced Session Manager permissions for ssmmessages and S3 access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetEncryptionConfiguration"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(
    {
      Name = "${var.iam_role_name}-session-manager-enhanced"
    },
    var.tags
  )
}

resource "aws_iam_role_policy_attachment" "session_manager_enhanced" {
  count      = var.enable_session_manager_permissions ? 1 : 0
  role       = aws_iam_role.ssm_role.name
  policy_arn = aws_iam_policy.session_manager_enhanced[0].arn
}



# =============================================================================
# NAT GATEWAY FOR PRIVATE SUBNET INTERNET ACCESS
# =============================================================================

# Create Elastic IP for NAT Gateway if needed
resource "aws_eip" "nat_gateway" {
  count  = var.create_nat_gateway && var.nat_gateway_allocation_id == null ? 1 : 0
  domain = "vpc"

  tags = merge(
    {
      Name = "${var.instance_name}-nat-gw-eip"
    },
    var.tags
  )

  depends_on = [data.aws_vpc.selected]
}

# Create NAT Gateway
resource "aws_nat_gateway" "this" {
  count         = var.create_nat_gateway ? 1 : 0
  allocation_id = var.nat_gateway_allocation_id != null ? var.nat_gateway_allocation_id : aws_eip.nat_gateway[0].id
  subnet_id     = var.nat_gateway_subnet_id

  tags = merge(
    {
      Name = "${var.instance_name}-nat-gw"
    },
    var.tags
  )

  depends_on = [aws_eip.nat_gateway]
}

# =============================================================================
# PRIVATE SUBNET ROUTE TABLE MANAGEMENT
# =============================================================================

# Create private route table if requested
resource "aws_route_table" "private" {
  count  = var.create_private_route_table ? 1 : 0
  vpc_id = data.aws_vpc.selected.id

  # Add NAT Gateway route - prefer created NAT Gateway over provided ID
  dynamic "route" {
    for_each = local.nat_gateway_id != null ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = local.nat_gateway_id
    }
  }

  tags = merge(
    {
      Name = "${var.instance_name}-private-rt"
    },
    var.tags
  )
}

# Associate the private route table with the subnet
resource "aws_route_table_association" "private" {
  count          = var.create_private_route_table && var.subnet_id != null ? 1 : 0
  subnet_id      = var.subnet_id
  route_table_id = aws_route_table.private[0].id
}

# =============================================================================
# VPC ENDPOINTS FOR SSM
# =============================================================================

# Check for existing VPC endpoints in the VPC - with error handling
data "aws_vpc_endpoint" "existing_ssm" {
  count = var.create_vpc_endpoints && var.check_for_existing_vpc_endpoints ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
  filter {
    name   = "service-name"
    values = ["com.amazonaws.${data.aws_region.current.region}.ssm"]
  }
  filter {
    name   = "vpc-endpoint-type"
    values = ["Interface"]
  }
  # Remove the state filter - it's invalid
}

data "aws_vpc_endpoint" "existing_ec2messages" {
  count = var.create_vpc_endpoints && var.check_for_existing_vpc_endpoints ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
  filter {
    name   = "service-name"
    values = ["com.amazonaws.${data.aws_region.current.region}.ec2messages"]
  }
  filter {
    name   = "vpc-endpoint-type"
    values = ["Interface"]
  }
  # Remove the state filter - it's invalid
}

data "aws_vpc_endpoint" "existing_ssmmessages" {
  count = var.create_vpc_endpoints && var.check_for_existing_vpc_endpoints ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
  filter {
    name   = "service-name"
    values = ["com.amazonaws.${data.aws_region.current.region}.ssmmessages"]
  }
  filter {
    name   = "vpc-endpoint-type"
    values = ["Interface"]
  }
  # Remove the state filter - it's invalid
}

# Get VPC endpoint service data for SSM (only if we need to create endpoints)
data "aws_vpc_endpoint_service" "ssm" {
  count = var.create_vpc_endpoints && (
    var.check_for_existing_vpc_endpoints ? !local.existing_ssm_endpoint_exists : true
  ) ? 1 : 0
  service = "ssm"
}

data "aws_vpc_endpoint_service" "ec2messages" {
  count = var.create_vpc_endpoints && (
    var.check_for_existing_vpc_endpoints ? !local.existing_ec2messages_endpoint_exists : true
  ) ? 1 : 0
  service = "ec2messages"
}

data "aws_vpc_endpoint_service" "ssmmessages" {
  count = var.create_vpc_endpoints && (
    var.check_for_existing_vpc_endpoints ? !local.existing_ssmmessages_endpoint_exists : true
  ) ? 1 : 0
  service = "ssmmessages"
}

# SSM VPC Endpoint
resource "aws_vpc_endpoint" "ssm" {
  count = var.create_vpc_endpoints && (
    var.check_for_existing_vpc_endpoints ? !local.existing_ssm_endpoint_exists : true
  ) ? 1 : 0
  vpc_id             = data.aws_vpc.selected.id
  service_name       = data.aws_vpc_endpoint_service.ssm[0].service_name
  vpc_endpoint_type  = "Interface"
  private_dns_enabled = var.enable_private_dns
  subnet_ids         = var.vpc_endpoint_subnet_ids != null ? var.vpc_endpoint_subnet_ids : [local.subnet_id]
  security_group_ids = [aws_security_group.vpc_endpoint[0].id]

  tags = merge(
    {
      Name = "${var.instance_name}-ssm-endpoint"
    },
    var.tags
  )
}

# EC2Messages VPC Endpoint (only create if it doesn't exist)
resource "aws_vpc_endpoint" "ec2messages" {
  count = var.create_vpc_endpoints && (
    var.check_for_existing_vpc_endpoints ? !local.existing_ec2messages_endpoint_exists : true
  ) ? 1 : 0
  vpc_id             = data.aws_vpc.selected.id
  service_name       = data.aws_vpc_endpoint_service.ec2messages[0].service_name
  vpc_endpoint_type  = "Interface"
  private_dns_enabled = var.enable_private_dns
  subnet_ids         = var.vpc_endpoint_subnet_ids != null ? var.vpc_endpoint_subnet_ids : [local.subnet_id]
  security_group_ids = [aws_security_group.vpc_endpoint[0].id]

  tags = merge(
    {
      Name = "${var.instance_name}-ec2messages-endpoint"
    },
    var.tags
  )
}

# SSMMessages VPC Endpoint (only create if it doesn't exist)
resource "aws_vpc_endpoint" "ssmmessages" {
  count = var.create_vpc_endpoints && (
    var.check_for_existing_vpc_endpoints ? !local.existing_ssmmessages_endpoint_exists : true
  ) ? 1 : 0
  vpc_id             = data.aws_vpc.selected.id
  service_name       = data.aws_vpc_endpoint_service.ssmmessages[0].service_name
  vpc_endpoint_type  = "Interface"
  private_dns_enabled = var.enable_private_dns
  subnet_ids         = var.vpc_endpoint_subnet_ids != null ? var.vpc_endpoint_subnet_ids : [local.subnet_id]
  security_group_ids = [aws_security_group.vpc_endpoint[0].id]

  tags = merge(
    {
      Name = "${var.instance_name}-ssmmessages-endpoint"
    },
    var.tags
  )
}

# Security group for VPC endpoints (only create if we need new endpoints)
resource "aws_security_group" "vpc_endpoint" {
  count       = local.create_vpc_endpoint_sg ? 1 : 0
  name        = "${var.instance_name}-vpc-endpoints-sg"
  description = "Security group for VPC endpoints"
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
    description = "HTTPS from VPC"
  }

  # Restrict egress to only necessary traffic for VPC endpoints
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
    description = "HTTPS within VPC for endpoint responses"
  }

  # Allow DNS resolution for endpoint functionality
  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
    description = "DNS resolution within VPC"
  }

  tags = merge(
    {
      Name = "${var.instance_name}-vpc-endpoints-sg"
    },
    var.tags
  )

  lifecycle {
    create_before_destroy = true
  }
}

# =============================================================================
# ADDITIONAL VPC ENDPOINTS FOR COMPLETE SSM FUNCTIONALITY IN PRIVATE SUBNETS
# =============================================================================

# S3 Gateway VPC Endpoint (for Session Manager S3 logging)
resource "aws_vpc_endpoint" "s3" {
  count             = var.create_s3_vpc_endpoint ? 1 : 0
  vpc_id            = data.aws_vpc.selected.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.s3_vpc_endpoint_route_table_ids

  tags = merge(
    {
      Name = "${var.instance_name}-s3-endpoint"
    },
    var.tags
  )
}

# KMS Interface VPC Endpoint (for Session Manager encryption)
resource "aws_vpc_endpoint" "kms" {
  count               = var.create_kms_vpc_endpoint ? 1 : 0
  vpc_id              = data.aws_vpc.selected.id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.kms"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.vpc_endpoint_subnet_ids != null ? var.vpc_endpoint_subnet_ids : [local.subnet_id]
  security_group_ids  = [aws_security_group.vpc_endpoint[0].id]
  private_dns_enabled = var.enable_private_dns

  tags = merge(
    {
      Name = "${var.instance_name}-kms-endpoint"
    },
    var.tags
  )

  depends_on = [aws_security_group.vpc_endpoint]
}

# CloudWatch Logs Interface VPC Endpoint (for Session Manager CloudWatch logging)
resource "aws_vpc_endpoint" "logs" {
  count               = var.create_logs_vpc_endpoint ? 1 : 0
  vpc_id              = data.aws_vpc.selected.id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.vpc_endpoint_subnet_ids != null ? var.vpc_endpoint_subnet_ids : [local.subnet_id]
  security_group_ids  = [aws_security_group.vpc_endpoint[0].id]
  private_dns_enabled = var.enable_private_dns

  tags = merge(
    {
      Name = "${var.instance_name}-logs-endpoint"
    },
    var.tags
  )

  depends_on = [aws_security_group.vpc_endpoint]
}

# CloudWatch Monitoring Interface VPC Endpoint (for CloudWatch metrics)
resource "aws_vpc_endpoint" "monitoring" {
  count               = var.create_monitoring_vpc_endpoint ? 1 : 0
  vpc_id              = data.aws_vpc.selected.id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.monitoring"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.vpc_endpoint_subnet_ids != null ? var.vpc_endpoint_subnet_ids : [local.subnet_id]
  security_group_ids  = [aws_security_group.vpc_endpoint[0].id]
  private_dns_enabled = var.enable_private_dns

  tags = merge(
    {
      Name = "${var.instance_name}-monitoring-endpoint"
    },
    var.tags
  )

  depends_on = [aws_security_group.vpc_endpoint]
}

# =============================================================================
# CLOUDWATCH AGENT CONFIGURATION (OPTIONAL)
# =============================================================================

resource "aws_ssm_parameter" "cloudwatch_agent_config_linux" {
  count  = var.enable_cloudwatch_agent && var.operating_system == "linux" ? 1 : 0
  name   = "/AmazonCloudWatch/${var.instance_name}/linux/config"
  type   = "SecureString"
  key_id = "alias/${var.instance_name}-parameter-store-key"
  value = jsonencode({
    agent = {
      metrics_collection_interval = 60
      run_as_user                 = "cwagent"
    }
    metrics = {
      namespace = "CWAgent"
      metrics_collected = {
        cpu = {
          measurement = [
            "cpu_usage_idle",
            "cpu_usage_iowait",
            "cpu_usage_user",
            "cpu_usage_system"
          ]
          metrics_collection_interval = 60
          totalcpu                    = false
        }
        disk = {
          measurement = [
            "used_percent"
          ]
          metrics_collection_interval = 60
          resources = [
            "*"
          ]
        }
        diskio = {
          measurement = [
            "io_time",
            "read_bytes",
            "write_bytes",
            "reads",
            "writes"
          ]
          metrics_collection_interval = 60
          resources = [
            "*"
          ]
        }
        mem = {
          measurement = [
            "mem_used_percent"
          ]
          metrics_collection_interval = 60
        }
        netstat = {
          measurement = [
            "tcp_established",
            "tcp_time_wait"
          ]
          metrics_collection_interval = 60
        }
        swap = {
          measurement = [
            "swap_used_percent"
          ]
          metrics_collection_interval = 60
        }
      }
    }
  })

  tags = merge(
    {
      Name = "${var.instance_name}-cw-config"
    },
    var.tags
  )
}

resource "aws_ssm_parameter" "cloudwatch_agent_config_windows" {
  count  = var.enable_cloudwatch_agent && var.operating_system == "windows" ? 1 : 0
  name   = "/AmazonCloudWatch/${var.instance_name}/windows/config"
  type   = "SecureString"
  key_id = "alias/${var.instance_name}-parameter-store-key"
  value = jsonencode({
    agent = {
      metrics_collection_interval = 60
    }
    metrics = {
      namespace = "CWAgent"
      metrics_collected = {
        "LogicalDisk" = {
          measurement = [
            "% Free Space"
          ]
          metrics_collection_interval = 60
          resources = [
            "*"
          ]
        }
        "Memory" = {
          measurement = [
            "% Committed Bytes In Use"
          ]
          metrics_collection_interval = 60
        }
        "Processor" = {
          measurement = [
            "% Processor Time"
          ]
          metrics_collection_interval = 60
          resources = [
            "_Total"
          ]
        }
      }
    }
  })

  tags = merge(
    {
      Name = "${var.instance_name}-cw-config"
    },
    var.tags
  )
}

resource "aws_ssm_association" "install_agent" {
  count = var.enable_cloudwatch_agent ? 1 : 0
  name  = "AWS-ConfigureAWSPackage"

  targets {
    key    = "InstanceIds"
    values = [aws_instance.this.id]
  }

  parameters = {
    action = "Install"
    name   = "AmazonCloudWatchAgent"
  }

  depends_on = [aws_instance.this]
}

resource "aws_ssm_association" "configure_agent" {
  count = var.enable_cloudwatch_agent ? 1 : 0
  name  = "AmazonCloudWatch-ManageAgent"

  targets {
    key    = "InstanceIds"
    values = [aws_instance.this.id]
  }

  parameters = {
    action                        = "configure"
    mode                          = "ec2"
    optionalConfigurationSource   = "ssm"
    optionalConfigurationLocation = var.operating_system == "linux" ? aws_ssm_parameter.cloudwatch_agent_config_linux[0].name : aws_ssm_parameter.cloudwatch_agent_config_windows[0].name
  }

  depends_on = [aws_instance.this, aws_ssm_association.install_agent]
}

# =============================================================================
# KEY PAIR CREATION FOR WINDOWS INSTANCES
# =============================================================================

# Generate a private key if key pair creation is requested and no public key provided
resource "tls_private_key" "this" {
  count     = var.create_key_pair && var.public_key == null ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create the key pair
resource "aws_key_pair" "this" {
  count      = var.create_key_pair ? 1 : 0
  key_name   = var.key_pair_name != null ? var.key_pair_name : "${var.instance_name}-key"
  public_key = var.public_key != null ? var.public_key : tls_private_key.this[0].public_key_openssh

  tags = merge(
    {
      Name = var.key_pair_name != null ? var.key_pair_name : "${var.instance_name}-key"
    },
    var.tags
  )
}

# Store the private key in SSM Parameter Store if key generation was requested
resource "aws_ssm_parameter" "private_key" {
  count       = var.create_key_pair && var.public_key == null && var.save_private_key ? 1 : 0
  name        = "/ec2/keypair/${aws_key_pair.this[0].key_name}/private_key"
  type        = "SecureString"
  value       = tls_private_key.this[0].private_key_pem
  description = "Private key for EC2 key pair ${aws_key_pair.this[0].key_name}"

  tags = merge(
    {
      Name = "${aws_key_pair.this[0].key_name}-private-key"
    },
    var.tags
  )
}

