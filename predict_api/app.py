"""
predict_api/app.py

FastAPI app for loan default prediction that loads the exported_model directory 
and exposes endpoints for health check and prediction.

Run:
  export MODEL_PATH=./exported_model
  uvicorn predict_api.app:app --host 0.0.0.0 --port 9000

Example prediction payload:
  {
    "age": 32,
    "annual_income": 60000,
    "employment_length": 3,
    "home_ownership": "RENT",
    "purpose": "credit_card",
    "loan_amount": 15000,
    "term_months": 36,
    "interest_rate": 12.5,
    "dti": 20.3,
    "credit_score": 720,
    "delinquency_2yrs": 0,
    "num_open_acc": 6
  }

"""
import os
from typing import Dict, Any, Optional
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import mlflow.sklearn
import pandas as pd
import numpy as np

MODEL_PATH = os.environ.get("MODEL_PATH", os.path.join(os.getcwd(), "exported_model"))

app = FastAPI(title="Loan Default Prediction API", version="2.0")

class LoanApplication(BaseModel):
    age: int
    annual_income: float
    employment_length: int
    home_ownership: str  # OWN, RENT, MORTGAGE
    purpose: str  # debt_consolidation, credit_card, etc.
    loan_amount: float
    term_months: int
    interest_rate: float
    dti: float  # debt-to-income ratio
    credit_score: float
    delinquency_2yrs: int
    num_open_acc: int

def add_feature_engineering(df):
    """Enhanced feature engineering for loan default prediction"""
    # Original features
    df['income_to_loan_ratio'] = df['annual_income'] / df['loan_amount']
    df['employment_risk'] = (df['employment_length'] < 2).astype(int)
    df['credit_score_binned'] = pd.cut(
        df['credit_score'], 
        bins=[0, 580, 670, 740, 850], 
        labels=['Poor', 'Fair', 'Good', 'Excellent'],
        include_lowest=True
    )
    
    # Additional engineered features
    df['monthly_payment'] = df['loan_amount'] / df['term_months']
    df['payment_to_income_ratio'] = df['monthly_payment'] / (df['annual_income'] / 12)
    df['high_interest'] = (df['interest_rate'] > df['interest_rate'].median()).astype(int)
    df['young_borrower'] = (df['age'] < 30).astype(int)
    df['experienced_worker'] = (df['employment_length'] > 10).astype(int)
    df['high_credit_score'] = (df['credit_score'] > 750).astype(int)
    df['multiple_delinquencies'] = (df['delinquency_2yrs'] > 1).astype(int)
    df['many_open_accounts'] = (df['num_open_acc'] > df['num_open_acc'].median()).astype(int)
    
    # Risk score combination
    risk_factors = ['employment_risk', 'high_interest', 'young_borrower', 
                   'multiple_delinquencies', 'many_open_accounts']
    df['risk_score'] = df[risk_factors].sum(axis=1)
    
    return df

@app.on_event("startup")
def load_model():
    global model
    try:
        model = mlflow.sklearn.load_model(MODEL_PATH)
        print("Loaded model from:", MODEL_PATH)
    except Exception as e:
        print("Could not load model at startup:", e)
        model = None

@app.get("/health")
def health():
    """Health check endpoint that returns model load status"""
    return {
        "status": "ok", 
        "model_loaded": model is not None, 
        "model_path": MODEL_PATH,
        "service": "Loan Default Prediction API"
    }

@app.post("/predict")
def predict(application: LoanApplication):
    """
    Predict loan default probability for a single application.
    Returns the predicted default probability and risk classification.
    """
    if model is None:
        raise HTTPException(status_code=500, detail="Model not loaded on server")
    
    try:
        # Convert single application to DataFrame
        app_data = application.dict()
        df = pd.DataFrame([app_data])
        
        # Add feature engineering
        df = add_feature_engineering(df)
        
        # Get prediction probability
        pred_proba = model.predict_proba(df)[0]
        default_probability = float(pred_proba[1])  # Probability of default (class 1)
        
        # Binary prediction
        binary_prediction = int(model.predict(df)[0])
        
        # Risk classification based on probability
        if default_probability >= 0.7:
            risk_level = "High"
        elif default_probability >= 0.4:
            risk_level = "Medium"
        else:
            risk_level = "Low"
        
        return {
            "default_probability": round(default_probability, 4),
            "binary_prediction": binary_prediction,
            "risk_level": risk_level,
            "recommendation": "Approve" if binary_prediction == 0 else "Reject"
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Prediction error: {str(e)}")
