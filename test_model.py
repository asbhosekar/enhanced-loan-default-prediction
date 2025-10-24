"""
test_model.py

Simple script to test the loan default prediction model
"""

import requests
import json

# Test data from requirements
test_application = {
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

def test_api(base_url="http://localhost:9000"):
    """Test the loan default prediction API"""
    
    # Test health endpoint
    print("Testing health endpoint...")
    try:
        response = requests.get(f"{base_url}/health")
        print(f"Health check: {response.status_code}")
        print(f"Response: {response.json()}")
        print()
    except Exception as e:
        print(f"Health check failed: {e}")
        return
    
    # Test prediction endpoint
    print("Testing prediction endpoint...")
    try:
        response = requests.post(
            f"{base_url}/predict",
            headers={"Content-Type": "application/json"},
            json=test_application
        )
        print(f"Prediction status: {response.status_code}")
        if response.status_code == 200:
            result = response.json()
            print(f"Prediction result: {json.dumps(result, indent=2)}")
        else:
            print(f"Error: {response.text}")
    except Exception as e:
        print(f"Prediction test failed: {e}")

if __name__ == "__main__":
    test_api()