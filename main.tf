terraform {
  # backend "s3" {}
}

# =============================================================================
# DATA SOURCES
# =============================================================================

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

  # VPC endpoint existence checks (only valid when checking is enabled)
  existing_ssm_endpoint_exists = var.create_vpc_endpoints && var.check_for_existing_vpc_endpoints ? (
    length(data.aws_vpc_endpoint.existing_ssm[0].ids) > 0
  ) : false
  existing_ec2messages_endpoint_exists = var.create_vpc_endpoints && var.check_for_existing_vpc_endpoints ? (
    length(data.aws_vpc_endpoint.existing_ec2messages[0].ids) > 0
  ) : false
  existing_ssmmessages_endpoint_exists = var.create_vpc_endpoints && var.check_for_existing_vpc_endpoints ? (
    length(data.aws_vpc_endpoint.existing_ssmmessages[0].ids) > 0
  ) : false

  # Determine if we need to create security group for VPC endpoints
  create_vpc_endpoint_sg = var.create_vpc_endpoints && (
    var.check_for_existing_vpc_endpoints ? (
      !local.existing_ssm_endpoint_exists ||
      !local.existing_ec2messages_endpoint_exists ||
      !local.existing_ssmmessages_endpoint_exists
    ) : true
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
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
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
  key_name                    = var.key_name
  user_data                   = var.user_data
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
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  count      = var.enable_cloudwatch_agent ? 1 : 0
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Additional policy for Windows instances
resource "aws_iam_role_policy_attachment" "ec2_role_for_ssm" {
  count      = var.operating_system == "windows" ? 1 : 0
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMDirectoryServiceAccess"
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

# Check for existing VPC endpoints in the VPC
data "aws_vpc_endpoint" "existing_ssm" {
  count = var.create_vpc_endpoints && var.check_for_existing_vpc_endpoints ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
  filter {
    name   = "service-name"
    values = ["com.amazonaws.${data.aws_region.current.name}.ssm"]
  }
  filter {
    name   = "vpc-endpoint-type"
    values = ["Interface"]
  }
}

data "aws_vpc_endpoint" "existing_ec2messages" {
  count = var.create_vpc_endpoints && var.check_for_existing_vpc_endpoints ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
  filter {
    name   = "service-name"
    values = ["com.amazonaws.${data.aws_region.current.name}.ec2messages"]
  }
  filter {
    name   = "vpc-endpoint-type"
    values = ["Interface"]
  }
}

data "aws_vpc_endpoint" "existing_ssmmessages" {
  count = var.create_vpc_endpoints && var.check_for_existing_vpc_endpoints ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
  filter {
    name   = "service-name"
    values = ["com.amazonaws.${data.aws_region.current.name}.ssmmessages"]
  }
  filter {
    name   = "vpc-endpoint-type"
    values = ["Interface"]
  }
}

# Get VPC endpoint service data for SSM (only if we need to create endpoints)
data "aws_vpc_endpoint_service" "ssm" {
  count = var.create_vpc_endpoints && (
    var.check_for_existing_vpc_endpoints ? length(data.aws_vpc_endpoint.existing_ssm[0].ids) == 0 : true
  ) ? 1 : 0
  service = "ssm"
}

data "aws_vpc_endpoint_service" "ec2messages" {
  count = var.create_vpc_endpoints && (
    var.check_for_existing_vpc_endpoints ? length(data.aws_vpc_endpoint.existing_ec2messages[0].ids) == 0 : true
  ) ? 1 : 0
  service = "ec2messages"
}

data "aws_vpc_endpoint_service" "ssmmessages" {
  count = var.create_vpc_endpoints && (
    var.check_for_existing_vpc_endpoints ? length(data.aws_vpc_endpoint.existing_ssmmessages[0].ids) == 0 : true
  ) ? 1 : 0
  service = "ssmmessages"
}

# SSM VPC Endpoint
resource "aws_vpc_endpoint" "ssm" {
  count = var.create_vpc_endpoints && (
    var.check_for_existing_vpc_endpoints ? length(data.aws_vpc_endpoint.existing_ssm[0].ids) == 0 : true
  ) ? 1 : 0
  vpc_id             = data.aws_vpc.selected.id
  service_name       = data.aws_vpc_endpoint_service.ssm[0].service_name
  vpc_endpoint_type  = "Interface"
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
    var.check_for_existing_vpc_endpoints ? length(data.aws_vpc_endpoint.existing_ec2messages[0].ids) == 0 : true
  ) ? 1 : 0
  vpc_id             = data.aws_vpc.selected.id
  service_name       = data.aws_vpc_endpoint_service.ec2messages[0].service_name
  vpc_endpoint_type  = "Interface"
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
    var.check_for_existing_vpc_endpoints ? length(data.aws_vpc_endpoint.existing_ssmmessages[0].ids) == 0 : true
  ) ? 1 : 0
  vpc_id             = data.aws_vpc.selected.id
  service_name       = data.aws_vpc_endpoint_service.ssmmessages[0].service_name
  vpc_endpoint_type  = "Interface"
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
# CLOUDWATCH AGENT CONFIGURATION (OPTIONAL)
# =============================================================================

resource "aws_ssm_parameter" "cloudwatch_agent_config_linux" {
  count  = var.enable_cloudwatch_agent && var.operating_system == "linux" ? 1 : 0
  name   = "/AmazonCloudWatch/${var.instance_name}/linux/config"
  type   = "SecureString"
  key_id = "alias/parameter_store_key"
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
  key_id = "alias/parameter_store_key"
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
