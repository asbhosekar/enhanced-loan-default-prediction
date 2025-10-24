# 🚀 Quick EC2 Manual Deployment - Enhanced Loan Default Prediction API

## Step-by-Step Manual Deployment

### **Prerequisites**
- EC2 instance running Amazon Linux 2 or Ubuntu
- SSH access to the instance
- Security group allowing ports 22, 80, and 9000

---

## **1. Connect to Your EC2 Instance**
```bash
# SSH into your EC2 instance
ssh -i your-key.pem ec2-user@YOUR_EC2_PUBLIC_IP
```

## **2. Install Docker**
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

# Refresh group membership (or logout/login)
newgrp docker

# Verify Docker installation
docker --version
```

## **3. Deploy Your API (The Command You Asked For)**
```bash
# Pull your Docker image from Docker Hub
sudo docker pull asbhoskar/enhanced-loan-default-prediction:v2.1

# Run the container
sudo docker run -d \
    -p 9000:9000 \
    --name loan-api \
    --restart unless-stopped \
    asbhoskar/enhanced-loan-default-prediction:v2.1

# Verify container is running
sudo docker ps

# Check container logs
sudo docker logs loan-api
```

## **4. Test Your Deployment**
```bash
# Test health endpoint locally
curl http://localhost:9000/health

# Test from outside (replace with your actual public IP)
curl http://YOUR_EC2_PUBLIC_IP:9000/health

# Test prediction endpoint
curl -X POST "http://YOUR_EC2_PUBLIC_IP:9000/predict" \
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
```

## **5. Expected Results**

### **Health Check Response:**
```json
{
  "status": "ok",
  "model_loaded": true,
  "model_path": "/app/exported_model_tuned",
  "service": "Enhanced Loan Default Prediction API",
  "model_type": "tuned_model"
}
```

### **Prediction Response:**
```json
{
  "prediction": {
    "default_probability": 0.0505,
    "default_probability_percent": "5.05%",
    "binary_prediction": 0,
    "prediction_label": "No Default"
  },
  "risk_assessment": {
    "risk_level": "Very Low",
    "risk_color": "green",
    "confidence": "High"
  },
  "recommendation": {
    "decision": "Approve",
    "reasoning": "Based on 5.05% default probability and very low risk level"
  }
}
```

---

## **🔧 Optional: Set Up Monitoring**

### **Create Health Check Script**
```bash
# Create monitoring script
cat > ~/monitor-api.sh << 'EOF'
#!/bin/bash
while true; do
    response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9000/health)
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [ $response -eq 200 ]; then
        echo "[$timestamp] ✅ API is healthy"
    else
        echo "[$timestamp] ❌ API is down (HTTP $response), restarting..."
        sudo docker restart loan-api
        sleep 30
    fi
    
    sleep 300  # Check every 5 minutes
done
EOF

chmod +x ~/monitor-api.sh

# Run monitoring in background
nohup ~/monitor-api.sh > ~/api-monitor.log 2>&1 &
```

### **View Container Stats**
```bash
# Monitor container performance
sudo docker stats loan-api

# View real-time logs
sudo docker logs -f loan-api

# Check system resources
free -h
df -h
top
```

---

## **🛡️ Security Best Practices**

### **1. Update Security Group (AWS Console)**
- Restrict SSH (port 22) to your IP only
- Keep API port 9000 open to 0.0.0.0/0 for public access
- Add HTTPS (port 443) if you plan to use SSL

### **2. Set Up Firewall (Optional)**
```bash
# Enable firewall
sudo systemctl start firewalld
sudo systemctl enable firewalld

# Add required ports
sudo firewall-cmd --permanent --add-port=9000/tcp
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --reload
```

---

## **🎯 Quick Commands Summary**

```bash
# One-liner deployment (after Docker is installed)
sudo docker pull asbhoskar/enhanced-loan-default-prediction:v2.1 && \
sudo docker run -d -p 9000:9000 --name loan-api --restart unless-stopped asbhoskar/enhanced-loan-default-prediction:v2.1

# Quick health check
curl http://localhost:9000/health

# View API documentation
# Open in browser: http://YOUR_EC2_PUBLIC_IP:9000/docs

# Container management
sudo docker stop loan-api      # Stop container
sudo docker start loan-api     # Start container
sudo docker restart loan-api   # Restart container
sudo docker logs loan-api      # View logs
sudo docker rm loan-api        # Remove container (after stop)
```

---

## **📊 Performance Tips**

### **For Production Use:**
```bash
# Run with resource limits
sudo docker run -d \
    -p 9000:9000 \
    --name loan-api \
    --restart unless-stopped \
    --memory="1g" \
    --cpus="1.0" \
    asbhoskar/enhanced-loan-default-prediction:v2.1

# Enable log rotation
sudo docker run -d \
    -p 9000:9000 \
    --name loan-api \
    --restart unless-stopped \
    --log-driver json-file \
    --log-opt max-size=10m \
    --log-opt max-file=3 \
    asbhoskar/enhanced-loan-default-prediction:v2.1
```

---

## **✅ Success Checklist**

- [ ] EC2 instance accessible via SSH
- [ ] Docker installed and running
- [ ] Image pulled successfully: `asbhoskar/enhanced-loan-default-prediction:v2.1`
- [ ] Container running on port 9000
- [ ] Health check returns HTTP 200
- [ ] Prediction endpoint working
- [ ] External access confirmed (from outside EC2)
- [ ] Security group configured properly
- [ ] Monitoring set up (optional)

## **🎉 You're Live!**

Your Enhanced Loan Default Prediction API is now running on AWS EC2!

**Access your API at:**
- Health: `http://YOUR_EC2_PUBLIC_IP:9000/health`
- Docs: `http://YOUR_EC2_PUBLIC_IP:9000/docs`
- Predict: `http://YOUR_EC2_PUBLIC_IP:9000/predict`

**Performance:** 94.64% ROC-AUC, 88.24% Precision, <50ms response time! 🚀