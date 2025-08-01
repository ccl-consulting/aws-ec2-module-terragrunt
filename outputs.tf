# =============================================================================
# INSTANCE OUTPUTS
# =============================================================================

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.this.id
}

output "instance_arn" {
  description = "ARN of the EC2 instance"
  value       = aws_instance.this.arn
}

output "instance_state" {
  description = "State of the EC2 instance"
  value       = aws_instance.this.instance_state
}

output "instance_type" {
  description = "Type of the EC2 instance"
  value       = aws_instance.this.instance_type
}

output "ami_id" {
  description = "AMI ID used for the EC2 instance"
  value       = aws_instance.this.ami
}

output "operating_system" {
  description = "Operating system of the instance"
  value       = var.operating_system
}

# =============================================================================
# NETWORK OUTPUTS
# =============================================================================

output "private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.this.private_ip
}

output "public_ip" {
  description = "Public IP address of the EC2 instance (if any)"
  value       = aws_instance.this.public_ip
}

output "eip" {
  description = "Elastic IP address of the EC2 instance (if created)"
  value       = var.create_eip ? aws_eip.eip[0].public_ip : null
}

output "eip_allocation_id" {
  description = "Allocation ID of the Elastic IP (if created)"
  value       = var.create_eip ? aws_eip.eip[0].allocation_id : null
}

output "subnet_id" {
  description = "Subnet ID where the instance is deployed"
  value       = aws_instance.this.subnet_id
}

output "vpc_id" {
  description = "VPC ID where the instance is deployed"
  value       = data.aws_vpc.selected.id
}

# =============================================================================
# SECURITY OUTPUTS
# =============================================================================

output "security_group_id" {
  description = "ID of the security group attached to the instance"
  value       = aws_security_group.this.id
}

output "security_group_name" {
  description = "Name of the security group attached to the instance"
  value       = aws_security_group.this.name
}

output "iam_role_name" {
  description = "Name of the IAM role attached to the instance"
  value       = aws_iam_role.ssm_role.name
}

output "iam_role_arn" {
  description = "ARN of the IAM role attached to the instance"
  value       = aws_iam_role.ssm_role.arn
}

output "iam_instance_profile_name" {
  description = "Name of the IAM instance profile"
  value       = aws_iam_instance_profile.ssm_profile.name
}

# =============================================================================
# STORAGE OUTPUTS
# =============================================================================

output "root_volume_id" {
  description = "ID of the root EBS volume"
  value       = aws_instance.this.root_block_device[0].volume_id
}

output "root_volume_size" {
  description = "Size of the root EBS volume in GiB"
  value       = aws_instance.this.root_block_device[0].volume_size
}

output "root_volume_type" {
  description = "Type of the root EBS volume"
  value       = aws_instance.this.root_block_device[0].volume_type
}

output "root_volume_encrypted" {
  description = "Whether the root EBS volume is encrypted"
  value       = aws_instance.this.root_block_device[0].encrypted
}

# =============================================================================
# KMS OUTPUTS
# =============================================================================

output "kms_key_id" {
  description = "ID of the KMS key used for EBS encryption (if created)"
  value       = var.enable_ebs_encryption && var.kms_key_id == null ? aws_kms_key.ebs[0].key_id : var.kms_key_id
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for EBS encryption (if created)"
  value       = var.enable_ebs_encryption && var.kms_key_id == null ? aws_kms_key.ebs[0].arn : null
}

output "kms_key_alias" {
  description = "Alias of the KMS key used for EBS encryption (if created)"
  value       = var.enable_ebs_encryption && var.kms_key_id == null ? aws_kms_alias.ebs[0].name : null
}

# =============================================================================
# MONITORING OUTPUTS
# =============================================================================

output "cloudwatch_agent_config_parameter" {
  description = "Name of the SSM parameter containing CloudWatch agent configuration"
  value = var.enable_cloudwatch_agent ? (
    var.operating_system == "linux" ?
    aws_ssm_parameter.cloudwatch_agent_config_linux[0].name :
    aws_ssm_parameter.cloudwatch_agent_config_windows[0].name
  ) : null
}

output "detailed_monitoring_enabled" {
  description = "Whether detailed monitoring is enabled for the instance"
  value       = var.enable_detailed_monitoring
}

# =============================================================================
# NAT GATEWAY OUTPUTS
# =============================================================================

output "nat_gateway_id" {
  description = "ID of the NAT Gateway (if created)"
  value       = var.create_nat_gateway ? aws_nat_gateway.this[0].id : null
}

output "nat_gateway_allocation_id" {
  description = "Allocation ID of the Elastic IP used by NAT Gateway (if created)"
  value       = var.create_nat_gateway ? aws_nat_gateway.this[0].allocation_id : null
}

output "nat_gateway_network_interface_id" {
  description = "Network interface ID of the NAT Gateway (if created)"
  value       = var.create_nat_gateway ? aws_nat_gateway.this[0].network_interface_id : null
}

output "nat_gateway_private_ip" {
  description = "Private IP address of the NAT Gateway (if created)"
  value       = var.create_nat_gateway ? aws_nat_gateway.this[0].private_ip : null
}

output "nat_gateway_public_ip" {
  description = "Public IP address of the NAT Gateway (if created)"
  value       = var.create_nat_gateway ? aws_nat_gateway.this[0].public_ip : null
}

output "nat_gateway_subnet_id" {
  description = "Subnet ID where the NAT Gateway is deployed (if created)"
  value       = var.create_nat_gateway ? aws_nat_gateway.this[0].subnet_id : null
}

# =============================================================================
# ROUTE TABLE OUTPUTS
# =============================================================================

output "private_route_table_id" {
  description = "ID of the private route table (if created)"
  value       = var.create_private_route_table ? aws_route_table.private[0].id : null
}

output "private_route_table_association_id" {
  description = "ID of the private route table association (if created)"
  value       = var.create_private_route_table && var.subnet_id != null ? aws_route_table_association.private[0].id : null
}

# =============================================================================
# VPC ENDPOINT OUTPUTS
# =============================================================================

output "existing_ssm_endpoint_id" {
  description = "ID of existing SSM VPC endpoint found in the VPC"
  value       = var.create_vpc_endpoints && var.check_for_existing_vpc_endpoints ? data.aws_vpc_endpoint.existing_ssm[0].id : null
}

output "existing_ec2messages_endpoint_id" {
  description = "ID of existing EC2Messages VPC endpoint found in the VPC"
  value       = var.create_vpc_endpoints && var.check_for_existing_vpc_endpoints ? data.aws_vpc_endpoint.existing_ec2messages[0].id : null
}

output "existing_ssmmessages_endpoint_id" {
  description = "ID of existing SSMMessages VPC endpoint found in the VPC"
  value       = var.create_vpc_endpoints && var.check_for_existing_vpc_endpoints ? data.aws_vpc_endpoint.existing_ssmmessages[0].id : null
}

output "created_ssm_endpoint_id" {
  description = "ID of the SSM VPC endpoint created by this module (if any)"
  value = var.create_vpc_endpoints && (
    var.check_for_existing_vpc_endpoints ? !local.existing_ssm_endpoint_exists : true
  ) ? aws_vpc_endpoint.ssm[0].id : null
}

output "created_ec2messages_endpoint_id" {
  description = "ID of the EC2Messages VPC endpoint created by this module (if any)"
  value = var.create_vpc_endpoints && (
    var.check_for_existing_vpc_endpoints ? !local.existing_ec2messages_endpoint_exists : true
  ) ? aws_vpc_endpoint.ec2messages[0].id : null
}

output "created_ssmmessages_endpoint_id" {
  description = "ID of the SSMMessages VPC endpoint created by this module (if any)"
  value = var.create_vpc_endpoints && (
    var.check_for_existing_vpc_endpoints ? !local.existing_ssmmessages_endpoint_exists : true
  ) ? aws_vpc_endpoint.ssmmessages[0].id : null
}

output "vpc_endpoints_reused" {
  description = "Boolean indicating if existing VPC endpoints were reused"
  value = var.create_vpc_endpoints && var.check_for_existing_vpc_endpoints ? (
    data.aws_vpc_endpoint.existing_ssm[0].id != null ||
    data.aws_vpc_endpoint.existing_ec2messages[0].id != null ||
    data.aws_vpc_endpoint.existing_ssmmessages[0].id != null
  ) : false
}
