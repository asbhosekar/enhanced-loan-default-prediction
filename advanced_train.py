"""
advanced_train.py

Advanced training script with comprehensive hyperparameter tuning,
feature selection, and model optimization for loan default prediction.
"""

import argparse
import os
import json
import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split, GridSearchCV, RandomizedSearchCV, cross_val_score
from sklearn.pipeline import Pipeline
from sklearn.impute import SimpleImputer
from sklearn.preprocessing import StandardScaler, OneHotEncoder
from sklearn.compose import ColumnTransformer
from sklearn.linear_model import LogisticRegression
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
from sklearn.svm import SVC
from sklearn.feature_selection import SelectKBest, f_classif, RFE
from sklearn.metrics import (accuracy_score, precision_score, recall_score, 
                           f1_score, roc_auc_score, classification_report, 
                           confusion_matrix, roc_curve)
import mlflow
import mlflow.sklearn
from datetime import datetime, timezone
import warnings
warnings.filterwarnings('ignore')

def parse_args():
    parser = argparse.ArgumentParser(description="Advanced loan default prediction model training")
    parser.add_argument("--data-path", type=str, default="loan_default_sample.csv", help="Path to CSV file")
    parser.add_argument("--target", type=str, default="target_default", help="Target column name")
    parser.add_argument("--model-type", type=str, 
                       choices=["logistic", "random_forest", "gradient_boost", "svm", "all"], 
                       default="all", help="Model type to train")
    parser.add_argument("--search-type", type=str, choices=["grid", "random"], default="random",
                       help="Hyperparameter search type")
    parser.add_argument("--cv", type=int, default=5, help="CV folds for GridSearch")
    parser.add_argument("--test-size", type=float, default=0.2, help="Test set fraction")
    parser.add_argument("--random-state", type=int, default=42)
    parser.add_argument("--n-iter", type=int, default=50, help="Number of iterations for RandomizedSearchCV")
    parser.add_argument("--feature-selection", type=str, choices=["none", "kbest", "rfe"], 
                       default="none", help="Feature selection method")
    parser.add_argument("--k-features", type=int, default=10, help="Number of features to select")
    parser.add_argument("--experiment-name", type=str, default="Advanced-LoanDefault-Tuning")
    parser.add_argument("--mlflow-tracking-uri", type=str, default=None)
    parser.add_argument("--register-model", type=str, default=None)
    return parser.parse_args()

def add_feature_engineering(df):
    """Enhanced feature engineering for loan default prediction"""
    # Original features
"""
advanced_train.py

Advanced training script with comprehensive hyperparameter tuning,
feature selection, and model optimization for loan default prediction.
"""

import argparse
import os
import json
import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split, GridSearchCV, RandomizedSearchCV, StratifiedKFold
from sklearn.pipeline import Pipeline
from sklearn.impute import SimpleImputer
from sklearn.preprocessing import StandardScaler, OneHotEncoder
from sklearn.compose import ColumnTransformer
from sklearn.linear_model import LogisticRegression
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
from sklearn.svm import SVC
from sklearn.metrics import (accuracy_score, precision_score, recall_score, 
                           f1_score, roc_auc_score, classification_report, 
                           confusion_matrix)
import mlflow
import mlflow.sklearn
from datetime import datetime, timezone
import warnings
warnings.filterwarnings('ignore')

def parse_args():
    parser = argparse.ArgumentParser(description="Advanced loan default prediction model training")
    parser.add_argument("--data-path", type=str, default="loan_default_sample.csv", help="Path to CSV file")
    parser.add_argument("--target", type=str, default="target_default", help="Target column name")
    parser.add_argument("--model-type", type=str, 
                       choices=["logistic", "random_forest", "gradient_boost", "svm", "all"], 
                       default="all", help="Model type to train")
    parser.add_argument("--search-type", type=str, choices=["grid", "random"], default="random",
                       help="Hyperparameter search type")
    parser.add_argument("--cv", type=int, default=5, help="CV folds for GridSearch")
    parser.add_argument("--test-size", type=float, default=0.2, help="Test set fraction")
    parser.add_argument("--random-state", type=int, default=42)
    parser.add_argument("--n-iter", type=int, default=30, help="Number of iterations for RandomizedSearchCV")
    parser.add_argument("--experiment-name", type=str, default="Advanced-LoanDefault-Tuning")
    parser.add_argument("--mlflow-tracking-uri", type=str, default=None)
    parser.add_argument("--register-model", type=str, default=None)
    return parser.parse_args()

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

def get_model_configs():
    """Get hyperparameter configurations for different models"""
    return {
        'logistic': {
            'model': LogisticRegression(random_state=42, max_iter=1000),
            'params': {
                'estimator__C': [0.01, 0.1, 1, 10, 100],
                'estimator__penalty': ['l1', 'l2'],
                'estimator__solver': ['liblinear', 'saga'],
                'estimator__class_weight': [None, 'balanced']
            }
        },
        'random_forest': {
            'model': RandomForestClassifier(random_state=42),
            'params': {
                'estimator__n_estimators': [50, 100, 200, 300],
                'estimator__max_depth': [None, 10, 20, 30],
                'estimator__min_samples_split': [2, 5, 10],
                'estimator__min_samples_leaf': [1, 2, 4],
                'estimator__max_features': ['sqrt', 'log2'],
                'estimator__class_weight': [None, 'balanced']
            }
        },
        'gradient_boost': {
            'model': GradientBoostingClassifier(random_state=42),
            'params': {
                'estimator__n_estimators': [100, 200, 300],
                'estimator__learning_rate': [0.01, 0.1, 0.2],
                'estimator__max_depth': [3, 5, 7],
                'estimator__subsample': [0.8, 0.9, 1.0],
                'estimator__max_features': ['sqrt', 'log2']
            }
        },
        'svm': {
            'model': SVC(random_state=42, probability=True),
            'params': {
                'estimator__C': [0.1, 1, 10, 100],
                'estimator__kernel': ['rbf', 'poly'],
                'estimator__gamma': ['scale', 'auto'],
                'estimator__class_weight': [None, 'balanced']
            }
        }
    }

def evaluate_model(model, X_test, y_test, model_name):
    """Comprehensive model evaluation"""
    # Predictions
    y_pred = model.predict(X_test)
    y_pred_proba = model.predict_proba(X_test)[:, 1]
    
    # Metrics
    metrics = {
        'accuracy': accuracy_score(y_test, y_pred),
        'precision': precision_score(y_test, y_pred),
        'recall': recall_score(y_test, y_pred),
        'f1_score': f1_score(y_test, y_pred),
        'roc_auc': roc_auc_score(y_test, y_pred_proba)
    }
    
    # Log metrics to MLflow
    for metric_name, value in metrics.items():
        mlflow.log_metric(metric_name, float(value))
    
    print(f"\n📊 {model_name} Performance:")
    print(f"Accuracy:  {metrics['accuracy']:.4f}")
    print(f"Precision: {metrics['precision']:.4f}")
    print(f"Recall:    {metrics['recall']:.4f}")
    print(f"F1-Score:  {metrics['f1_score']:.4f}")
    print(f"ROC-AUC:   {metrics['roc_auc']:.4f}")
    
    return metrics

def train_and_tune_model(model_name, config, pipeline, X_train, y_train, X_test, y_test, args):
    """Train and tune a specific model"""
    print(f"\n🔄 Training {model_name}...")
    
    # Set up cross-validation
    cv = StratifiedKFold(n_splits=args.cv, shuffle=True, random_state=args.random_state)
    
    # Choose search method
    if args.search_type == 'random':
        search = RandomizedSearchCV(
            pipeline, config['params'], n_iter=args.n_iter, cv=cv, 
            scoring='roc_auc', n_jobs=-1, random_state=args.random_state, verbose=1
        )
    else:
        search = GridSearchCV(
            pipeline, config['params'], cv=cv, scoring='roc_auc', n_jobs=-1, verbose=1
        )
    
    # Fit the search
    search.fit(X_train, y_train)
    best_model = search.best_estimator_
    
    print(f"✅ Best {model_name} parameters: {search.best_params_}")
    print(f"📊 Best CV ROC-AUC: {search.best_score_:.4f}")
    
    # Log parameters
    for param, value in search.best_params_.items():
        mlflow.log_param(param, value)
    mlflow.log_metric("cv_roc_auc", search.best_score_)
    
    # Evaluate on test set
    metrics = evaluate_model(best_model, X_test, y_test, model_name)
    
    return best_model, metrics, search.best_params_

def main():
    args = parse_args()
    
    if args.mlflow_tracking_uri:
        mlflow.set_tracking_uri(args.mlflow_tracking_uri)
    mlflow.set_experiment(args.experiment_name)
    
    # Load and prepare data
    print("📊 Loading and preparing data...")
    df = pd.read_csv(args.data_path)
    print(f"Loaded data: {df.shape[0]} rows, {df.shape[1]} columns")
    
    # Feature engineering
    df = add_feature_engineering(df)
    print(f"After feature engineering: {df.shape[0]} rows, {df.shape[1]} columns")
    
    # Prepare features and target
    target_col = args.target
    if target_col not in df.columns:
        raise ValueError(f"Target column {target_col} not found in data")
    
    df = df.dropna(subset=[target_col])
    if 'loan_id' in df.columns:
        df = df.drop(columns=['loan_id'])
    
    X = df.drop(columns=[target_col])
    y = df[target_col]
    
    print(f"📊 Class distribution: {y.value_counts().to_dict()}")
    
    # Train/test split
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=args.test_size, random_state=args.random_state, stratify=y
    )
    
    # Preprocessing pipeline
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
    
    # Get model configurations
    model_configs = get_model_configs()
    
    # Determine which models to train
    if args.model_type == "all":
        models_to_train = list(model_configs.keys())
    else:
        models_to_train = [args.model_type]
    
    # Store results for comparison
    results = {}
    best_model = None
    best_score = 0
    best_model_name = None
    
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S")
    
    # Train each model
    for model_name in models_to_train:
        with mlflow.start_run(run_name=f"advanced_{model_name}_{timestamp}") as run:
            config = model_configs[model_name]
            
            # Create pipeline
            pipeline = Pipeline(steps=[
                ("preprocessor", preprocessor),
                ("estimator", config['model'])
            ])
            
            # Train and tune
            mlflow.log_param("model_type", model_name)
            mlflow.log_param("search_type", args.search_type)
            mlflow.log_param("test_size", args.test_size)
            mlflow.log_param("cv_folds", args.cv)
            
            tuned_model, metrics, best_params = train_and_tune_model(
                model_name, config, pipeline, X_train, y_train, X_test, y_test, args
            )
            
            # Store results
            results[model_name] = {
                'model': tuned_model,
                'metrics': metrics,
                'params': best_params,
                'run_id': run.info.run_id
            }
            
            # Track best model
            if metrics['roc_auc'] > best_score:
                best_score = metrics['roc_auc']
                best_model = tuned_model
                best_model_name = model_name
            
            # Log model
            mlflow.sklearn.log_model(tuned_model, name="model")
    
    # Summary and best model export
    print("\n" + "="*60)
    print("🏆 MODEL COMPARISON SUMMARY")
    print("="*60)
    
    # Results table
    print(f"{'Model':<15} {'Accuracy':<10} {'Precision':<11} {'Recall':<8} {'F1':<8} {'ROC-AUC':<8}")
    print("-" * 70)
    
    for model_name, result in results.items():
        metrics = result['metrics']
        print(f"{model_name:<15} {metrics['accuracy']:<10.4f} {metrics['precision']:<11.4f} "
              f"{metrics['recall']:<8.4f} {metrics['f1_score']:<8.4f} {metrics['roc_auc']:<8.4f}")
    
    print(f"\n🥇 BEST MODEL: {best_model_name.upper()} (ROC-AUC: {best_score:.4f})")
    
    # Export best model
    if best_model:
        export_dir = os.path.abspath("exported_model_tuned")
        if os.path.exists(export_dir):
            import shutil
            shutil.rmtree(export_dir)
        mlflow.sklearn.save_model(best_model, export_dir)
        print(f"💾 Best model saved to: {export_dir}")
        
        # Save results summary
        summary = {
            'best_model': best_model_name,
            'best_score': best_score,
            'all_results': {name: result['metrics'] for name, result in results.items()},
            'best_params': results[best_model_name]['params'],
            'training_config': {
                'search_type': args.search_type,
                'cv_folds': args.cv,
                'test_size': args.test_size,
                'n_iter': args.n_iter
            }
        }
        
        with open("tuning_results.json", "w") as f:
            json.dump(summary, f, indent=2)
        print("📊 Results summary saved to: tuning_results.json")
    
    print("\n🎯 Next steps:")
    print("  1. View detailed results: mlflow ui")
    print("  2. Test best model: python simple_test.py")
    print("  3. Deploy API with tuned model")

if __name__ == "__main__":
    main()