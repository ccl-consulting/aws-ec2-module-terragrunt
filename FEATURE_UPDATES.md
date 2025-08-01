# Feature Updates: Session Manager & Key Pair Management

This document summarizes the new features added to the AWS EC2 module for enhanced Session Manager support and automatic key pair creation.

## New Features Added

### 1. Enhanced Session Manager Permissions

#### What was added:
- New IAM policy with enhanced Session Manager permissions
- Support for `ssmmessages` API calls required for Session Manager functionality
- S3 encryption configuration access for session logs

#### New Variables:
- `enable_session_manager_permissions` (bool, default: true) - Adds enhanced Session Manager permissions

#### IAM Permissions Added:
```json
{
  "Effect": "Allow",
  "Action": [
    "ssmmessages:CreateControlChannel",
    "ssmmessages:CreateDataChannel", 
    "ssmmessages:OpenControlChannel",
    "ssmmessages:OpenDataChannel"
  ],
  "Resource": "*"
},
{
  "Effect": "Allow",
  "Action": [
    "s3:GetEncryptionConfiguration"
  ],
  "Resource": "*"
}
```

### 2. Automated Key Pair Creation

#### What was added:
- Automatic key pair generation using Terraform TLS provider
- Option to use existing public key material
- Secure storage of private keys in SSM Parameter Store
- Support for both generated and user-provided public keys

#### New Variables:
- `create_key_pair` (bool, default: false) - Create a new key pair
- `key_pair_name` (string, default: "${instance_name}-key") - Name for the key pair
- `public_key` (string, default: null) - Use existing public key material
- `save_private_key` (bool, default: true) - Store private key in SSM Parameter Store

#### New Outputs:
- `key_pair_created` - Whether a key pair was created
- `key_pair_name` - Name of the key pair used
- `key_pair_id` - ID of the created key pair
- `key_pair_arn` - ARN of the created key pair
- `key_pair_fingerprint` - Fingerprint of the key pair
- `private_key_ssm_parameter` - SSM parameter path for private key
- `private_key_pem` - Private key in PEM format (sensitive)
- `public_key_openssh` - Public key in OpenSSH format

### 3. Private Key Download Scripts

#### What was added:
- Bash script for Linux/Mac users (`scripts/download-private-key.sh`)
- PowerShell script for Windows users (`scripts/download-private-key.ps1`)
- Automatic permission setting (chmod 600 equivalent)
- Error handling and user guidance

#### Script Features:
- Download private keys from SSM Parameter Store
- Set proper file permissions
- Provide usage instructions for SSH/RDP
- Input validation and error handling

## Usage Examples

### Enable Enhanced Session Manager Permissions
```hcl
inputs = {
  instance_name = "my-instance"
  
  # Enhanced Session Manager permissions (enabled by default)
  enable_session_manager_permissions = true
  
  # Other configuration...
}
```

### Create Windows Instance with Auto-Generated Key Pair
```hcl
inputs = {
  instance_name    = "windows-server-01"
  operating_system = "windows"
  
  # Auto-generate key pair for Windows password retrieval
  create_key_pair  = true
  key_pair_name    = "windows-server-01-key"
  save_private_key = true
  
  # Other configuration...
}
```

### Download Private Key After Deployment
```bash
# Get the SSM parameter path from Terraform output
terraform output private_key_ssm_parameter

# Download using the provided script
./scripts/download-private-key.sh "/ec2/keypair/windows-server-01-key/private_key"

# For Windows password retrieval
aws ec2 get-password-data --instance-id i-1234567890abcdef0 --priv-launch-key windows-server-01-key.pem
```

## Backward Compatibility

All changes are backward compatible:
- Existing deployments continue to work without modification
- New features are opt-in with sensible defaults
- No breaking changes to existing variables or outputs

## Files Modified/Added

### Modified Files:
- `main.tf` - Added Session Manager policy and key pair creation logic
- `variables.tf` - Added new variables for Session Manager and key pair features
- `outputs.tf` - Added new outputs for key pair information

### New Files:
- `scripts/download-private-key.sh` - Bash script for private key download
- `scripts/download-private-key.ps1` - PowerShell script for private key download
- `KEY_PAIR_USAGE.md` - Comprehensive guide for key pair functionality
- `FEATURE_UPDATES.md` - This summary document

## Security Enhancements

1. **Secure Key Storage**: Private keys stored as SecureString in SSM Parameter Store
2. **Proper Permissions**: Scripts automatically set restrictive file permissions
3. **Access Control**: IAM permissions follow least-privilege principle
4. **Encryption**: Support for encrypted session manager logs

## Problem Solved

### Before:
- Manual key pair creation required
- No built-in Session Manager enhanced permissions  
- Windows instances needed manual password retrieval setup
- Private key management left to users

### After:
- Automated key pair generation and management
- Enhanced Session Manager permissions included by default
- Seamless Windows password retrieval workflow
- Secure private key storage and retrieval system

This update significantly improves the user experience for both Linux SSH access and Windows RDP access scenarios.
