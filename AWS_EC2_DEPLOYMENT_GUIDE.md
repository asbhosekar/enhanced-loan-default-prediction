# 🚀 AWS EC2 Deployment Guide for Enhanced Loan Default Prediction API

## 📋 **Prerequisites**

### **1. AWS Account Setup**
- AWS account with EC2 access
- AWS CLI configured with credentials
- Key pair created for EC2 access

### **2. Required Tools**
```bash
# Install AWS CLI
pip install awscli

# Configure AWS credentials
aws configure
```

---

## 🏗️ **Option 1: Automated EC2 Deployment Script**

### **Create EC2 Instance with Docker**
```bash
#!/bin/bash
# deploy-ec2.sh - Automated EC2 deployment script

# Configuration
INSTANCE_TYPE="t3.small"
AMI_ID="ami-0c02fb55956c7d316"  # Amazon Linux 2 (update for your region)
KEY_NAME="your-key-pair-name"
SECURITY_GROUP="loan-api-sg"
REGION="us-east-1"

echo "🚀 Deploying Enhanced Loan Default Prediction API to EC2"

# 1. Create Security Group
aws ec2 create-security-group \
    --group-name $SECURITY_GROUP \
    --description "Security group for Loan Default API" \
    --region $REGION

# Get Security Group ID
SG_ID=$(aws ec2 describe-security-groups \
    --group-names $SECURITY_GROUP \
    --query 'SecurityGroups[0].GroupId' \
    --output text \
    --region $REGION)

# 2. Add Security Group Rules
aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0 \
    --region $REGION

aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 9000 \
    --cidr 0.0.0.0/0 \
    --region $REGION

aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0 \
    --region $REGION

# 3. Create User Data Script
cat > user-data.sh << 'EOF'
#!/bin/bash
yum update -y
yum install -y docker

# Start Docker service
systemctl start docker
systemctl enable docker

# Add ec2-user to docker group
usermod -a -G docker ec2-user

# Pull and run the API
docker pull asbhoskar/enhanced-loan-default-prediction:v2.1
docker run -d -p 9000:9000 --name loan-api --restart unless-stopped asbhoskar/enhanced-loan-default-prediction:v2.1

# Install nginx for reverse proxy (optional)
yum install -y nginx
systemctl start nginx
systemctl enable nginx

# Create nginx config for API
cat > /etc/nginx/conf.d/api.conf << 'NGINX_EOF'
server {
    listen 80;
    server_name _;
    
    location / {
        proxy_pass http://localhost:9000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
NGINX_EOF

systemctl reload nginx

# Create health check script
cat > /home/ec2-user/health-check.sh << 'HEALTH_EOF'
#!/bin/bash
response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9000/health)
if [ $response -eq 200 ]; then
    echo "✅ API is healthy"
else
    echo "❌ API is down, restarting..."
    docker restart loan-api
fi
HEALTH_EOF

chmod +x /home/ec2-user/health-check.sh

# Add health check to cron (every 5 minutes)
echo "*/5 * * * * /home/ec2-user/health-check.sh >> /var/log/api-health.log 2>&1" | crontab -u ec2-user -
EOF

# 4. Launch EC2 Instance
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --count 1 \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-group-ids $SG_ID \
    --user-data file://user-data.sh \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=loan-default-api}]' \
    --query 'Instances[0].InstanceId' \
    --output text \
    --region $REGION)

echo "🏗️ Launching EC2 instance: $INSTANCE_ID"

# 5. Wait for instance to be running
aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $REGION

# 6. Get public IP
PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text \
    --region $REGION)

echo "✅ Deployment completed!"
echo "🌐 Public IP: $PUBLIC_IP"
echo "🔗 API URL: http://$PUBLIC_IP:9000"
echo "🏥 Health Check: http://$PUBLIC_IP:9000/health"
echo "📚 API Docs: http://$PUBLIC_IP:9000/docs"
echo "🌍 Nginx Proxy: http://$PUBLIC_IP"

# Clean up
rm user-data.sh
```

---

## 🏗️ **Option 2: Manual Step-by-Step Deployment**

### **Step 1: Launch EC2 Instance**

#### **Via AWS Console:**
1. Go to EC2 Dashboard
2. Click "Launch Instance"
3. Choose AMI: Amazon Linux 2
4. Instance Type: t3.small (2 vCPU, 2GB RAM)
5. Configure Security Group:
   - SSH (22): Your IP
   - HTTP (80): 0.0.0.0/0
   - Custom TCP (9000): 0.0.0.0/0
6. Select existing key pair or create new
7. Launch instance

#### **Via AWS CLI:**
```bash
# Create security group
aws ec2 create-security-group --group-name loan-api-sg --description "Loan API Security Group"

# Add rules
aws ec2 authorize-security-group-ingress --group-name loan-api-sg --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-name loan-api-sg --protocol tcp --port 9000 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-name loan-api-sg --protocol tcp --port 80 --cidr 0.0.0.0/0

# Launch instance
aws ec2 run-instances \
    --image-id ami-0c02fb55956c7d316 \
    --count 1 \
    --instance-type t3.small \
    --key-name your-key-pair \
    --security-groups loan-api-sg \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=loan-api-server}]'
```

### **Step 2: Connect to EC2 Instance**
```bash
# SSH into instance
ssh -i your-key.pem ec2-user@YOUR_PUBLIC_IP
```

### **Step 3: Install Docker**
```bash
# Update system
sudo yum update -y

# Install Docker
sudo yum install -y docker

# Start Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Add user to docker group
sudo usermod -a -G docker ec2-user

# Logout and login again, or run:
newgrp docker

# Verify Docker installation
docker --version
```

### **Step 4: Deploy Your API**
```bash
# Pull your Docker image
sudo docker pull asbhoskar/enhanced-loan-default-prediction:v2.1

# Run the container
sudo docker run -d \
    -p 9000:9000 \
    --name loan-api \
    --restart unless-stopped \
    asbhoskar/enhanced-loan-default-prediction:v2.1

# Check if container is running
sudo docker ps

# Check logs
sudo docker logs loan-api
```

### **Step 5: Test the Deployment**
```bash
# Test health endpoint
curl http://localhost:9000/health

# Test from outside (replace with your public IP)
curl http://YOUR_PUBLIC_IP:9000/health
```

---

## 🔧 **Optional: Nginx Reverse Proxy Setup**

### **Install and Configure Nginx**
```bash
# Install Nginx
sudo yum install -y nginx

# Start Nginx
sudo systemctl start nginx
sudo systemctl enable nginx

# Create API configuration
sudo tee /etc/nginx/conf.d/api.conf << EOF
server {
    listen 80;
    server_name _;
    
    location / {
        proxy_pass http://localhost:9000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Test and reload Nginx
sudo nginx -t
sudo systemctl reload nginx
```

---

## 📊 **Monitoring and Maintenance**

### **Health Check Script**
```bash
# Create health check script
cat > ~/health-check.sh << 'EOF'
#!/bin/bash
LOG_FILE="/var/log/api-health.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9000/health)
if [ $response -eq 200 ]; then
    echo "[$TIMESTAMP] ✅ API is healthy" >> $LOG_FILE
else
    echo "[$TIMESTAMP] ❌ API is down (HTTP $response), restarting..." >> $LOG_FILE
    sudo docker restart loan-api
    sleep 30
    new_response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9000/health)
    echo "[$TIMESTAMP] 🔄 Restart attempt, new status: $new_response" >> $LOG_FILE
fi
EOF

chmod +x ~/health-check.sh

# Add to crontab (check every 5 minutes)
echo "*/5 * * * * /home/ec2-user/health-check.sh" | crontab -
```

### **Log Management**
```bash
# View API logs
sudo docker logs loan-api

# Follow real-time logs
sudo docker logs -f loan-api

# View health check logs
tail -f /var/log/api-health.log

# View system logs
sudo journalctl -u docker
```

### **Performance Monitoring**
```bash
# Monitor container stats
sudo docker stats loan-api

# Monitor system resources
htop
free -h
df -h

# Monitor API performance
curl -w "Response time: %{time_total}s\n" -o /dev/null -s http://localhost:9000/health
```

---

## 🛡️ **Security Best Practices**

### **1. Update Security Group Rules**
```bash
# Restrict SSH access to your IP only
aws ec2 authorize-security-group-ingress \
    --group-name loan-api-sg \
    --protocol tcp \
    --port 22 \
    --cidr YOUR_IP/32

# Remove broad SSH access
aws ec2 revoke-security-group-ingress \
    --group-name loan-api-sg \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0
```

### **2. SSL/TLS Setup (Optional)**
```bash
# Install certbot for Let's Encrypt
sudo yum install -y certbot python3-certbot-nginx

# Get SSL certificate (replace with your domain)
sudo certbot --nginx -d yourdomain.com

# Auto-renewal setup
echo "0 12 * * * /usr/bin/certbot renew --quiet" | sudo crontab -
```

### **3. Firewall Configuration**
```bash
# Enable firewall
sudo systemctl start firewalld
sudo systemctl enable firewalld

# Add required ports
sudo firewall-cmd --permanent --add-port=22/tcp
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --reload
```

---

## 💰 **Cost Optimization**

### **Instance Types and Costs (us-east-1)**
| Instance Type | vCPU | RAM | Cost/Month | Use Case |
|---------------|------|-----|------------|----------|
| t3.micro | 2 | 1GB | ~$9 | Testing/Development |
| t3.small | 2 | 2GB | ~$18 | Light Production |
| t3.medium | 2 | 4GB | ~$36 | Medium Load |
| t3.large | 2 | 8GB | ~$72 | High Load |

### **Cost Reduction Tips**
1. **Use Spot Instances** - 70% cost reduction
2. **Schedule Start/Stop** - Turn off during non-business hours
3. **Reserved Instances** - 1-year commitment for 40% savings
4. **CloudWatch Monitoring** - Track usage and optimize

---

## 🚀 **Auto-Scaling Setup (Advanced)**

### **Application Load Balancer + Auto Scaling**
```bash
# Create launch template
aws ec2 create-launch-template \
    --launch-template-name loan-api-template \
    --launch-template-data '{
        "ImageId": "ami-0c02fb55956c7d316",
        "InstanceType": "t3.small",
        "KeyName": "your-key-pair",
        "SecurityGroupIds": ["sg-xxxxxxxxx"],
        "UserData": "base64-encoded-user-data"
    }'

# Create Auto Scaling Group
aws autoscaling create-auto-scaling-group \
    --auto-scaling-group-name loan-api-asg \
    --launch-template LaunchTemplateName=loan-api-template,Version=1 \
    --min-size 1 \
    --max-size 3 \
    --desired-capacity 2 \
    --availability-zones us-east-1a us-east-1b
```

---

## ✅ **Deployment Checklist**

- [ ] EC2 instance launched and accessible
- [ ] Security groups configured properly
- [ ] Docker installed and running
- [ ] API container deployed and healthy
- [ ] External access verified (port 9000)
- [ ] Health checks working
- [ ] Nginx proxy configured (optional)
- [ ] SSL certificate installed (optional)
- [ ] Monitoring scripts deployed
- [ ] Backup strategy defined
- [ ] Cost monitoring enabled

## 🎯 **Testing Your Deployment**

```bash
# Test health endpoint
curl http://YOUR_PUBLIC_IP:9000/health

# Test prediction endpoint
curl -X POST "http://YOUR_PUBLIC_IP:9000/predict" \
  -H "Content-Type: application/json" \
  -d '{
    "age": 35,
    "annual_income": 80000,
    "employment_length": 8,
    "home_ownership": "OWN",
    "purpose": "home_improvement",
    "loan_amount": 20000,
    "term_months": 36,
    "interest_rate": 8.5,
    "dti": 15.2,
    "credit_score": 780,
    "delinquency_2yrs": 0,
    "num_open_acc": 4
  }'

# Load testing with Apache Bench
ab -n 100 -c 10 http://YOUR_PUBLIC_IP:9000/health
```

Your Enhanced Loan Default Prediction API is now live on AWS EC2! 🌟