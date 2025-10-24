"""
deploy.py

Comprehensive deployment script for the loan default prediction system
"""

import subprocess
import sys
import os
import time
import requests
import json

def run_command(command, description, background=False):
    """Run a command with error handling"""
    print(f"\n🔄 {description}...")
    try:
        if background:
            process = subprocess.Popen(command, shell=True)
            return process
        else:
            result = subprocess.run(command, shell=True, capture_output=True, text=True, check=True)
            print(f"✅ {description} completed successfully")
            return result
    except subprocess.CalledProcessError as e:
        print(f"❌ Error in {description}: {e}")
        if e.stdout:
            print(f"STDOUT: {e.stdout}")
        if e.stderr:
            print(f"STDERR: {e.stderr}")
        return None

def check_requirements():
    """Check if all requirements are installed"""
    try:
        import mlflow
        import sklearn
        import pandas
        import fastapi
        import uvicorn
        print("✅ All required packages are installed")
        return True
    except ImportError as e:
        print(f"❌ Missing required package: {e}")
        return False

def train_model():
    """Train the loan default prediction model"""
    print("\n🎯 STEP 1: Training Loan Default Prediction Model")
    
    # Train with Logistic Regression
    cmd = f'"{sys.executable}" train.py --model-type logistic'
    result = run_command(cmd, "Training Logistic Regression model")
    
    if result is None:
        return False
    
    # Check if model was created
    if os.path.exists("exported_model"):
        print("✅ Model exported successfully to ./exported_model/")
        return True
    else:
        print("❌ Model export failed")
        return False

def start_api_server():
    """Start the FastAPI server"""
    print("\n🚀 STEP 2: Starting API Server")
    
    # Set environment variable
    os.environ["MODEL_PATH"] = "./exported_model"
    
    # Start server in background
    cmd = f'"{sys.executable}" -m uvicorn predict_api.app:app --host 0.0.0.0 --port 9000'
    process = run_command(cmd, "Starting FastAPI server", background=True)
    
    if process:
        print("🔄 Waiting for server to start...")
        time.sleep(5)  # Give server time to start
        return process
    return None

def test_api():
    """Test the API endpoints"""
    print("\n🧪 STEP 3: Testing API")
    
    base_url = "http://localhost:9000"
    
    # Test health endpoint
    try:
        response = requests.get(f"{base_url}/health", timeout=10)
        if response.status_code == 200:
            print("✅ Health endpoint working")
            print(f"   Response: {response.json()}")
        else:
            print(f"❌ Health endpoint failed with status {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Health endpoint error: {e}")
        return False
    
    # Test prediction endpoint
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
    
    try:
        response = requests.post(
            f"{base_url}/predict",
            headers={"Content-Type": "application/json"},
            json=test_data,
            timeout=10
        )
        if response.status_code == 200:
            result = response.json()
            print("✅ Prediction endpoint working")
            print(f"   Test Result: {json.dumps(result, indent=2)}")
            
            # Validate success criteria
            if result.get('default_probability') is not None:
                print("\n📊 Validation Results:")
                prob = result['default_probability']
                risk = result['risk_level']
                recommendation = result['recommendation']
                print(f"   Default Probability: {prob:.4f} ({prob*100:.2f}%)")
                print(f"   Risk Level: {risk}")
                print(f"   Recommendation: {recommendation}")
                return True
        else:
            print(f"❌ Prediction endpoint failed with status {response.status_code}")
            print(f"   Error: {response.text}")
            return False
    except Exception as e:
        print(f"❌ Prediction endpoint error: {e}")
        return False

def main():
    """Main deployment function"""
    print("🏦 Loan Default Prediction System - Deployment Script")
    print("=" * 60)
    
    # Check requirements
    if not check_requirements():
        print("\n❌ Please install requirements first:")
        print("   pip install -r requirements.txt")
        return
    
    # Train model
    if not train_model():
        print("\n❌ Model training failed. Exiting.")
        return
    
    # Start API server
    server_process = start_api_server()
    if not server_process:
        print("\n❌ Failed to start API server. Exiting.")
        return
    
    try:
        # Test API
        if test_api():
            print("\n🎉 SUCCESS! Loan Default Prediction System is fully deployed and tested!")
            print("\n📋 Quick Reference:")
            print("   Health Check: GET  http://localhost:9000/health")
            print("   Predictions:  POST http://localhost:9000/predict")
            print("   Model Path:   ./exported_model/")
            print("   MLflow UI:    mlflow ui (run in separate terminal)")
            print("\n   Press Ctrl+C to stop the server when done.")
            
            # Keep server running
            try:
                server_process.wait()
            except KeyboardInterrupt:
                print("\n🛑 Shutting down server...")
                server_process.terminate()
                server_process.wait()
        else:
            print("\n❌ API testing failed.")
            server_process.terminate()
    except Exception as e:
        print(f"\n❌ Deployment error: {e}")
        if server_process:
            server_process.terminate()

if __name__ == "__main__":
    main()