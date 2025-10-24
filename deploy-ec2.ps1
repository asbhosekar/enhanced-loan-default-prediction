# 🚀 PowerShell EC2 Deployment Script for Enhanced Loan Default Prediction API

param(
    [Parameter(Mandatory=$true)]
    [string]$KeyName,           # Your EC2 key pair name
    
    [string]$Region = "us-east-1",              # AWS region
    [string]$InstanceType = "t3.small",         # Instance type
    [string]$SecurityGroup = "loan-api-sg",     # Security group name
    [string]$AmiId = "ami-0c02fb55956c7d316"   # Amazon Linux 2 AMI
)

Write-Host "🚀 Starting EC2 deployment for Enhanced Loan Default Prediction API" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Yellow

# Check if AWS CLI is configured
try {
    aws sts get-caller-identity | Out-Null
    Write-Host "✅ AWS CLI is configured" -ForegroundColor Green
} catch {
    Write-Host "❌ AWS CLI not configured. Run 'aws configure' first." -ForegroundColor Red
    exit 1
}

# 1. Create Security Group
Write-Host "🛡️ Creating security group..." -ForegroundColor Cyan
try {
    aws ec2 create-security-group --group-name $SecurityGroup --description "Security group for Enhanced Loan Default API" --region $Region 2>$null
    Write-Host "✅ Security group created" -ForegroundColor Green
} catch {
    Write-Host "ℹ️ Security group already exists" -ForegroundColor Yellow
}

# Get Security Group ID
$SgId = (aws ec2 describe-security-groups --group-names $SecurityGroup --query 'SecurityGroups[0].GroupId' --output text --region $Region)
Write-Host "🔑 Security Group ID: $SgId" -ForegroundColor Cyan

# 2. Add Security Group Rules
Write-Host "🔐 Configuring security group rules..." -ForegroundColor Cyan

$rules = @(
    @{Port=22; Description="SSH"},
    @{Port=9000; Description="API"},
    @{Port=80; Description="HTTP"}
)

foreach ($rule in $rules) {
    try {
        aws ec2 authorize-security-group-ingress --group-id $SgId --protocol tcp --port $rule.Port --cidr 0.0.0.0/0 --region $Region 2>$null
        Write-Host "✅ Added $($rule.Description) rule (port $($rule.Port))" -ForegroundColor Green
    } catch {
        Write-Host "ℹ️ $($rule.Description) rule already exists" -ForegroundColor Yellow
    }
}

# 3. Create User Data Script
Write-Host "📝 Creating user data script..." -ForegroundColor Cyan

$userDataScript = @'
#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "Starting Enhanced Loan Default API deployment..."

# Update system
yum update -y

# Install Docker
yum install -y docker htop curl
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Pull and run the API
echo "Pulling Docker image: asbhoskar/enhanced-loan-default-prediction:v2.1"
docker pull asbhoskar/enhanced-loan-default-prediction:v2.1

echo "Starting API container..."
docker run -d \
    -p 9000:9000 \
    --name loan-api \
    --restart unless-stopped \
    --memory="1g" \
    --cpus="1.0" \
    asbhoskar/enhanced-loan-default-prediction:v2.1

# Wait for API to start
sleep 30

# Verify API health
echo "Verifying API health..."
for i in {1..12}; do
    if curl -f http://localhost:9000/health; then
        echo "✅ API is healthy and ready!"
        break
    else
        echo "⏳ Waiting for API to start (attempt $i/12)..."
        sleep 10
    fi
done

# Create monitoring scripts
cat > /home/ec2-user/api-status.sh << 'STATUS_EOF'
#!/bin/bash
echo "🏦 Enhanced Loan Default Prediction API - Status"
echo "=================================================="
echo "🌐 Public IP: $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo "🔗 Health: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9000/health"
echo "📚 Docs: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9000/docs"
echo "🐳 Container: $(docker ps --format 'table {{.Names}}\t{{.Status}}' | grep loan-api)"
echo "📊 Performance: $(curl -s http://localhost:9000/health | grep -o '"roc_auc":[^,]*' | cut -d: -f2)"
echo "=================================================="
STATUS_EOF

chmod +x /home/ec2-user/api-status.sh

# Health monitoring
cat > /home/ec2-user/health-monitor.sh << 'HEALTH_EOF'
#!/bin/bash
response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9000/health)
if [ $response -eq 200 ]; then
    echo "$(date): ✅ API healthy" >> /var/log/api-monitor.log
else
    echo "$(date): ❌ API down, restarting..." >> /var/log/api-monitor.log
    docker restart loan-api
fi
HEALTH_EOF

chmod +x /home/ec2-user/health-monitor.sh
echo "*/5 * * * * /home/ec2-user/health-monitor.sh" | crontab -u ec2-user -

echo "✅ Deployment script completed!"
'@

$userDataScript | Out-File -FilePath "user-data.sh" -Encoding ASCII

# 4. Launch EC2 Instance
Write-Host "🚀 Launching EC2 instance..." -ForegroundColor Cyan

$instanceId = (aws ec2 run-instances `
    --image-id $AmiId `
    --count 1 `
    --instance-type $InstanceType `
    --key-name $KeyName `
    --security-group-ids $SgId `
    --user-data file://user-data.sh `
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=enhanced-loan-api},{Key=Project,Value=LoanDefaultPrediction}]' `
    --query 'Instances[0].InstanceId' `
    --output text `
    --region $Region)

Write-Host "🏗️ Instance ID: $instanceId" -ForegroundColor Yellow
Write-Host "⏳ Waiting for instance to be running..." -ForegroundColor Cyan

# 5. Wait for instance to be running
aws ec2 wait instance-running --instance-ids $instanceId --region $Region

# 6. Get instance details
$instanceInfo = (aws ec2 describe-instances `
    --instance-ids $instanceId `
    --query 'Reservations[0].Instances[0].[PublicIpAddress,PrivateIpAddress,State.Name]' `
    --output text `
    --region $Region).Split("`t")

$publicIp = $instanceInfo[0]
$privateIp = $instanceInfo[1]
$state = $instanceInfo[2]

# Display results
Write-Host ""
Write-Host "✅ EC2 deployment completed successfully!" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Yellow
Write-Host "🆔 Instance ID: $instanceId" -ForegroundColor Cyan
Write-Host "🌐 Public IP: $publicIp" -ForegroundColor Cyan
Write-Host "🏠 Private IP: $privateIp" -ForegroundColor Cyan
Write-Host "📍 Region: $Region" -ForegroundColor Cyan
Write-Host "🔧 Instance Type: $InstanceType" -ForegroundColor Cyan
Write-Host "⚡ State: $state" -ForegroundColor Cyan
Write-Host ""
Write-Host "🔗 API Endpoints:" -ForegroundColor Green
Write-Host "   Health Check: http://$publicIp:9000/health" -ForegroundColor White
Write-Host "   Prediction: http://$publicIp:9000/predict" -ForegroundColor White
Write-Host "   API Docs: http://$publicIp:9000/docs" -ForegroundColor White
Write-Host ""
Write-Host "🔌 SSH Connection:" -ForegroundColor Green
Write-Host "   ssh -i $KeyName.pem ec2-user@$publicIp" -ForegroundColor White
Write-Host ""
Write-Host "⏰ Note: API may take 2-3 minutes to fully start." -ForegroundColor Yellow
Write-Host ""
Write-Host "🧪 Test Commands:" -ForegroundColor Green
Write-Host "   # Health check" -ForegroundColor Gray
Write-Host "   curl http://$publicIp:9000/health" -ForegroundColor White
Write-Host ""
Write-Host "   # Test prediction" -ForegroundColor Gray
Write-Host "   Invoke-RestMethod -Uri 'http://$publicIp:9000/predict' -Method POST -Headers @{'Content-Type'='application/json'} -Body '{`"age`":35,`"annual_income`":80000,`"employment_length`":8,`"home_ownership`":`"OWN`",`"purpose`":`"home_improvement`",`"loan_amount`":20000,`"term_months`":36,`"interest_rate`":8.5,`"dti`":15.2,`"credit_score`":780,`"delinquency_2yrs`":0,`"num_open_acc`":4}'" -ForegroundColor White

# Clean up
Remove-Item "user-data.sh" -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "🎉 Your Enhanced Loan Default Prediction API is now deploying!" -ForegroundColor Green
Write-Host "🌟 Docker image: asbhoskar/enhanced-loan-default-prediction:v2.1" -ForegroundColor Magenta
Write-Host ""
Write-Host "💡 Quick test in a few minutes:" -ForegroundColor Yellow
Write-Host "   curl http://$publicIp:9000/health" -ForegroundColor White