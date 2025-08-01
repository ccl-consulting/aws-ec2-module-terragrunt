#!/bin/bash

# Script to download private key from SSM Parameter Store
# Usage: ./download-private-key.sh <ssm-parameter-name> [output-file]

set -euo pipefail

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <ssm-parameter-name> [output-file]"
    echo ""
    echo "Examples:"
    echo "  $0 /ec2/keypair/my-instance-key/private_key"
    echo "  $0 /ec2/keypair/my-instance-key/private_key my-key.pem"
    echo ""
    echo "Note: The private key will be saved with proper permissions (600)"
    exit 1
fi

SSM_PARAMETER_NAME="$1"
OUTPUT_FILE="${2:-$(basename "${SSM_PARAMETER_NAME}")-$(date +%Y%m%d-%H%M%S).pem}"

echo "Downloading private key from SSM Parameter Store..."
echo "Parameter: $SSM_PARAMETER_NAME"
echo "Output file: $OUTPUT_FILE"

# Download the private key from SSM Parameter Store
if aws ssm get-parameter --name "$SSM_PARAMETER_NAME" --with-decryption --query 'Parameter.Value' --output text > "$OUTPUT_FILE" 2>/dev/null; then
    # Set proper permissions for the private key file
    chmod 600 "$OUTPUT_FILE"
    
    echo "✅ Private key downloaded successfully!"
    echo "File: $OUTPUT_FILE"
    echo "Permissions: $(ls -la "$OUTPUT_FILE" | awk '{print $1, $3, $4, $9}')"
    echo ""
    echo "You can now use this key file for:"
    echo "  - SSH connections: ssh -i $OUTPUT_FILE ec2-user@<instance-ip>"
    echo "  - RDP password retrieval: aws ec2 get-password-data --instance-id <instance-id> --priv-launch-key $OUTPUT_FILE"
    echo ""
    echo "⚠️  Keep this private key secure and do not share it!"
else
    echo "❌ Failed to download private key from SSM Parameter Store."
    echo "Please check:"
    echo "  1. The parameter name is correct: $SSM_PARAMETER_NAME"
    echo "  2. You have proper AWS credentials configured"
    echo "  3. You have permission to access the SSM parameter"
    echo "  4. The parameter exists in the current AWS region"
    exit 1
fi
