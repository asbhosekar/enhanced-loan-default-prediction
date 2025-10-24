# Create Working EC2 Instance for Enhanced Loan Default API
Write-Host "🚀 Creating working EC2 instance..." -ForegroundColor Green

# Get default VPC and subnet
$vpcId = aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query "Vpcs[0].VpcId" --output text
$subnetId = aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpcId" --query "Subnets[0].SubnetId" --output text

# Create security group
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$sgName = "loan-api-working-$timestamp"
$securityGroupId = aws ec2 create-security-group --group-name $sgName --description "Working Enhanced Loan API" --vpc-id $vpcId --query "GroupId" --output text

# Add security rules
aws ec2 authorize-security-group-ingress --group-id $securityGroupId --protocol tcp --port 22 --cidr 0.0.0.0/0 | Out-Null
aws ec2 authorize-security-group-ingress --group-id $securityGroupId --protocol tcp --port 8080 --cidr 0.0.0.0/0 | Out-Null

Write-Host "✅ Security group created: $securityGroupId" -ForegroundColor Green

# Simple working user data script
$userData = @"
#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "=== Starting Enhanced Loan Default API Setup ==="
date

# Update system
yum update -y

# Install Docker
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

echo "Docker installed and started"

# Wait for Docker to be fully ready
sleep 30

echo "Pulling Docker image..."
docker pull asbhosekar/enhanced-loan-default-prediction:v2.3

echo "Starting API container..."
docker run -d \
  -p 8080:9000 \
  --name enhanced-loan-api \
  --restart unless-stopped \
  asbhosekar/enhanced-loan-default-prediction:v2.3

# Wait and verify
sleep 30
echo "=== Container Status ==="
docker ps

echo "=== Testing API locally ==="
curl -f http://localhost:8080/health && echo "API is working!" || echo "API not ready yet"

echo "=== Setup completed ==="
date
"@

$userDataEncoded = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($userData))

# Launch instance
Write-Host "🖥️ Launching EC2 instance..." -ForegroundColor Yellow
$instanceId = aws ec2 run-instances `
    --image-id ami-0c02fb55956c7d316 `
    --count 1 `
    --instance-type t3.small `
    --security-group-ids $securityGroupId `
    --subnet-id $subnetId `
    --user-data $userDataEncoded `
    --associate-public-ip-address `
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=enhanced-loan-api-working-$timestamp}]" `
    --query "Instances[0].InstanceId" `
    --output text

if ($instanceId -like "i-*") {
    Write-Host "✅ Instance launched: $instanceId" -ForegroundColor Green
    
    Write-Host "⏳ Waiting for instance to be running..." -ForegroundColor Yellow
    aws ec2 wait instance-running --instance-ids $instanceId
    
    $publicIp = aws ec2 describe-instances --instance-ids $instanceId --query "Reservations[0].Instances[0].PublicIpAddress" --output text
    
    Write-Host ""
    Write-Host "🎉 NEW EC2 INSTANCE READY!" -ForegroundColor Green
    Write-Host "=========================" -ForegroundColor Green
    Write-Host "Instance ID: $instanceId" -ForegroundColor Cyan
    Write-Host "Public IP: $publicIp" -ForegroundColor Cyan
    Write-Host "API URL: http://$publicIp`:8080" -ForegroundColor Yellow
    Write-Host "Health Check: http://$publicIp`:8080/health" -ForegroundColor Yellow
    Write-Host "=========================" -ForegroundColor Green
    Write-Host ""
    Write-Host "⏳ Docker setup will take 3-4 minutes..." -ForegroundColor Yellow
    Write-Host "Then test with Postman at: http://$publicIp`:8080" -ForegroundColor Magenta
    
    # Wait and test
    Write-Host "⏳ Waiting 4 minutes for complete setup..." -ForegroundColor Yellow
    Start-Sleep -Seconds 240
    
    Write-Host "🧪 Testing new EC2 API..." -ForegroundColor Cyan
    try {
        $response = Invoke-RestMethod -Uri "http://$publicIp`:8080/health" -Method GET -TimeoutSec 15
        Write-Host "🎉 SUCCESS! EC2 API IS READY FOR POSTMAN!" -ForegroundColor Green
        Write-Host "Use this URL in Postman: http://$publicIp`:8080" -ForegroundColor Magenta
        $response | ConvertTo-Json
    } catch {
        Write-Host "⏳ Still starting up - check again in 2 minutes" -ForegroundColor Yellow
        Write-Host "URL to test: http://$publicIp`:8080/health" -ForegroundColor White
    }
    
} else {
    Write-Host "❌ Failed to launch instance" -ForegroundColor Red
}