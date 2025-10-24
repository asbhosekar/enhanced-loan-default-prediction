# Enhanced EC2 Deployment with SSM Support
Write-Host "Creating EC2 instance with proper configuration..." -ForegroundColor Green

# Get default VPC and subnet
$vpcId = aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query "Vpcs[0].VpcId" --output text
$subnetId = aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpcId" --query "Subnets[0].SubnetId" --output text

# Create security group
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$sgName = "loan-api-sg-$timestamp"
$securityGroupId = aws ec2 create-security-group --group-name $sgName --description "Enhanced Loan API" --vpc-id $vpcId --query "GroupId" --output text

# Add security rules
aws ec2 authorize-security-group-ingress --group-id $securityGroupId --protocol tcp --port 22 --cidr 0.0.0.0/0 | Out-Null
aws ec2 authorize-security-group-ingress --group-id $securityGroupId --protocol tcp --port 8080 --cidr 0.0.0.0/0 | Out-Null

Write-Host "Security group created: $securityGroupId" -ForegroundColor Green

# Enhanced user data script
$userData = @"
#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting Enhanced Loan Default API setup..."

# Update system
yum update -y

# Install Docker
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Install SSM Agent
yum install -y amazon-ssm-agent
systemctl start amazon-ssm-agent
systemctl enable amazon-ssm-agent

echo "Waiting for Docker to be ready..."
sleep 30

# Pull and run the API
echo "Pulling Docker image..."
docker pull asbhosekar/enhanced-loan-default-prediction:v2.3

echo "Starting API container..."
docker run -d -p 8080:9000 --name enhanced-loan-api --restart unless-stopped asbhosekar/enhanced-loan-default-prediction:v2.3

# Wait a bit and check container
sleep 20
docker ps

# Create status check script
cat << 'EOF' > /home/ec2-user/check-status.sh
#!/bin/bash
echo "=== Docker Status ==="
docker ps
echo ""
echo "=== API Health Check ==="
curl -f http://localhost:8080/health || echo "API not ready yet"
echo ""
echo "=== Container Logs ==="
docker logs enhanced-loan-api --tail 10
EOF
chmod +x /home/ec2-user/check-status.sh

echo "Setup completed! API should be available on port 8080"
"@

$userDataEncoded = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($userData))

# Launch instance with IAM role
Write-Host "Launching instance..." -ForegroundColor Yellow
$instanceId = aws ec2 run-instances `
    --image-id ami-0c02fb55956c7d316 `
    --count 1 `
    --instance-type t3.small `
    --security-group-ids $securityGroupId `
    --subnet-id $subnetId `
    --user-data $userDataEncoded `
    --associate-public-ip-address `
    --iam-instance-profile Name=EC2-SSM-Role `
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=enhanced-loan-api-$timestamp}]" `
    --query "Instances[0].InstanceId" `
    --output text 2>$null

if (-not $instanceId -or $instanceId -eq "None") {
    Write-Host "Creating instance without IAM role..." -ForegroundColor Yellow
    $instanceId = aws ec2 run-instances `
        --image-id ami-0c02fb55956c7d316 `
        --count 1 `
        --instance-type t3.small `
        --security-group-ids $securityGroupId `
        --subnet-id $subnetId `
        --user-data $userDataEncoded `
        --associate-public-ip-address `
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=enhanced-loan-api-$timestamp}]" `
        --query "Instances[0].InstanceId" `
        --output text
}

if ($instanceId -like "i-*") {
    Write-Host "Instance launched: $instanceId" -ForegroundColor Green
    
    Write-Host "Waiting for instance to be running..." -ForegroundColor Yellow
    aws ec2 wait instance-running --instance-ids $instanceId
    
    $publicIp = aws ec2 describe-instances --instance-ids $instanceId --query "Reservations[0].Instances[0].PublicIpAddress" --output text
    
    Write-Host ""
    Write-Host "=== DEPLOYMENT SUCCESS ===" -ForegroundColor Green
    Write-Host "Instance ID: $instanceId" -ForegroundColor Cyan
    Write-Host "Public IP: $publicIp" -ForegroundColor Cyan
    Write-Host "API URL: http://$publicIp:8080" -ForegroundColor Yellow
    Write-Host "Health Check: http://$publicIp:8080/health" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Wait 3-4 minutes for setup to complete, then test with:" -ForegroundColor Yellow
    Write-Host "Invoke-RestMethod http://$publicIp:8080/health" -ForegroundColor White
    Write-Host ""
    
    # Save the new IP for testing
    $global:EC2_API_URL = "http://$publicIp:8080"
    Write-Host "New EC2 API URL saved: $global:EC2_API_URL" -ForegroundColor Magenta
    
} else {
    Write-Host "Failed to launch instance" -ForegroundColor Red
}