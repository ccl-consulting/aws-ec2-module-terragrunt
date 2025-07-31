# AWS EC2 Module

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.0-623CE4?logo=terraform6logoColor=white)](https://www.terraform.io/)
[![AWS Provider](https://img.shields.io/badge/AWS_Provider-%3E%3D4.0-FF9900?logo=amazon-aws6logoColor=white)](https://registry.terraform.io/providers/hashicorp/aws/latest)
[![Terragrunt](https://img.shields.io/badge/Terragrunt-%3E%3D0.35-0F1419?logo=terragrunt6logoColor=white)](https://terragrunt.gruntwork.io/)
[![CI/CD](https://img.shields.io/badge/CI%2FCD-GitHub_Actions-2088FF?logo=github-actions6logoColor=white)](https://github.com/features/actions)
[![CCL Modules](https://img.shields.io/badge/CCL-Modules-blue?style=flat6logo=data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjQiIGhlaWdodD0iMjQiIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KPHBhdGggZD0iTTEyIDJMMTMuMDkgOC4yNkwyMCA5TDEzLjA5IDE1Ljc0TDEyIDIyTDEwLjkxIDE1Ljc0TDQgOUwxMC45MSA4LjI2TDEyIDJaIiBmaWxsPSJ3aGl0ZSIvPgo8L3N2Zz4K)](https://github.com/ccl-consulting)

This Terraform module deploys an EC2 instance with enhanced security, flexible configuration options, and support for both Linux and Windows operating systems. It provides comprehensive features including KMS encryption, custom networking, and detailed monitoring capabilities.

## Features

- Support for both Linux and Windows instances
- Flexible AMI selection (default latest or custom AMI)
- Enhanced security with configurable ingress/egress rules
- KMS encryption for EBS volumes
- Optional Elastic IP association
- CloudWatch monitoring and logging
- Custom VPC and subnet configuration
- NAT Gateway creation and management for private subnet internet access
- VPC Endpoints for SSM connectivity in private subnets
- Private route table management
- Comprehensive tagging support
- AWS Systems Manager (SSM) integration

## Requirements

- Terraform version >= 1.0
- AWS Provider version >= 4.0
- Terragrunt version >= 0.35
- AWS CLI configured with appropriate permissions
- VPC and subnets (will use default VPC if not specified)

## Inputs

### Core Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `instance_name` | `string` | - | Name of the instance (required) |
| `instance_type` | `string` | `"t3.micro"` | EC2 instance type |
| `operating_system` | `string` | `"linux"` | Operating system type (linux/windows) |
| `aws_region` | `string` | - | AWS region for deployment |

### AMI Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `custom_ami_id` | `string` | `null` | Custom AMI ID to use instead of default |
| `ami_owners` | `list(string)` | `["amazon"]` | List of AMI owners to consider |

### Network Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `vpc_id` | `string` | `null` | VPC ID (uses default VPC if not specified) |
| `subnet_id` | `string` | `null` | Subnet ID (auto-selects if not specified) |
| `private_subnet` | `bool` | `false` | Whether to deploy in private subnet |
| `associate_public_ip_address` | `bool` | `null` | Whether to associate public IP |

### NAT Gateway Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `create_nat_gateway` | `bool` | `false` | Whether to create NAT Gateway for outbound internet access |
| `nat_gateway_subnet_id` | `string` | `null` | Public subnet ID for NAT Gateway placement (required if creating NAT Gateway) |
| `nat_gateway_allocation_id` | `string` | `null` | Existing Elastic IP allocation ID for NAT Gateway (new EIP created if not provided) |
| `nat_gateway_id` | `string` | `null` | Existing NAT Gateway ID to use instead of creating new one |

### Private Subnet and VPC Endpoints

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `create_private_route_table` | `bool` | `false` | Create private route table (removes internet gateway route) |
| `create_vpc_endpoints` | `bool` | `true` | Create VPC endpoints for SSM connectivity |
| `vpc_endpoint_subnet_ids` | `list(string)` | `null` | Subnet IDs for VPC endpoints (defaults to instance subnet) |

### Security Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `allowed_ssh_cidrs` | `list(string)` | `[]` | CIDR blocks allowed for SSH (Linux) |
| `allowed_rdp_cidrs` | `list(string)` | `[]` | CIDR blocks allowed for RDP (Windows) |
| `allowed_http_cidrs` | `list(string)` | `[]` | CIDR blocks allowed for HTTP |
| `allowed_https_cidrs` | `list(string)` | `[]` | CIDR blocks allowed for HTTPS |
| `custom_ingress_rules` | `list(object)` | `[]` | Custom ingress security group rules |
| `custom_egress_rules` | `list(object)` | `[]` | Custom egress security group rules |
| `restrict_egress` | `bool` | `false` | Whether to restrict egress traffic |

### Storage and Encryption

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `volume_size` | `number` | `8` | Size of root volume in GiB |
| `volume_type` | `string` | `"gp3"` | Type of EBS volume |
| `enable_ebs_encryption` | `bool` | `true` | Whether to enable EBS encryption |
| `kms_key_id` | `string` | `null` | KMS key ID for encryption |

### Monitoring and Management

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `enable_detailed_monitoring` | `bool` | `false` | Enable detailed CloudWatch monitoring |
| `enable_cloudwatch_agent` | `bool` | `true` | Install CloudWatch agent |
| `create_eip` | `bool` | `true` | Whether to create Elastic IP |

## Outputs

| Name | Description |
|------|-------------|
| `instance_id` | ID of the EC2 instance |
| `instance_arn` | ARN of the EC2 instance |
| `private_ip` | Private IP address |
| `public_ip` | Public IP address (if any) |
| `eip` | Elastic IP address (if created) |
| `security_group_id` | ID of the security group |
| `root_volume_id` | ID of the root EBS volume |
| `kms_key_id` | ID of the KMS key used for encryption |
| `nat_gateway_id` | ID of the NAT Gateway (if created) |
| `nat_gateway_public_ip` | Public IP of the NAT Gateway (if created) |
| `private_route_table_id` | ID of the private route table (if created) |

## Usage

This module can be used with Terragrunt to deploy EC2 instances with various configurations. The module supports both Linux and Windows instances with comprehensive security and monitoring capabilities.

### Basic Usage

```hcl
terraform {
  source = "git::https://github.com/ccl-consulting/aws-ec2-module-terragrunt.git"
}

inputs = {
  instance_name = "my-server"
  instance_type = "t3.micro"
  aws_region    = "us-east-1"
  
  # Configure security appropriately
  allowed_ssh_cidrs = ["203.0.113.0/24"]
  
  tags = {
    Environment = "Development"
    Owner       = "DevOps"
  }
}
```

## Examples

### Basic Linux Instance

```hcl
terraform {
  source = "git::https://github.com/ccl-consulting/aws-ec2-module-terragrunt.git"
}

inputs = {
  instance_name = "my-server"
  instance_type = "t3.micro"
  aws_region    = "us-east-1"
  
  allowed_ssh_cidrs = ["203.0.113.0/24"]
  
  tags = {
    Environment = "Development"
    Owner       = "DevOps"
  }
}
```

### Windows Server with Custom Security

```hcl
terraform {
  source = "git::https://github.com/ccl-consulting/aws-ec2-module-terragrunt.git"
}

inputs = {
  instance_name    = "windows-server"
  instance_type    = "t3.medium"
  operating_system = "windows"
  aws_region       = "us-west-2"
  
  allowed_rdp_cidrs = ["10.0.0.0/8"]
  
  custom_ingress_rules = [
    {
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/8"]
      description = "Application port"
    }
  ]
  
  volume_size           = 50
  enable_ebs_encryption = true
  
  tags = {
    Environment = "Production"
    OS          = "Windows"
  }
}
```

### Private Instance with VPC Endpoints Only (Most Secure)

```hcl
terraform {
  source = "git::https://github.com/ccl-consulting/aws-ec2-module-terragrunt.git"
}

inputs = {
  instance_name  = "private-db-server"
  instance_type  = "t3.medium"
  aws_region     = "us-east-1"
  
  vpc_id         = "vpc-12345678"
  subnet_id      = "subnet-private123"
  private_subnet = true
  create_eip     = false
  
  # Create private route table (removes internet gateway route)
  create_private_route_table = true
  
  # Enable VPC endpoints for SSM access
  create_vpc_endpoints = true
  
  custom_ingress_rules = [
    {
      from_port   = 3306
      to_port     = 3306
      protocol    = "tcp"
      cidr_blocks = ["10.0.1.0/24"]
      description = "MySQL from app servers"
    }
  ]
  
  restrict_egress = true
  custom_egress_rules = [
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"]
      description = "HTTPS to VPC endpoints only"
    },
    {
      from_port   = 53
      to_port     = 53
      protocol    = "udp"
      cidr_blocks = ["10.0.0.0/16"]
      description = "DNS resolution"
    }
  ]
  
  volume_size           = 100
  enable_ebs_encryption = true
  
  tags = {
    Environment = "Production"
    Application = "Database"
    NetworkTier = "private"
  }
}
```

### Private Instance with NAT Gateway (For Internet Access)

```hcl
terraform {
  source = "git::https://github.com/ccl-consulting/aws-ec2-module-terragrunt.git"
}

inputs = {
  instance_name  = "private-app-server"
  instance_type  = "t3.medium"
  operating_system = "linux"
  aws_region     = "us-east-1"
  
  vpc_id         = "vpc-12345678"
  subnet_id      = "subnet-private123"
  private_subnet = true
  create_eip     = false
  
  # Create NAT Gateway for internet access
  create_nat_gateway     = true
  nat_gateway_subnet_id  = "subnet-public456"  # Must be public subnet
  
  # Create private route table with NAT Gateway route
  create_private_route_table = true
  
  # VPC endpoints for better performance
  create_vpc_endpoints = true
  
  custom_ingress_rules = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"]
      description = "SSH from VPC"
    }
  ]
  
  restrict_egress = true
  custom_egress_rules = [
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTPS to internet via NAT Gateway"
    },
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTP for package updates"
    },
    {
      from_port   = 53
      to_port     = 53
      protocol    = "udp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "DNS resolution"
    }
  ]
  
  volume_size           = 50
  enable_ebs_encryption = true
  
  tags = {
    Environment = "Production"
    Application = "AppServer"
    NetworkTier = "private"
    InternetAccess = "nat-gateway"
  }
}
```

## Private Subnet Connectivity Options

This module provides flexible options for private subnet connectivity, each with different security and cost implications:

### VPC Endpoints Only (Most Secure, Lower Cost)

**Use when:**
- Maximum security is required
- No internet access needed
- Linux instances with pre-configured software
- Cost optimization is important

**Configuration:**
```hcl
create_vpc_endpoints = true
create_private_route_table = true
# No NAT Gateway configuration
```

### NAT Gateway + VPC Endpoints (Balanced Security and Functionality)

**Use when:**
- Windows instances (require internet for updates)
- Linux instances needing package updates/installations
- Applications requiring external API access
- Certificate validation is required

**Configuration:**
```hcl
create_nat_gateway = true
nat_gateway_subnet_id = "subnet-public123"
create_private_route_table = true
create_vpc_endpoints = true  # Optional but recommended for performance
```

### Key Differences

| Feature | VPC Endpoints Only | NAT Gateway + VPC Endpoints |
|---------|-------------------|-----------------------------|
| **Security** | Highest (no internet access) | High (filtered internet access) |
| **Cost** | Lower (VPC endpoint charges only) | Higher (NAT Gateway + data charges) |
| **Windows Updates** | ❌ Not possible | ✅ Fully supported |
| **Package Updates** | ❌ Limited | ✅ Full access |
| **External APIs** | ❌ Not accessible | ✅ Accessible |
| **SSM Access** | ✅ Via VPC endpoints | ✅ Via VPC endpoints (faster) |

## Security Best Practices

- **Network Security**: Use specific CIDR blocks instead of `0.0.0.0/0` for ingress rules
- **Encryption**: Enable EBS encryption with KMS keys
- **Access Control**: Use IAM roles instead of access keys
- **Monitoring**: Enable CloudWatch detailed monitoring for production instances
- **Updates**: Keep AMIs updated with latest security patches
- **Egress Control**: Use `restrict_egress = true` for sensitive workloads
- **NAT Gateway**: Only create when internet access is required; prefer VPC endpoints for AWS services
- **Private Subnets**: Always use `create_private_route_table = true` for truly private instances

## Contributing

Contributions are welcome! Please read our contributing guidelines and submit pull requests to our repository.

## License

This module is licensed under the MIT License. See LICENSE file for details.

## Support

For support and questions, please contact the CCL Consulting team or create an issue in the repository.
