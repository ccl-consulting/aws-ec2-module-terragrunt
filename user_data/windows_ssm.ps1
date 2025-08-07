<powershell>
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$region = "${region}"
$LogFile = "C:\\ssm-debug.log"
"[$(Get-Date)] Starting SSM install in $region" | Out-File $LogFile

# Determine if the region is in China and adjust the S3 domain accordingly
if ($region -like "cn-*") {
    $s3Domain = "amazonaws.com.cn"
    $ssmDomain = "amazonaws.com.cn"
} else {
    $s3Domain = "amazonaws.com"
    $ssmDomain = "amazonaws.com"
}

try {
  $url = "https://s3.${region}.${s3Domain}/amazon-ssm-${region}/latest/windows_amd64/AmazonSSMAgentSetup.exe"
  $out = "C:\\AmazonSSMAgentSetup.exe"
  Invoke-WebRequest -Uri $url -OutFile $out
  Start-Process -FilePath $out -ArgumentList "/quiet" -Wait
  Start-Service AmazonSSMAgent
  Set-Service -Name AmazonSSMAgent -StartupType Automatic
  "[$(Get-Date)] SSM agent installed and started successfully." | Out-File $LogFile -Append
} catch {
  "[$(Get-Date)] Error during SSM agent setup: $_" | Out-File $LogFile -Append
}

Test-NetConnection "ssm.${region}.${ssmDomain}" -Port 443 | Out-File "C:\\ssm-connectivity.log"
</powershell>
