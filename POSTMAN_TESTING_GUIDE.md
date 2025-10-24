# 🚀 Postman Testing Guide for Enhanced Loan Default Prediction API

## 📋 Quick Setup

**Base URL (Local):** `http://localhost:8080`  
**Base URL (AWS EC2):** `http://54.234.127.110:8080`  
**API Documentation:** Enhanced Loan Default Prediction API v2.1  
**Model:** Tuned Gradient Boosting (94.64% ROC-AUC, 88.24% Precision)

**🎯 Your Live API is Ready for Testing!**

---

## 🧪 Test Scenarios for Postman

### 1. **Health Check Endpoint**

**Request:**
```
GET http://localhost:8080/health
```

**Headers:**
```
Content-Type: application/json
```

**Expected Response:**
```json
{
  "status": "ok",
  "model_loaded": true,
  "model_path": "./exported_model_tuned",
  "service": "Enhanced Loan Default Prediction API",
  "model_type": "gradient_boost",
  "model_performance": {
    "roc_auc": 0.9463869463869464,
    "target_precision": ">80%",
    "target_roc_auc": ">85%"
  },
  "features": {
    "enhanced_feature_engineering": true,
    "risk_scoring": true,
    "precision_optimized": true
  }
}
```

---

### 2. **Model Information Endpoint**

**Request:**
```
GET http://localhost:8080/model-info
```

**Headers:**
```
Content-Type: application/json
```

**Expected Response:**
```json
{
  "model_details": {
    "best_model": "gradient_boost",
    "best_score": 0.9463869463869464,
    "all_results": {
      "logistic": {"roc_auc": 0.8939, "precision": 0.6818},
      "random_forest": {"roc_auc": 0.9435, "precision": 0.7895},
      "gradient_boost": {"roc_auc": 0.9464, "precision": 0.8824},
      "svm": {"roc_auc": 0.8916, "precision": 0.0000}
    }
  },
  "feature_engineering": {
    "original_features": [...],
    "enhanced_features": [...]
  }
}
```

---

### 3. **Single Loan Prediction - Low Risk Borrower**

**Request:**
```
POST http://localhost:8080/predict
```

**Headers:**
```
Content-Type: application/json
```

**Body (JSON):**
```json
{
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
}
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
  },
  "feature_analysis": {
    "income_to_loan_ratio": 4.0,
    "monthly_payment": 555.56,
    "payment_to_income_ratio": 0.0833,
    "risk_score": 0,
    "credit_score_category": "Excellent",
    "risk_factors": {
      "employment_risk": false,
      "high_interest": false,
      "young_borrower": false,
      "multiple_delinquencies": false,
      "many_open_accounts": false
    }
  },
  "model_info": {
    "model_type": "gradient_boost",
    "model_performance": "ROC-AUC: 0.946",
    "precision": "88.24%"
  }
}
```

---

### 4. **Single Loan Prediction - High Risk Borrower**

**Request:**
```
POST http://localhost:8080/predict
```

**Headers:**
```
Content-Type: application/json
```

**Body (JSON):**
```json
{
  "age": 22,
  "annual_income": 25000,
  "employment_length": 1,
  "home_ownership": "RENT",
  "purpose": "debt_consolidation",
  "loan_amount": 15000,
  "term_months": 60,
  "interest_rate": 18.5,
  "dti": 45.0,
  "credit_score": 580,
  "delinquency_2yrs": 3,
  "num_open_acc": 12
}
```

**Expected Response:**
```json
{
  "prediction": {
    "default_probability": 0.9139,
    "default_probability_percent": "91.39%",
    "binary_prediction": 1,
    "prediction_label": "Default"
  },
  "risk_assessment": {
    "risk_level": "Very High",
    "risk_color": "red",
    "confidence": "High"
  },
  "recommendation": {
    "decision": "Reject",
    "reasoning": "Based on 91.39% default probability and very high risk level"
  },
  "feature_analysis": {
    "income_to_loan_ratio": 1.67,
    "monthly_payment": 250.0,
    "payment_to_income_ratio": 0.12,
    "risk_score": 3,
    "credit_score_category": "Poor",
    "risk_factors": {
      "employment_risk": true,
      "high_interest": true,
      "young_borrower": true,
      "multiple_delinquencies": true,
      "many_open_accounts": false
    }
  }
}
```

---

### 5. **Batch Prediction (Multiple Applications)**

**Request:**
```
POST http://localhost:9000/predict
```

**Headers:**
```
Content-Type: application/json
```

**Body (JSON):**
```json
[
  {
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
  },
  {
    "age": 22,
    "annual_income": 25000,
    "employment_length": 1,
    "home_ownership": "RENT",
    "purpose": "debt_consolidation",
    "loan_amount": 15000,
    "term_months": 60,
    "interest_rate": 18.5,
    "dti": 45.0,
    "credit_score": 580,
    "delinquency_2yrs": 3,
    "num_open_acc": 12
  },
  {
    "age": 30,
    "annual_income": 55000,
    "employment_length": 5,
    "home_ownership": "MORTGAGE",
    "purpose": "credit_card",
    "loan_amount": 12000,
    "term_months": 36,
    "interest_rate": 12.0,
    "dti": 25.0,
    "credit_score": 680,
    "delinquency_2yrs": 1,
    "num_open_acc": 8
  }
]
```

**Expected Response:**
```json
{
  "summary": {
    "total_applications": 3,
    "successful_predictions": 3,
    "errors": 0,
    "high_risk_count": 1
  },
  "results": [
    {
      "application_id": 1,
      "status": "success",
      "result": { /* Full prediction response */ }
    },
    {
      "application_id": 2,
      "status": "success", 
      "result": { /* Full prediction response */ }
    },
    {
      "application_id": 3,
      "status": "success",
      "result": { /* Full prediction response */ }
    }
  ]
}
```

---

## 🎯 Testing Strategy in Postman

### **Step 1: Create a New Collection**
1. Open Postman
2. Click "New" → "Collection"
3. Name it: "Loan Default Prediction API v2.1"
4. Add description: "Enhanced ML model with 94.64% ROC-AUC"

### **Step 2: Set Up Environment Variables**
1. Click the gear icon (top right) → "Manage Environments"
2. Click "Add"
3. Environment name: "Loan Default API"
4. Add variables:
   - `base_url`: `http://54.234.127.110:8080` (for AWS) or `http://localhost:8080` (for local)
   - `api_version`: `2.1`

### **Step 3: Create Test Requests**

**For each endpoint above:**
1. Click "Add Request" in your collection
2. Set the HTTP method (GET/POST)
3. Enter URL: `{{base_url}}/endpoint`
4. Add headers if needed
5. For POST requests, add the JSON body
6. Click "Send"

### **Step 4: Add Test Scripts**

**Example test script for the prediction endpoint:**
```javascript
pm.test("Status code is 200", function () {
    pm.response.to.have.status(200);
});

pm.test("Response has prediction", function () {
    var jsonData = pm.response.json();
    pm.expect(jsonData).to.have.property('prediction');
    pm.expect(jsonData.prediction).to.have.property('default_probability');
    pm.expect(jsonData.prediction).to.have.property('binary_prediction');
});

pm.test("Risk assessment present", function () {
    var jsonData = pm.response.json();
    pm.expect(jsonData).to.have.property('risk_assessment');
    pm.expect(jsonData.risk_assessment).to.have.property('risk_level');
});

pm.test("Model performance meets targets", function () {
    var jsonData = pm.response.json();
    if (jsonData.model_info && jsonData.model_info.model_performance) {
        var auc = parseFloat(jsonData.model_info.model_performance.split(':')[1]);
        pm.expect(auc).to.be.above(0.85);
    }
});
```

---

## 🚀 Advanced Testing Scenarios

### **Edge Cases to Test:**

1. **Minimum Values:**
```json
{
  "age": 18,
  "annual_income": 15000,
  "employment_length": 0,
  "home_ownership": "RENT",
  "purpose": "other",
  "loan_amount": 1000,
  "term_months": 12,
  "interest_rate": 5.0,
  "dti": 1.0,
  "credit_score": 300,
  "delinquency_2yrs": 0,
  "num_open_acc": 1
}
```

2. **Maximum Values:**
```json
{
  "age": 65,
  "annual_income": 200000,
  "employment_length": 40,
  "home_ownership": "OWN",
  "purpose": "home_improvement",
  "loan_amount": 50000,
  "term_months": 84,
  "interest_rate": 25.0,
  "dti": 50.0,
  "credit_score": 850,
  "delinquency_2yrs": 10,
  "num_open_acc": 30
}
```

3. **Invalid Data (should return 400):**
```json
{
  "age": -5,
  "annual_income": "invalid",
  "employment_length": 100,
  "home_ownership": "INVALID",
  "purpose": "",
  "loan_amount": 0,
  "term_months": 0,
  "interest_rate": -1,
  "dti": 200,
  "credit_score": 1000,
  "delinquency_2yrs": -1,
  "num_open_acc": -5
}
```

---

## 📊 Expected Performance Benchmarks

- **Response Time:** < 100ms for single predictions
- **Batch Processing:** < 500ms for 10 applications
- **Accuracy:** 91.0% overall accuracy
- **Precision:** 88.24% (very low false positives)
- **ROC-AUC:** 94.64% (excellent discrimination)

## 🎉 Success Indicators

✅ **Health endpoint returns 200**  
✅ **Model info shows gradient_boost as best model**  
✅ **Low-risk borrowers get approval recommendations**  
✅ **High-risk borrowers get rejection recommendations**  
✅ **Batch processing handles multiple applications**  
✅ **Response times under 100ms**  
✅ **Feature analysis provides detailed insights**

**Your enhanced API is ready for comprehensive testing! 🚀**