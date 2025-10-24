# 🏦 Enhanced Loan Default Prediction API

**Advanced ML Pipeline with 94.64% ROC-AUC & 88.24% Precision**

A production-ready machine learning system for loan default prediction using MLflow, FastAPI, and advanced feature engineering. This containerized API transforms raw loan application data into intelligent risk assessments with comprehensive business recommendations.

## 🚀 **Key Features**

✅ **Exceptional Performance:** 94.64% ROC-AUC, 88.24% Precision (exceeds industry targets)  
✅ **Advanced ML:** Gradient Boosting with 26 engineered features  
✅ **Production Ready:** <50ms response time, auto-scaling capable  
✅ **Business Intelligence:** Detailed risk assessment and approval recommendations  
✅ **Docker Optimized:** Lightweight (~200MB), secure, health-checked  

## 🐳 **Quick Start with Docker**

### **Run the API**
```bash
# Pull and run the latest image
docker run -d -p 9000:9000 asbhoskar/enhanced-loan-default-prediction:latest

# Test the health endpoint
curl http://localhost:9000/health

# Test a prediction
curl -X POST "http://localhost:9000/predict" \
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

### **Docker Compose (Recommended)**
```yaml
version: '3.8'
services:
  loan-api:
    image: asbhoskar/enhanced-loan-default-prediction:latest
    ports:
      - "9000:9000"
    environment:
      - MODEL_PATH=/app/exported_model_tuned
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
```

## 📊 **API Endpoints**

| Endpoint | Method | Description |
|----------|---------|-------------|
| `/health` | GET | System health and model status |
| `/model-info` | GET | Detailed model performance metrics |
| `/predict` | POST | Single loan application prediction |
| `/batch-predict` | POST | Multiple applications processing |
| `/docs` | GET | Interactive API documentation |

## 🎯 **Example Response**

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
  },
  "feature_analysis": {
    "income_to_loan_ratio": 4.0,
    "monthly_payment": 555.56,
    "payment_to_income_ratio": 0.0833,
    "risk_score": 0,
    "credit_score_category": "Excellent"
  }
}
```

## 🛠 **Technology Stack**

- **ML Framework:** scikit-learn with Gradient Boosting
- **API Framework:** FastAPI with automatic documentation
- **Experiment Tracking:** MLflow for model versioning
- **Containerization:** Docker with multi-stage optimization
- **Base Image:** python:3.11-slim (security hardened)

## 📈 **Model Performance**

| Model | ROC-AUC | Precision | Recall | Status |
|-------|---------|-----------|--------|---------|
| **Gradient Boosting** | **94.64%** | **88.24%** | 79.31% | ✅ **Selected** |
| Random Forest | 94.35% | 78.95% | 83.33% | ✅ Excellent |
| Logistic Regression | 89.39% | 68.18% | 88.89% | ✅ Good |

## 🔧 **Environment Variables**

| Variable | Default | Description |
|----------|---------|-------------|
| `MODEL_PATH` | `/app/exported_model_tuned` | Path to model artifacts |
| `PORT` | `9000` | API server port |

## 🌐 **Deployment Options**

### **Local Development**
```bash
docker run -p 9000:9000 asbhoskar/enhanced-loan-default-prediction:latest
```

### **Production (with volume mounting)**
```bash
docker run -d \
  -p 9000:9000 \
  -v $(pwd)/logs:/app/logs \
  --name loan-api \
  asbhoskar/enhanced-loan-default-prediction:latest
```

### **Kubernetes**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: loan-default-api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: loan-default-api
  template:
    metadata:
      labels:
        app: loan-default-api
    spec:
      containers:
      - name: api
        image: asbhoskar/enhanced-loan-default-prediction:latest
        ports:
        - containerPort: 9000
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
```

## 🛡️ **Security Features**

- ✅ Non-root user execution
- ✅ Minimal attack surface (slim base image)
- ✅ Health check endpoints
- ✅ Input validation and sanitization
- ✅ No sensitive data in logs

## 📚 **Documentation**

- **API Docs:** `http://localhost:9000/docs` (Swagger UI)
- **GitHub:** [Enhanced Loan Default Prediction](https://github.com/asbhosekar/enhanced-loan-default-prediction)
- **Postman Collection:** Complete testing guide included

## 🏷️ **Tags**

- `latest` - Most recent stable version
- `v2.1` - Specific version with enhanced features
- `v2.0` - Initial production release

## 💡 **Use Cases**

- **Financial Institutions:** Real-time loan approval decisions
- **FinTech Applications:** Risk assessment APIs
- **Credit Scoring:** Enhanced underwriting processes
- **ML Pipeline:** Reference implementation for classification

## 🤝 **Contributing**

This is an open-source project. Contributions welcome!

1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## 📄 **License**

MIT License - see repository for details

---

**Built with ❤️ for intelligent loan decision making**

🌟 **Star this repository if you find it useful!**