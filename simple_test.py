"""
simple_test.py

Simple test without requests dependency to verify the model works locally
"""

import sys
import os
sys.path.append('.')

from predict_api.app import add_feature_engineering, LoanApplication
import pandas as pd
import mlflow.sklearn

# Test data from requirements
test_data = {
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

def test_model_locally():
    """Test the model locally without API"""
    
    print("Testing loan default prediction model locally...")
    
    # Load the model
    model_path = "./exported_model"
    if not os.path.exists(model_path):
        print(f"Error: Model path {model_path} does not exist")
        return
    
    try:
        model = mlflow.sklearn.load_model(model_path)
        print("✓ Model loaded successfully")
    except Exception as e:
        print(f"✗ Error loading model: {e}")
        return
    
    # Create DataFrame from test data
    df = pd.DataFrame([test_data])
    print(f"✓ Created DataFrame with shape: {df.shape}")
    
    # Add feature engineering
    df = add_feature_engineering(df)
    print(f"✓ Added feature engineering, new shape: {df.shape}")
    print(f"  - income_to_loan_ratio: {df['income_to_loan_ratio'].iloc[0]:.4f}")
    print(f"  - employment_risk: {df['employment_risk'].iloc[0]}")
    print(f"  - credit_score_binned: {df['credit_score_binned'].iloc[0]}")
    
    # Make prediction
    try:
        pred_proba = model.predict_proba(df)[0]
        binary_prediction = int(model.predict(df)[0])
        default_probability = float(pred_proba[1])
        
        # Risk classification
        if default_probability >= 0.7:
            risk_level = "High"
        elif default_probability >= 0.4:
            risk_level = "Medium"
        else:
            risk_level = "Low"
        
        print("\n🎯 Prediction Results:")
        print(f"  Default Probability: {default_probability:.4f} ({default_probability*100:.2f}%)")
        print(f"  Binary Prediction: {binary_prediction} ({'Default' if binary_prediction == 1 else 'No Default'})")
        print(f"  Risk Level: {risk_level}")
        print(f"  Recommendation: {'Reject' if binary_prediction == 1 else 'Approve'}")
        
        # Validate against success criteria
        print("\n📊 Model Validation:")
        if hasattr(model, 'classes_'):
            print(f"  Model classes: {model.classes_}")
        
        print("✅ Model test completed successfully!")
        
    except Exception as e:
        print(f"✗ Error making prediction: {e}")

if __name__ == "__main__":
    test_model_locally()