# Enhanced Loan Default API - New EC2 Deployment Script
# This script creates a new EC2 instance with proper Docker setup

param(
    [string]$KeyPairName = "loan-api-key",
    [string]$SecurityGroupName = "loan-api-sg",
    [string]$InstanceName = "enhanced-loan-api"
)

Write-Host "🚀 Starting new EC2 deployment for Enhanced Loan Default API..." -ForegroundColor Green

# Create or use existing key pair
Write-Host "📋 Checking for existing key pair..." -ForegroundColor Yellow
$keyExists = aws ec2 describe-key-pairs --key-names $KeyPairName --query "KeyPairs[0].KeyName" --output text 2>$null
if ($keyExists -ne $KeyPairName) {
    Write-Host "🔑 Creating new key pair: $KeyPairName" -ForegroundColor Cyan
    aws ec2 create-key-pair --key-name $KeyPairName --query "KeyMaterial" --output text | Out-File -FilePath ".\$KeyPairName.pem" -Encoding ASCII
    Write-Host "✅ Key saved to: $KeyPairName.pem" -ForegroundColor Green
} else {
    Write-Host "✅ Using existing key pair: $KeyPairName" -ForegroundColor Green
}

# Get default VPC
$vpcId = aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query "Vpcs[0].VpcId" --output text
Write-Host "🌐 Using VPC: $vpcId" -ForegroundColor Cyan

# Create security group
Write-Host "🔒 Creating security group..." -ForegroundColor Yellow
$sgExists = aws ec2 describe-security-groups --group-names $SecurityGroupName --query "SecurityGroups[0].GroupId" --output text 2>$null
if ($sgExists -like "sg-*") {
    $securityGroupId = $sgExists
    Write-Host "✅ Using existing security group: $securityGroupId" -ForegroundColor Green
} else {
    $securityGroupId = aws ec2 create-security-group --group-name $SecurityGroupName --description "Security group for Enhanced Loan Default API" --vpc-id $vpcId --query 'GroupId' --output text
    
    # Add rules
    aws ec2 authorize-security-group-ingress --group-id $securityGroupId --protocol tcp --port 22 --cidr 0.0.0.0/0
    aws ec2 authorize-security-group-ingress --group-id $securityGroupId --protocol tcp --port 8080 --cidr 0.0.0.0/0
    aws ec2 authorize-security-group-ingress --group-id $securityGroupId --protocol tcp --port 80 --cidr 0.0.0.0/0
    aws ec2 authorize-security-group-ingress --group-id $securityGroupId --protocol tcp --port 443 --cidr 0.0.0.0/0
    
    Write-Host "✅ Created security group: $securityGroupId" -ForegroundColor Green
}

# User data script for EC2 instance
$userData = @"
#!/bin/bash
yum update -y
yum install -y docker

# Start Docker service
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Wait for Docker to be ready
sleep 10

# Pull and run the Enhanced Loan Default API
docker pull asbhosekar/enhanced-loan-default-prediction:v2.3
docker run -d -p 8080:9000 --name enhanced-loan-api --restart unless-stopped asbhosekar/enhanced-loan-default-prediction:v2.3

# Install SSM Agent for Session Manager
yum install -y amazon-ssm-agent
systemctl start amazon-ssm-agent
systemctl enable amazon-ssm-agent

echo "✅ Enhanced Loan Default API deployment completed!" > /var/log/deployment.log
"@

$userDataEncoded = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($userData))

# Launch EC2 instance
Write-Host "🖥️ Launching new EC2 instance..." -ForegroundColor Yellow
$instanceId = aws ec2 run-instances `
    --image-id ami-0c02fb55956c7d316 `
    --count 1 `
    --instance-type t3.small `
    --key-name $KeyPairName `
    --security-group-ids $securityGroupId `
    --user-data $userDataEncoded `
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$InstanceName}]" `
    --iam-instance-profile Name=EC2-SSM-Role `
    --query "Instances[0].InstanceId" \
    --output text

if ($instanceId -like "i-*") {
    Write-Host "✅ Instance launched: $instanceId" -ForegroundColor Green
    
    # Wait for instance to be running
    Write-Host "⏳ Waiting for instance to be running..." -ForegroundColor Yellow
    aws ec2 wait instance-running --instance-ids $instanceId
    
    # Get public IP
    $publicIp = aws ec2 describe-instances --instance-ids $instanceId --query "Reservations[0].Instances[0].PublicIpAddress" --output text
    
    Write-Host "🎉 Deployment Summary:" -ForegroundColor Green
    Write-Host "  Instance ID: $instanceId" -ForegroundColor Cyan
    Write-Host "  Public IP: $publicIp" -ForegroundColor Cyan
    Write-Host "  API URL: http://$publicIp:8080" -ForegroundColor Cyan
    Write-Host "  Health Check: http://$publicIp:8080/health" -ForegroundColor Cyan
    Write-Host "  SSH Command: ssh -i $KeyPairName.pem ec2-user@$publicIp" -ForegroundColor Cyan
    
    Write-Host "⏳ Please wait 2-3 minutes for the API to start, then test:" -ForegroundColor Yellow
    Write-Host "  curl http://$publicIp:8080/health" -ForegroundColor White
    
} else {
    Write-Host "❌ Failed to launch instance" -ForegroundColor Red
}