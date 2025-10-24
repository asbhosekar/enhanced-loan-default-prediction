# Fix EC2 Security Group for Enhanced Loan Default API
Write-Host "🔧 Fixing EC2 security group for instance i-015aa68dd387864a7..." -ForegroundColor Green

# Get the instance's security group
$instanceId = "i-015aa68dd387864a7"
$securityGroupId = aws ec2 describe-instances --instance-ids $instanceId --query "Reservations[0].Instances[0].SecurityGroups[0].GroupId" --output text

Write-Host "Security Group ID: $securityGroupId" -ForegroundColor Cyan

# Add inbound rules for ports 8080 and 9000 if they don't exist
Write-Host "Adding inbound rules for ports 8080 and 9000..." -ForegroundColor Yellow

try {
    # Add port 8080
    aws ec2 authorize-security-group-ingress --group-id $securityGroupId --protocol tcp --port 8080 --cidr 0.0.0.0/0 2>$null
    Write-Host "✅ Port 8080 rule added" -ForegroundColor Green
} catch {
    Write-Host "ℹ️ Port 8080 rule already exists" -ForegroundColor Blue
}

try {
    # Add port 9000
    aws ec2 authorize-security-group-ingress --group-id $securityGroupId --protocol tcp --port 9000 --cidr 0.0.0.0/0 2>$null
    Write-Host "✅ Port 9000 rule added" -ForegroundColor Green
} catch {
    Write-Host "ℹ️ Port 9000 rule already exists" -ForegroundColor Blue
}

Write-Host ""
Write-Host "🔍 Current security group rules:" -ForegroundColor Yellow
aws ec2 describe-security-groups --group-ids $securityGroupId --query "SecurityGroups[0].IpPermissions[*].[IpProtocol,FromPort,ToPort,IpRanges[0].CidrIp]" --output table

Write-Host ""
Write-Host "⏳ Waiting 30 seconds for rules to take effect..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

Write-Host "🧪 Testing EC2 API after security group fix..." -ForegroundColor Cyan
try {
    $response = Invoke-RestMethod -Uri "http://98.92.230.238:8080/health" -Method GET -TimeoutSec 10
    Write-Host "🎉 SUCCESS! EC2 API is now accessible!" -ForegroundColor Green
    $response
} catch {
    Write-Host "⚠️ Still not accessible. Trying port 9000..." -ForegroundColor Yellow
    try {
        $response = Invoke-RestMethod -Uri "http://98.92.230.238:9000/health" -Method GET -TimeoutSec 10
        Write-Host "🎉 SUCCESS! EC2 API is accessible on port 9000!" -ForegroundColor Green
        $response
    } catch {
        Write-Host "❌ Docker container may need to be restarted manually" -ForegroundColor Red
        Write-Host "This would require SSH access to the instance" -ForegroundColor White
    }
}