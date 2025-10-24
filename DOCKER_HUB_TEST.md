# 🐳 Docker Hub Quick Test

## Test the Public Docker Image

### 1. **Pull and Run**
```bash
# Pull the latest image from Docker Hub
docker pull asbhoskar/enhanced-loan-default-prediction:latest

# Run the container
docker run -d -p 9000:9000 --name test-loan-api asbhoskar/enhanced-loan-default-prediction:latest

# Wait a moment for startup, then test
sleep 10
```

### 2. **Test Health Endpoint**
```bash
# Test health check
curl http://localhost:9000/health
```

**Expected Response:**
```json
{
  "status": "ok",
  "model_loaded": true,
  "model_path": "/app/exported_model_tuned",
  "service": "Enhanced Loan Default Prediction API"
}
```

### 3. **Test Prediction**
```bash
# Test a loan prediction
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

**Expected Response:**
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

### 4. **Clean Up**
```bash
# Stop and remove the test container
docker stop test-loan-api
docker rm test-loan-api
```

## 🌟 **Success Indicators**

✅ **Image pulls successfully from Docker Hub**  
✅ **Container starts without errors**  
✅ **Health endpoint returns 200 OK**  
✅ **Prediction endpoint returns valid response**  
✅ **Response time under 100ms**  
✅ **Model performance metrics displayed**  

## 🔗 **Links**

- **Docker Hub:** https://hub.docker.com/r/asbhoskar/enhanced-loan-default-prediction
- **GitHub:** https://github.com/asbhosekar/enhanced-loan-default-prediction
- **API Docs:** http://localhost:9000/docs (when running)

Your Docker image is now publicly available and ready for global use! 🌍