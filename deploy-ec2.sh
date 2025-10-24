#!/bin/bash
# 🚀 Quick EC2 Deployment Script for Enhanced Loan Default Prediction API

set -e

# Configuration (UPDATE THESE VALUES)
KEY_NAME="your-key-pair-name"          # Your EC2 key pair name
REGION="us-east-1"                     # AWS region
INSTANCE_TYPE="t3.small"               # Instance type
SECURITY_GROUP="loan-api-sg"           # Security group name

# AMI ID for Amazon Linux 2 (update for your region)
AMI_ID="ami-0c02fb55956c7d316"

echo "🚀 Starting EC2 deployment for Enhanced Loan Default Prediction API"
echo "=================================================="

# Check if AWS CLI is configured
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "❌ AWS CLI not configured. Run 'aws configure' first."
    exit 1
fi

# 1. Create Security Group
echo "🛡️ Creating security group..."
aws ec2 create-security-group \
    --group-name $SECURITY_GROUP \
    --description "Security group for Enhanced Loan Default API" \
    --region $REGION 2>/dev/null || echo "Security group already exists"

# Get Security Group ID
SG_ID=$(aws ec2 describe-security-groups \
    --group-names $SECURITY_GROUP \
    --query 'SecurityGroups[0].GroupId' \
    --output text \
    --region $REGION)

echo "🔑 Security Group ID: $SG_ID"

# 2. Add Security Group Rules
echo "🔐 Configuring security group rules..."
aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0 \
    --region $REGION 2>/dev/null || echo "SSH rule already exists"

aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 9000 \
    --cidr 0.0.0.0/0 \
    --region $REGION 2>/dev/null || echo "API port rule already exists"

aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0 \
    --region $REGION 2>/dev/null || echo "HTTP rule already exists"

# 3. Create User Data Script
echo "📝 Creating user data script..."
cat > user-data.sh << 'EOF'
#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "Starting user data script execution..."

# Update system
yum update -y

# Install Docker
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install monitoring tools
yum install -y htop curl

# Pull and run the Enhanced Loan Default API
echo "Pulling Docker image..."
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

# Verify API is running
echo "Verifying API health..."
for i in {1..12}; do
    if curl -f http://localhost:9000/health; then
        echo "✅ API is healthy!"
        break
    else
        echo "⏳ Waiting for API to start (attempt $i/12)..."
        sleep 10
    fi
done

# Create health check script
cat > /home/ec2-user/health-check.sh << 'HEALTH_EOF'
#!/bin/bash
LOG_FILE="/var/log/api-health.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9000/health)
if [ $response -eq 200 ]; then
    echo "[$TIMESTAMP] ✅ API is healthy" >> $LOG_FILE
else
    echo "[$TIMESTAMP] ❌ API is down (HTTP $response), restarting..." >> $LOG_FILE
    docker restart loan-api
    sleep 30
    new_response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9000/health)
    echo "[$TIMESTAMP] 🔄 Restart attempt, new status: $new_response" >> $LOG_FILE
fi
HEALTH_EOF

chmod +x /home/ec2-user/health-check.sh

# Add health check to cron (every 5 minutes)
echo "*/5 * * * * /home/ec2-user/health-check.sh" | crontab -u ec2-user -

# Create API info script
cat > /home/ec2-user/api-info.sh << 'INFO_EOF'
#!/bin/bash
echo "🏦 Enhanced Loan Default Prediction API - Server Info"
echo "=================================================="
echo "🌐 Public IP: $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo "🔗 API Health: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9000/health"
echo "📚 API Docs: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9000/docs"
echo "🐳 Container Status: $(docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | grep loan-api)"
echo "📊 Container Stats:"
docker stats loan-api --no-stream
echo "=================================================="
INFO_EOF

chmod +x /home/ec2-user/api-info.sh

# Set up log rotation
cat > /etc/logrotate.d/api-health << 'LOGROTATE_EOF'
/var/log/api-health.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
LOGROTATE_EOF

echo "✅ User data script completed successfully!"
EOF

# 4. Launch EC2 Instance
echo "🚀 Launching EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --count 1 \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-group-ids $SG_ID \
    --user-data file://user-data.sh \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=enhanced-loan-api},{Key=Project,Value=LoanDefaultPrediction},{Key=Environment,Value=Production}]' \
    --query 'Instances[0].InstanceId' \
    --output text \
    --region $REGION)

echo "🏗️ Instance ID: $INSTANCE_ID"
echo "⏳ Waiting for instance to be running..."

# 5. Wait for instance to be running
aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $REGION

# 6. Get instance details
INSTANCE_INFO=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --query 'Reservations[0].Instances[0].[PublicIpAddress,PrivateIpAddress,State.Name]' \
    --output text \
    --region $REGION)

PUBLIC_IP=$(echo $INSTANCE_INFO | cut -d' ' -f1)
PRIVATE_IP=$(echo $INSTANCE_INFO | cut -d' ' -f2)
STATE=$(echo $INSTANCE_INFO | cut -d' ' -f3)

echo "✅ EC2 deployment completed successfully!"
echo "=================================================="
echo "🆔 Instance ID: $INSTANCE_ID"
echo "🌐 Public IP: $PUBLIC_IP"
echo "🏠 Private IP: $PRIVATE_IP"
echo "📍 Region: $REGION"
echo "🔧 Instance Type: $INSTANCE_TYPE"
echo "⚡ State: $STATE"
echo ""
echo "🔗 API Endpoints:"
echo "   Health Check: http://$PUBLIC_IP:9000/health"
echo "   Prediction: http://$PUBLIC_IP:9000/predict"
echo "   API Docs: http://$PUBLIC_IP:9000/docs"
echo ""
echo "🔌 SSH Connection:"
echo "   ssh -i $KEY_NAME.pem ec2-user@$PUBLIC_IP"
echo ""
echo "⏰ Note: API may take 2-3 minutes to fully start. Check status with:"
echo "   curl http://$PUBLIC_IP:9000/health"
echo ""
echo "📊 Monitor deployment:"
echo "   ssh -i $KEY_NAME.pem ec2-user@$PUBLIC_IP 'tail -f /var/log/user-data.log'"
echo ""
echo "🎯 Test prediction:"
echo "   curl -X POST 'http://$PUBLIC_IP:9000/predict' \\"
echo "        -H 'Content-Type: application/json' \\"
echo "        -d '{\"age\":35,\"annual_income\":80000,\"employment_length\":8,\"home_ownership\":\"OWN\",\"purpose\":\"home_improvement\",\"loan_amount\":20000,\"term_months\":36,\"interest_rate\":8.5,\"dti\":15.2,\"credit_score\":780,\"delinquency_2yrs\":0,\"num_open_acc\":4}'"

# Clean up
rm user-data.sh

echo ""
echo "🎉 Your Enhanced Loan Default Prediction API is now deploying to AWS EC2!"
echo "🌟 Docker image: asbhoskar/enhanced-loan-default-prediction:v2.1"