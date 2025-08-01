# Key Pair Management

This module includes functionality to create and manage EC2 key pairs, especially useful for Windows instances that require a key pair for password retrieval and RDP access.

## Overview

When you create a key pair with this module, you have several options:

1. **Generate a new key pair**: The module creates both public and private keys
2. **Use existing public key**: Provide your own public key material
3. **Store private key securely**: Save the generated private key to AWS SSM Parameter Store

## Variables

### Key Pair Configuration

- `create_key_pair` (bool): Whether to create a new key pair (default: false)
- `key_pair_name` (string): Name for the created key pair (default: "${instance_name}-key")
- `public_key` (string): Public key material to use (default: null - generates new key)
- `save_private_key` (bool): Whether to save generated private key to SSM (default: true)

## Usage Examples

### 1. Generate New Key Pair for Windows Instance

```hcl
inputs = {
  instance_name    = "windows-server-01"
  operating_system = "windows"
  
  # Key pair configuration
  create_key_pair = true
  key_pair_name   = "windows-server-01-key"
  save_private_key = true
  
  # Other instance configuration...
}
```

### 2. Use Existing Public Key

```hcl
inputs = {
  instance_name    = "my-instance"
  
  # Key pair configuration
  create_key_pair = true
  key_pair_name   = "my-existing-key"
  public_key      = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQ..." # Your public key
  
  # Other instance configuration...
}
```

### 3. Use Existing Key Pair (Traditional Approach)

```hcl
inputs = {
  instance_name = "my-instance"
  
  # Use existing key pair
  key_name = "my-existing-keypair-name"
  
  # Other instance configuration...
}
```

## Accessing the Private Key

When the module generates a private key, you have multiple ways to access it:

### Option 1: Terraform Output (Immediate Access)

The private key is available as a sensitive output:

```bash
# Get the private key directly from Terraform output
terraform output -raw private_key_pem > my-private-key.pem
chmod 600 my-private-key.pem
```

### Option 2: Download from SSM Parameter Store

The module stores the private key in AWS SSM Parameter Store for secure, long-term storage.

#### Using the Provided Scripts

**Linux/Mac:**
```bash
# Using the provided script
./scripts/download-private-key.sh "/ec2/keypair/windows-server-01-key/private_key"

# With custom output file
./scripts/download-private-key.sh "/ec2/keypair/windows-server-01-key/private_key" my-key.pem
```

**Windows PowerShell:**
```powershell
# Using the provided PowerShell script
.\scripts\download-private-key.ps1 -ParameterName "/ec2/keypair/windows-server-01-key/private_key"

# With custom output file
.\scripts\download-private-key.ps1 -ParameterName "/ec2/keypair/windows-server-01-key/private_key" -OutputFile "my-key.pem"
```

#### Using AWS CLI Directly

```bash
# Download private key from SSM Parameter Store
aws ssm get-parameter --name "/ec2/keypair/windows-server-01-key/private_key" --with-decryption --query 'Parameter.Value' --output text > my-private-key.pem

# Set proper permissions
chmod 600 my-private-key.pem
```

## Use Cases

### For Windows Instances (RDP Access)

1. **Create the instance** with key pair creation enabled
2. **Download the private key** using one of the methods above
3. **Retrieve the Windows password**:
   ```bash
   aws ec2 get-password-data --instance-id i-1234567890abcdef0 --priv-launch-key my-private-key.pem
   ```
4. **Connect via RDP** using the retrieved password

### For Linux Instances (SSH Access)

1. **Create the instance** with key pair creation enabled
2. **Download the private key** using one of the methods above
3. **Connect via SSH**:
   ```bash
   ssh -i my-private-key.pem ec2-user@<instance-public-ip>
   ```

## Outputs

The module provides several outputs related to key pairs:

- `key_pair_created`: Whether a key pair was created
- `key_pair_name`: Name of the key pair used
- `key_pair_id`: ID of the created key pair
- `key_pair_arn`: ARN of the created key pair
- `key_pair_fingerprint`: Fingerprint of the key pair
- `private_key_ssm_parameter`: SSM parameter path where private key is stored
- `private_key_pem`: The private key in PEM format (sensitive)
- `public_key_openssh`: The public key in OpenSSH format

## Security Considerations

1. **Private Key Storage**: Private keys are stored securely in AWS SSM Parameter Store as SecureString parameters
2. **Access Control**: Ensure proper IAM permissions are set for accessing SSM parameters
3. **File Permissions**: Always set proper permissions (600) on downloaded private key files
4. **Key Rotation**: Consider rotating keys periodically for enhanced security
5. **Cleanup**: Remove downloaded private key files when no longer needed

## Required Permissions

To use the key pair functionality, your Terraform execution role needs:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateKeyPair",
        "ec2:DeleteKeyPair",
        "ec2:DescribeKeyPairs",
        "ssm:PutParameter",
        "ssm:GetParameter",
        "ssm:DeleteParameter",
        "ssm:AddTagsToResource"
      ],
      "Resource": "*"
    }
  ]
}
```

To download private keys from SSM, users need:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter"
      ],
      "Resource": "arn:aws:ssm:*:*:parameter/ec2/keypair/*/*"
    }
  ]
}
```
