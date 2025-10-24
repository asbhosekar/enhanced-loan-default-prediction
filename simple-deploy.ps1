# Simple EC2 Deployment for Enhanced Loan Default API
Write-Host "Creating new EC2 instance..." -ForegroundColor Green

# Get default VPC and subnet
$vpcId = aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query "Vpcs[0].VpcId" --output text
$subnetId = aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpcId" --query "Subnets[0].SubnetId" --output text

Write-Host "Using VPC: $vpcId" -ForegroundColor Cyan

# Create security group
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$sgName = "loan-api-sg-$timestamp"
$securityGroupId = aws ec2 create-security-group --group-name $sgName --description "Enhanced Loan API" --vpc-id $vpcId --query "GroupId" --output text

# Add security rules
aws ec2 authorize-security-group-ingress --group-id $securityGroupId --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $securityGroupId --protocol tcp --port 8080 --cidr 0.0.0.0/0

Write-Host "Security group created: $securityGroupId" -ForegroundColor Green

# User data script
$userData = @"
#!/bin/bash
yum update -y
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user
sleep 15
docker pull asbhosekar/enhanced-loan-default-prediction:v2.3
docker run -d -p 8080:9000 --name enhanced-loan-api --restart unless-stopped asbhosekar/enhanced-loan-default-prediction:v2.3
"@

$userDataEncoded = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($userData))

# Launch instance
$instanceId = aws ec2 run-instances --image-id ami-0c02fb55956c7d316 --count 1 --instance-type t3.small --security-group-ids $securityGroupId --subnet-id $subnetId --user-data $userDataEncoded --associate-public-ip-address --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=enhanced-loan-api-$timestamp}]" --query "Instances[0].InstanceId" --output text

if ($instanceId -like "i-*") {
    Write-Host "Instance launched: $instanceId" -ForegroundColor Green
    
    Write-Host "Waiting for instance to be running..." -ForegroundColor Yellow
    aws ec2 wait instance-running --instance-ids $instanceId
    
    $publicIp = aws ec2 describe-instances --instance-ids $instanceId --query "Reservations[0].Instances[0].PublicIpAddress" --output text
    
    Write-Host ""
    Write-Host "SUCCESS!" -ForegroundColor Green
    Write-Host "Instance ID: $instanceId" -ForegroundColor Cyan
    Write-Host "Public IP: $publicIp" -ForegroundColor Cyan
    Write-Host "API URL: http://$publicIp:8080" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Wait 2-3 minutes then test with:" -ForegroundColor Yellow
    Write-Host "Invoke-RestMethod http://$publicIp:8080/health" -ForegroundColor White
    
} else {
    Write-Host "Failed to launch instance" -ForegroundColor Red
}