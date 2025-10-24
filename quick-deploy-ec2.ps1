# Quick EC2 Deployment for Enhanced Loan Default API
Write-Host "🚀 Creating new EC2 instance for Enhanced Loan Default API..." -ForegroundColor Green

# Get default VPC and subnet
$vpcId = aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query "Vpcs[0].VpcId" --output text
$subnetId = aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpcId" --query "Subnets[0].SubnetId" --output text

Write-Host "🌐 Using VPC: $vpcId" -ForegroundColor Cyan
Write-Host "🌐 Using Subnet: $subnetId" -ForegroundColor Cyan

# Create simple security group
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$sgName = "loan-api-sg-$timestamp"
Write-Host "🔒 Creating security group: $sgName" -ForegroundColor Yellow

$securityGroupId = aws ec2 create-security-group `
    --group-name $sgName `
    --description "Security group for Enhanced Loan Default API" `
    --vpc-id $vpcId `
    --query "GroupId" `
    --output text

# Add security group rules
aws ec2 authorize-security-group-ingress --group-id $securityGroupId --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $securityGroupId --protocol tcp --port 8080 --cidr 0.0.0.0/0

Write-Host "✅ Security group created: $securityGroupId" -ForegroundColor Green

# User data script for EC2 instance
$userData = @"
#!/bin/bash
yum update -y
yum install -y docker

# Start Docker service
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Wait for Docker to be ready
sleep 15

# Pull and run the Enhanced Loan Default API
docker pull asbhosekar/enhanced-loan-default-prediction:v2.3
docker run -d -p 8080:9000 --name enhanced-loan-api --restart unless-stopped asbhosekar/enhanced-loan-default-prediction:v2.3

# Create a simple health check script
echo '#!/bin/bash' > /home/ec2-user/check-api.sh
echo 'curl -f http://localhost:8080/health || echo "API not ready yet"' >> /home/ec2-user/check-api.sh
chmod +x /home/ec2-user/check-api.sh

echo "✅ Enhanced Loan Default API setup completed!" > /var/log/deployment.log
echo "📊 API URL: http://\$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080" >> /var/log/deployment.log
"@

$userDataEncoded = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($userData))

# Launch EC2 instance
Write-Host "🖥️ Launching new EC2 instance..." -ForegroundColor Yellow

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

if ($instanceId -like "i-*") {
    Write-Host "✅ Instance launched: $instanceId" -ForegroundColor Green
    
    Write-Host "⏳ Waiting for instance to be running..." -ForegroundColor Yellow
    aws ec2 wait instance-running --instance-ids $instanceId
    
    # Get public IP
    $publicIp = aws ec2 describe-instances --instance-ids $instanceId --query "Reservations[0].Instances[0].PublicIpAddress" --output text
    
    Write-Host ""
    Write-Host "🎉 Deployment Successful!" -ForegroundColor Green
    Write-Host "===========================================" -ForegroundColor Green
    Write-Host "Instance ID: $instanceId" -ForegroundColor Cyan
    Write-Host "Public IP: $publicIp" -ForegroundColor Cyan
    Write-Host "API URL: http://$publicIp:8080" -ForegroundColor Yellow
    Write-Host "Health Check: http://$publicIp:8080/health" -ForegroundColor Yellow
    Write-Host "Security Group: $securityGroupId" -ForegroundColor Cyan
    Write-Host "===========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "⏳ Please wait 2-3 minutes for Docker to start the API..." -ForegroundColor Yellow
    Write-Host "Then test with: Invoke-RestMethod http://$publicIp:8080/health" -ForegroundColor White
    
    # Update the testing guide with new IP
    $newBaseUrl = "http://$publicIp:8080"
    Write-Host "📝 New EC2 Base URL: $newBaseUrl" -ForegroundColor Magenta
    
    return @{
        InstanceId = $instanceId
        PublicIp = $publicIp
        ApiUrl = $newBaseUrl
        SecurityGroup = $securityGroupId
    }
    
} else {
    Write-Host "❌ Failed to launch instance" -ForegroundColor Red
    return $null
}