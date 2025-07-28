# Terragrunt Configuration Examples

This directory contains example Terragrunt configurations for different use cases and environments. Each example demonstrates best practices for security, networking, and infrastructure management.

## Security Best Practices

Before using any of these examples in production, please review and customize the following security configurations:

### 🔐 Critical Security Items to Review

1. **SSH/RDP Access**: Never use `0.0.0.0/0` for SSH or RDP access
   ```hcl
   # ❌ BAD - Allows access from anywhere
   allowed_ssh_cidrs = ["0.0.0.0/0"]
   
   # ✅ GOOD - Restricts access to specific networks
   allowed_ssh_cidrs = ["10.0.100.0/24", "203.0.113.0/24"]
   ```

2. **Hardcoded Resource IDs**: Replace example IDs with your actual resource IDs
   ```hcl
   # ❌ BAD - Example placeholder
   vpc_id = "vpc-12345678"
   
   # ✅ GOOD - Use dependency outputs or variables
   vpc_id = dependency.vpc.outputs.vpc_id
   ```

3. **IAM Role ARNs**: Update with your actual role ARNs
   ```hcl
   assume_role_arn = "arn:aws:iam::${get_aws_account_id()}:role/YourTerraformRole"
   ```

4. **KMS Keys**: Use your organization's KMS keys for encryption
   ```hcl
   kms_key_id = "arn:aws:kms:region:account:key/your-key-id"
   ```

## Example Files

### Basic Examples
- `../terragrunt.hcl` - Basic development instance with minimal security
- `windows-instance.hcl` - Windows Server with enhanced security
- `secure-web-server.hcl` - Linux web server with custom VPC

### Advanced Examples
- `private-instance.hcl` - Database server in private subnet
- `production-secure.hcl` - Production-ready secure configuration

## Common Configuration Patterns

### Using Dependencies
```hcl
dependency "vpc" {
  config_path = "../vpc"
}

inputs = {
  vpc_id    = dependency.vpc.outputs.vpc_id
  subnet_id = dependency.vpc.outputs.private_subnet_ids[0]
}
```

### Environment-Specific Variables
```hcl
# In terragrunt.hcl
locals {
  environment = "production"
  
  # Environment-specific settings
  instance_configs = {
    development = {
      instance_type = "t3.micro"
      volume_size   = 10
    }
    production = {
      instance_type = "t3.small"
      volume_size   = 30
    }
  }
}

inputs = merge(
  local.instance_configs[local.environment],
  {
    instance_name = "${local.environment}-web-server"
    # ... other configs
  }
)
```

### Secure User Data Management
```hcl
# Store user data in separate files
user_data = filebase64("${get_parent_terragrunt_dir()}/user-data/web-server-init.sh")
```

## Validation Checklist

Before deploying any configuration, ensure:

- [ ] SSH/RDP access is restricted to specific IP ranges
- [ ] All hardcoded resource IDs are replaced with actual values
- [ ] IAM role ARNs are correct for your environment
- [ ] KMS encryption is enabled with appropriate keys
- [ ] Egress rules are properly restricted for sensitive workloads
- [ ] Comprehensive tagging is applied for governance
- [ ] User data scripts don't contain sensitive information
- [ ] Instance termination protection is enabled for production

## Getting Help

If you need assistance with these configurations:
1. Review the main module documentation in the parent README
2. Check AWS best practices documentation
3. Consult with your security team for network and access requirements
4. Test configurations in a development environment first

## Contributing

When adding new examples:
- Follow the established naming convention
- Include comprehensive comments explaining security decisions
- Validate configurations against security best practices
- Update this README with any new patterns or considerations
