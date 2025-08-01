# PowerShell script to download private key from SSM Parameter Store
# Usage: .\download-private-key.ps1 -ParameterName "/ec2/keypair/my-instance-key/private_key" [-OutputFile "my-key.pem"]

param(
    [Parameter(Mandatory=$true)]
    [string]$ParameterName,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputFile
)

# Set default output file if not provided
if (-not $OutputFile) {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $baseName = Split-Path $ParameterName -Leaf
    $OutputFile = "$baseName-$timestamp.pem"
}

Write-Host "Downloading private key from SSM Parameter Store..." -ForegroundColor Green
Write-Host "Parameter: $ParameterName" -ForegroundColor Cyan
Write-Host "Output file: $OutputFile" -ForegroundColor Cyan

try {
    # Check if AWS CLI is available
    $awsCliPath = Get-Command aws -ErrorAction SilentlyContinue
    if (-not $awsCliPath) {
        throw "AWS CLI is not installed or not in PATH. Please install AWS CLI first."
    }
    
    # Download the private key from SSM Parameter Store
    $privateKey = aws ssm get-parameter --name $ParameterName --with-decryption --query 'Parameter.Value' --output text 2>$null
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to retrieve parameter from SSM"
    }
    
    # Save the private key to file
    $privateKey | Out-File -FilePath $OutputFile -Encoding ASCII -NoNewline
    
    # Set file permissions (Windows equivalent of chmod 600)
    $acl = Get-Acl $OutputFile
    $acl.SetAccessRuleProtection($true, $false)  # Disable inheritance
    $acl.SetAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule([System.Security.Principal.WindowsIdentity]::GetCurrent().Name, "FullControl", "Allow")))
    Set-Acl -Path $OutputFile -AclObject $acl
    
    Write-Host ""
    Write-Host "✅ Private key downloaded successfully!" -ForegroundColor Green
    Write-Host "File: $OutputFile" -ForegroundColor Yellow
    
    $fileInfo = Get-Item $OutputFile
    Write-Host "Size: $($fileInfo.Length) bytes" -ForegroundColor Yellow
    Write-Host "Created: $($fileInfo.CreationTime)" -ForegroundColor Yellow
    
    Write-Host ""
    Write-Host "You can now use this key file for:" -ForegroundColor Cyan
    Write-Host "  - SSH connections: ssh -i $OutputFile ec2-user@<instance-ip>" -ForegroundColor White
    Write-Host "  - RDP password retrieval: aws ec2 get-password-data --instance-id <instance-id> --priv-launch-key $OutputFile" -ForegroundColor White
    Write-Host ""
    Write-Host "⚠️  Keep this private key secure and do not share it!" -ForegroundColor Red
    
} catch {
    Write-Host "❌ Failed to download private key from SSM Parameter Store." -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please check:" -ForegroundColor Yellow
    Write-Host "  1. The parameter name is correct: $ParameterName" -ForegroundColor White
    Write-Host "  2. You have proper AWS credentials configured" -ForegroundColor White
    Write-Host "  3. You have permission to access the SSM parameter" -ForegroundColor White
    Write-Host "  4. The parameter exists in the current AWS region" -ForegroundColor White
    exit 1
}
