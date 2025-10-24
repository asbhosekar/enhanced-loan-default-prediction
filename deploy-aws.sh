#!/bin/bash
# 🚀 AWS Deployment Script for Enhanced Loan Default Prediction API
# Comprehensive deployment automation for AWS ECS with Fargate

set -e

# Configuration
AWS_REGION="us-east-1"
ECR_REPOSITORY="enhanced-loan-default-prediction"
CLUSTER_NAME="ml-prediction-cluster"
SERVICE_NAME="loan-default-service"
TASK_DEFINITION_NAME="loan-default-task"
IMAGE_TAG="latest"

echo "🚀 Starting AWS Deployment for Enhanced Loan Default Prediction API"
echo "=================================================="

# 1. Create ECR Repository
echo "📦 Creating ECR repository..."
aws ecr describe-repositories --repository-names $ECR_REPOSITORY --region $AWS_REGION 2>/dev/null || \
aws ecr create-repository --repository-name $ECR_REPOSITORY --region $AWS_REGION

# Get ECR login
echo "🔐 Logging into ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $(aws sts get-caller-identity --query Account --output text).dkr.ecr.$AWS_REGION.amazonaws.com

# 2. Build and tag Docker image
echo "🏗️ Building Docker image..."
docker build -t $ECR_REPOSITORY:$IMAGE_TAG .

# 3. Tag image for ECR
ECR_URI=$(aws sts get-caller-identity --query Account --output text).dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY:$IMAGE_TAG
docker tag $ECR_REPOSITORY:$IMAGE_TAG $ECR_URI

# 4. Push to ECR
echo "📤 Pushing image to ECR..."
docker push $ECR_URI

# 5. Create ECS Cluster
echo "🏗️ Creating ECS cluster..."
aws ecs describe-clusters --clusters $CLUSTER_NAME --region $AWS_REGION 2>/dev/null || \
aws ecs create-cluster --cluster-name $CLUSTER_NAME --capacity-providers FARGATE --region $AWS_REGION

# 6. Create IAM role for ECS task execution
echo "🔑 Creating IAM roles..."
aws iam get-role --role-name ecsTaskExecutionRole 2>/dev/null || \
aws iam create-role --role-name ecsTaskExecutionRole --assume-role-policy-document '{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}'

aws iam attach-role-policy --role-name ecsTaskExecutionRole --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

# 7. Create task definition
echo "📋 Creating ECS task definition..."
cat > task-definition.json << EOF
{
  "family": "$TASK_DEFINITION_NAME",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/ecsTaskExecutionRole",
  "containerDefinitions": [
    {
      "name": "loan-default-api",
      "image": "$ECR_URI",
      "portMappings": [
        {
          "containerPort": 9000,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "MODEL_PATH",
          "value": "/app/exported_model_tuned"
        },
        {
          "name": "PORT",
          "value": "9000"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/loan-default-api",
          "awslogs-region": "$AWS_REGION",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "python -c \"import requests; requests.get('http://localhost:9000/health')\" || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
EOF

aws ecs register-task-definition --cli-input-json file://task-definition.json --region $AWS_REGION

# 8. Create CloudWatch log group
echo "📊 Creating CloudWatch log group..."
aws logs describe-log-groups --log-group-name-prefix "/ecs/loan-default-api" --region $AWS_REGION 2>/dev/null || \
aws logs create-log-group --log-group-name "/ecs/loan-default-api" --region $AWS_REGION

# 9. Get default VPC and subnets
echo "🌐 Getting VPC information..."
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text --region $AWS_REGION)
SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[*].SubnetId' --output text --region $AWS_REGION)
SUBNET_ID_1=$(echo $SUBNET_IDS | cut -d' ' -f1)
SUBNET_ID_2=$(echo $SUBNET_IDS | cut -d' ' -f2)

# 10. Create security group
echo "🛡️ Creating security group..."
SECURITY_GROUP_ID=$(aws ec2 create-security-group --group-name loan-default-api-sg --description "Security group for Loan Default Prediction API" --vpc-id $VPC_ID --region $AWS_REGION --query 'GroupId' --output text 2>/dev/null || \
aws ec2 describe-security-groups --filters "Name=group-name,Values=loan-default-api-sg" --query 'SecurityGroups[0].GroupId' --output text --region $AWS_REGION)

# Add inbound rule for port 9000
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 9000 --cidr 0.0.0.0/0 --region $AWS_REGION 2>/dev/null || true

# 11. Create ECS service
echo "🚀 Creating ECS service..."
aws ecs create-service \
  --cluster $CLUSTER_NAME \
  --service-name $SERVICE_NAME \
  --task-definition $TASK_DEFINITION_NAME \
  --desired-count 1 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_ID_1,$SUBNET_ID_2],securityGroups=[$SECURITY_GROUP_ID],assignPublicIp=ENABLED}" \
  --region $AWS_REGION 2>/dev/null || \
aws ecs update-service \
  --cluster $CLUSTER_NAME \
  --service $SERVICE_NAME \
  --task-definition $TASK_DEFINITION_NAME \
  --region $AWS_REGION

echo "✅ Deployment completed successfully!"
echo "=================================================="
echo "🔍 To get the public IP of your service:"
echo "aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks \$(aws ecs list-tasks --cluster $CLUSTER_NAME --service-name $SERVICE_NAME --query 'taskArns[0]' --output text --region $AWS_REGION) --query 'tasks[0].attachments[0].details[?name==\`networkInterfaceId\`].value' --output text --region $AWS_REGION | xargs -I {} aws ec2 describe-network-interfaces --network-interface-ids {} --query 'NetworkInterfaces[0].Association.PublicIp' --output text --region $AWS_REGION"
echo ""
echo "🌐 Your API will be available at: http://[PUBLIC_IP]:9000"
echo "📊 Health check: http://[PUBLIC_IP]:9000/health"
echo "📚 API docs: http://[PUBLIC_IP]:9000/docs"