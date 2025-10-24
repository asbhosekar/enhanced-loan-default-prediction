"""
train.py

Train a (linear / ridge / lasso) regression model, optionally run hyperparameter tuning,
and log parameters, metrics and model to MLflow. Also saves a local exported_model directory
so the model can be served by the API.

Usage examples:
  python train.py --data-path sample_input_for_regression.csv --target target --tune --model-type ridge --alpha 0.1 1 10
  python train.py --data-path sample_input_for_regression.csv --target target

"""

import argparse
import os
import json
import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split, GridSearchCV
from sklearn.pipeline import Pipeline
from sklearn.impute import SimpleImputer
from sklearn.preprocessing import StandardScaler, OneHotEncoder
from sklearn.compose import ColumnTransformer
from sklearn.linear_model import LogisticRegression
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score, roc_auc_score, classification_report
import mlflow
import mlflow.sklearn
from datetime import datetime, timezone

def parse_args():
    parser = argparse.ArgumentParser(description="Train loan default prediction model and log to MLflow")
    parser.add_argument("--data-path", type=str, default="loan_default_sample.csv", help="Path to CSV file")
    parser.add_argument("--target", type=str, default="target_default", help="Target column name")
    parser.add_argument("--model-type", type=str, choices=["logistic","random_forest"], default="logistic")
    parser.add_argument("--tune", action="store_true", help="Whether to run grid search tuning")
    parser.add_argument("--C", type=float, nargs="*", default=[0.1,1.0,10.0], help="C values for Logistic Regression tuning")
    parser.add_argument("--cv", type=int, default=5, help="CV folds for GridSearch")
    parser.add_argument("--test-size", type=float, default=0.2, help="Test set fraction")
    parser.add_argument("--random-state", type=int, default=42)
    parser.add_argument("--experiment-name", type=str, default="LoanDefault-Prediction-Experiment")
    parser.add_argument("--mlflow-tracking-uri", type=str, default=None,
                        help="If provided, set MLflow tracking URI (e.g., http://127.0.0.1:5000). Otherwise defaults to local file-based mlruns.")
    parser.add_argument("--register-model", type=str, default=None, help="If using an MLflow Model Registry, provide a name to register model under")
    parser.add_argument("--autolog", action="store_true", help="Enable mlflow.sklearn.autolog()")
    return parser.parse_args()

def add_feature_engineering(df):
    """Add derived features for loan default prediction"""
    # income_to_loan_ratio = annual_income / loan_amount
    df['income_to_loan_ratio'] = df['annual_income'] / df['loan_amount']
    
    # employment_risk = 1 if employment_length < 2 years else 0
    df['employment_risk'] = (df['employment_length'] < 2).astype(int)
    
    # credit_score_binned = categorical bands based on credit_score
    df['credit_score_binned'] = pd.cut(
        df['credit_score'], 
        bins=[0, 580, 670, 740, 850], 
        labels=['Poor', 'Fair', 'Good', 'Excellent'],
        include_lowest=True
    )
    
    return df

def main():
    args = parse_args()
    if args.mlflow_tracking_uri:
        mlflow.set_tracking_uri(args.mlflow_tracking_uri)
    mlflow.set_experiment(args.experiment_name)

    if args.autolog:
        mlflow.sklearn.autolog()

    df = pd.read_csv(args.data_path)
    print(f"Loaded data: {df.shape[0]} rows, {df.shape[1]} columns")
    
    # Add feature engineering
    df = add_feature_engineering(df)
    print(f"After feature engineering: {df.shape[0]} rows, {df.shape[1]} columns")
    
    target_col = args.target
    if target_col not in df.columns:
        raise ValueError(f"Target column {target_col} not found in data")

    # Drop rows where target is missing and remove loan_id if present
    df = df.dropna(subset=[target_col])
    if 'loan_id' in df.columns:
        df = df.drop(columns=['loan_id'])
    
    X = df.drop(columns=[target_col])
    y = df[target_col]

    # Train/test split
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=args.test_size, random_state=args.random_state)

    # Identify numeric and categorical features
    numeric_features = X_train.select_dtypes(include=[np.number]).columns.tolist()
    categorical_features = X_train.select_dtypes(exclude=[np.number]).columns.tolist()

    numeric_transformer = Pipeline(steps=[
        ("imputer", SimpleImputer(strategy="median")),
        ("scaler", StandardScaler())
    ])

    categorical_transformer = Pipeline(steps=[
        ("imputer", SimpleImputer(strategy="most_frequent")),
        ("onehot", OneHotEncoder(handle_unknown="ignore", sparse_output=False))
    ])

    preprocessor = ColumnTransformer(transformers=[
        ("num", numeric_transformer, numeric_features),
        ("cat", categorical_transformer, categorical_features)
    ], remainder="drop")

    # Choose estimator
    if args.model_type == "logistic":
        estimator = LogisticRegression(random_state=args.random_state, max_iter=1000)
    elif args.model_type == "random_forest":
        estimator = RandomForestClassifier(random_state=args.random_state, n_estimators=100)
    else:
        raise ValueError("Unsupported model type")

    pipeline = Pipeline(steps=[("preprocessor", preprocessor), ("estimator", estimator)])

    param_grid = {}
    if args.tune:
        if args.model_type == "logistic":
            param_grid = {"estimator__C": args.C}
        elif args.model_type == "random_forest":
            param_grid = {
                "estimator__n_estimators": [50, 100, 200],
                "estimator__max_depth": [None, 10, 20]
            }

    #timestamp = datetime.utcnow().strftime("%Y%m%d%H%M%S")
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S")
    
    with mlflow.start_run(run_name=f"train_{args.model_type}_{timestamp}") as run:
        run_id = run.info.run_id
        mlflow.log_param("model_type", args.model_type)
        mlflow.log_param("test_size", args.test_size)
        mlflow.log_param("random_state", args.random_state)

        if args.tune and param_grid:
            print("Starting grid search with params:", param_grid)
            search = GridSearchCV(pipeline, param_grid=param_grid, cv=args.cv, scoring="roc_auc", n_jobs=-1)
            search.fit(X_train, y_train)
            best = search.best_estimator_
            best_params = search.best_params_
            print("Best params:", best_params)
            mlflow.log_params({k: float(v) for k,v in best_params.items()})
            model_to_save = best
        else:
            pipeline.fit(X_train, y_train)
            model_to_save = pipeline

        # Evaluate on test set
        preds = model_to_save.predict(X_test)
        pred_proba = model_to_save.predict_proba(X_test)[:, 1]  # Probability of default
        
        accuracy = accuracy_score(y_test, preds)
        precision = precision_score(y_test, preds)
        recall = recall_score(y_test, preds)
        f1 = f1_score(y_test, preds)
        roc_auc = roc_auc_score(y_test, pred_proba)

        mlflow.log_metric("accuracy", float(accuracy))
        mlflow.log_metric("precision", float(precision))
        mlflow.log_metric("recall", float(recall))
        mlflow.log_metric("f1_score", float(f1))
        mlflow.log_metric("roc_auc", float(roc_auc))
        
        print(f"\nModel Performance:")
        print(f"Accuracy: {accuracy:.4f}")
        print(f"Precision: {precision:.4f}")
        print(f"Recall: {recall:.4f}")
        print(f"F1-Score: {f1:.4f}")
        print(f"ROC-AUC: {roc_auc:.4f}")

        # Log the sklearn pipeline as an MLflow model artifact
        mlflow.sklearn.log_model(model_to_save, name="model", registered_model_name=args.register_model if args.register_model else None)

        # Also save a local exported_model folder for easy serving / API loading
        export_dir = os.path.abspath("exported_model")
        if os.path.exists(export_dir):
            import shutil
            shutil.rmtree(export_dir)
        mlflow.sklearn.save_model(model_to_save, export_dir)
        print(f"Saved exported model to: {export_dir}")

        # Save run metadata to a small JSON file
        meta = {
            "run_id": run_id,
            "accuracy": accuracy,
            "precision": precision,
            "recall": recall,
            "f1_score": f1,
            "roc_auc": roc_auc,
            "params": { "model_type": args.model_type }
        }
        with open("run_metadata.json","w") as f:
            json.dump(meta, f, indent=2)

    print("Training complete. MLflow run id:", run_id)
    print("To view results: start `mlflow ui` or run an MLflow tracking server and open the UI.")

if __name__ == "__main__":
    main()
