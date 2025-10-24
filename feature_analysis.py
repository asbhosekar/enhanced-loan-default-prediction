"""
feature_analysis.py

Advanced feature analysis and selection for loan default prediction
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler, LabelEncoder
from sklearn.feature_selection import SelectKBest, f_classif, RFE, SelectFromModel
from sklearn.ensemble import RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import mutual_info_score
from scipy.stats import chi2_contingency
import warnings
warnings.filterwarnings('ignore')

def add_feature_engineering(df):
    """Enhanced feature engineering"""
    df['income_to_loan_ratio'] = df['annual_income'] / df['loan_amount']
    df['employment_risk'] = (df['employment_length'] < 2).astype(int)
    df['credit_score_binned'] = pd.cut(
        df['credit_score'], 
        bins=[0, 580, 670, 740, 850], 
        labels=['Poor', 'Fair', 'Good', 'Excellent'],
        include_lowest=True
    )
    
    # Additional features
    df['monthly_payment'] = df['loan_amount'] / df['term_months']
    df['payment_to_income'] = (df['monthly_payment'] * 12) / df['annual_income']
    df['credit_utilization'] = df['loan_amount'] / (df['credit_score'] * 100)
    df['age_employment_interaction'] = df['age'] * df['employment_length']
    df['high_dti'] = (df['dti'] > 36).astype(int)
    df['multiple_delinquencies'] = (df['delinquency_2yrs'] > 1).astype(int)
    df['many_accounts'] = (df['num_open_acc'] > 10).astype(int)
    
    df['interest_rate_category'] = pd.cut(
        df['interest_rate'],
        bins=[0, 8, 12, 16, 25],
        labels=['Low', 'Medium', 'High', 'Very_High'],
        include_lowest=True
    )
    
    return df

def analyze_feature_importance():
    """Comprehensive feature importance analysis"""
    print("🔍 FEATURE IMPORTANCE ANALYSIS")
    print("=" * 50)
    
    # Load and prepare data
    df = pd.read_csv("loan_default_sample.csv")
    df = add_feature_engineering(df)
    
    if 'loan_id' in df.columns:
        df = df.drop(columns=['loan_id'])
    
    target_col = 'target_default'
    df = df.dropna(subset=[target_col])
    
    X = df.drop(columns=[target_col])
    y = df[target_col]
    
    # Encode categorical variables for analysis
    X_encoded = X.copy()
    categorical_features = X.select_dtypes(exclude=[np.number]).columns
    
    label_encoders = {}
    for col in categorical_features:
        le = LabelEncoder()
        X_encoded[col] = le.fit_transform(X[col].astype(str))
        label_encoders[col] = le
    
    # Split data
    X_train, X_test, y_train, y_test = train_test_split(
        X_encoded, y, test_size=0.2, random_state=42, stratify=y
    )
    
    # Scale features
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test)
    
    results = {}
    
    # 1. Univariate Feature Selection (F-test)
    print("\\n1️⃣ Univariate Feature Selection (F-test)")
    selector_f = SelectKBest(score_func=f_classif, k='all')
    selector_f.fit(X_train_scaled, y_train)
    
    f_scores = pd.DataFrame({
        'feature': X.columns,
        'f_score': selector_f.scores_,
        'p_value': selector_f.pvalues_
    }).sort_values('f_score', ascending=False)
    
    print(f_scores.head(10))
    results['f_test'] = f_scores
    
    # 2. Random Forest Feature Importance
    print("\\n2️⃣ Random Forest Feature Importance")
    rf = RandomForestClassifier(n_estimators=100, random_state=42)
    rf.fit(X_train_scaled, y_train)
    
    rf_importance = pd.DataFrame({
        'feature': X.columns,
        'importance': rf.feature_importances_
    }).sort_values('importance', ascending=False)
    
    print(rf_importance.head(10))
    results['random_forest'] = rf_importance
    
    # 3. Logistic Regression Coefficients
    print("\\n3️⃣ Logistic Regression Feature Coefficients")
    lr = LogisticRegression(random_state=42, max_iter=1000)
    lr.fit(X_train_scaled, y_train)
    
    lr_coefs = pd.DataFrame({
        'feature': X.columns,
        'coefficient': lr.coef_[0],
        'abs_coefficient': np.abs(lr.coef_[0])
    }).sort_values('abs_coefficient', ascending=False)
    
    print(lr_coefs.head(10))
    results['logistic_regression'] = lr_coefs
    
    # 4. Recursive Feature Elimination
    print("\\n4️⃣ Recursive Feature Elimination (RFE)")
    rfe = RFE(estimator=LogisticRegression(random_state=42, max_iter=1000), n_features_to_select=10)
    rfe.fit(X_train_scaled, y_train)
    
    rfe_ranking = pd.DataFrame({
        'feature': X.columns,
        'ranking': rfe.ranking_,
        'selected': rfe.support_
    }).sort_values('ranking')
    
    print("Top 10 features selected by RFE:")
    print(rfe_ranking[rfe_ranking['selected']])
    results['rfe'] = rfe_ranking
    
    # 5. Mutual Information
    print("\\n5️⃣ Mutual Information Analysis")
    from sklearn.feature_selection import mutual_info_classif
    
    mi_scores = mutual_info_classif(X_train_scaled, y_train, random_state=42)
    mi_df = pd.DataFrame({
        'feature': X.columns,
        'mutual_info': mi_scores
    }).sort_values('mutual_info', ascending=False)
    
    print(mi_df.head(10))
    results['mutual_info'] = mi_df
    
    return results, X, y

def create_feature_visualizations(results, X, y):
    """Create comprehensive feature analysis visualizations"""
    print("\\n📊 Creating feature analysis visualizations...")
    
    # Set up the plotting style
    plt.style.use('default')
    sns.set_palette("husl")
    
    # Create a comprehensive feature analysis plot
    fig, axes = plt.subplots(3, 2, figsize=(20, 18))
    fig.suptitle('Comprehensive Feature Importance Analysis', fontsize=16, fontweight='bold')
    
    # 1. F-test scores
    top_f = results['f_test'].head(15)
    axes[0, 0].barh(range(len(top_f)), top_f['f_score'])
    axes[0, 0].set_yticks(range(len(top_f)))
    axes[0, 0].set_yticklabels(top_f['feature'], fontsize=8)
    axes[0, 0].set_title('Top 15 Features - F-test Scores')
    axes[0, 0].set_xlabel('F-Score')
    
    # 2. Random Forest importance
    top_rf = results['random_forest'].head(15)
    axes[0, 1].barh(range(len(top_rf)), top_rf['importance'])
    axes[0, 1].set_yticks(range(len(top_rf)))
    axes[0, 1].set_yticklabels(top_rf['feature'], fontsize=8)
    axes[0, 1].set_title('Top 15 Features - Random Forest Importance')
    axes[0, 1].set_xlabel('Importance')
    
    # 3. Logistic Regression coefficients
    top_lr = results['logistic_regression'].head(15)
    axes[1, 0].barh(range(len(top_lr)), top_lr['abs_coefficient'])
    axes[1, 0].set_yticks(range(len(top_lr)))
    axes[1, 0].set_yticklabels(top_lr['feature'], fontsize=8)
    axes[1, 0].set_title('Top 15 Features - Logistic Regression |Coefficients|')
    axes[1, 0].set_xlabel('Absolute Coefficient')
    
    # 4. Mutual Information
    top_mi = results['mutual_info'].head(15)
    axes[1, 1].barh(range(len(top_mi)), top_mi['mutual_info'])
    axes[1, 1].set_yticks(range(len(top_mi)))
    axes[1, 1].set_yticklabels(top_mi['feature'], fontsize=8)
    axes[1, 1].set_title('Top 15 Features - Mutual Information')
    axes[1, 1].set_xlabel('Mutual Information Score')
    
    # 5. Correlation with target
    numeric_features = X.select_dtypes(include=[np.number]).columns
    correlations = X[numeric_features].corrwith(y).abs().sort_values(ascending=False)
    
    axes[2, 0].barh(range(len(correlations)), correlations.values)
    axes[2, 0].set_yticks(range(len(correlations)))
    axes[2, 0].set_yticklabels(correlations.index, fontsize=8)
    axes[2, 0].set_title('Feature Correlation with Target (Absolute)')
    axes[2, 0].set_xlabel('|Correlation|')
    
    # 6. Feature selection consensus
    # Create a consensus ranking based on all methods
    consensus_scores = pd.DataFrame({'feature': X.columns})
    
    # Normalize all scores to 0-1 scale and rank
    methods = ['f_test', 'random_forest', 'logistic_regression', 'mutual_info']
    for method in methods:
        df = results[method].copy()
        score_col = {'f_test': 'f_score', 'random_forest': 'importance', 
                    'logistic_regression': 'abs_coefficient', 'mutual_info': 'mutual_info'}[method]
        
        # Rank features (1 = best)
        df[f'{method}_rank'] = df[score_col].rank(ascending=False)
        consensus_scores = consensus_scores.merge(df[['feature', f'{method}_rank']], on='feature')
    
    # Calculate average rank
    rank_cols = [f'{method}_rank' for method in methods]
    consensus_scores['avg_rank'] = consensus_scores[rank_cols].mean(axis=1)
    consensus_scores = consensus_scores.sort_values('avg_rank')
    
    top_consensus = consensus_scores.head(15)
    axes[2, 1].barh(range(len(top_consensus)), top_consensus['avg_rank'])
    axes[2, 1].set_yticks(range(len(top_consensus)))
    axes[2, 1].set_yticklabels(top_consensus['feature'], fontsize=8)
    axes[2, 1].set_title('Consensus Feature Ranking (Lower = Better)')
    axes[2, 1].set_xlabel('Average Rank')
    axes[2, 1].invert_xaxis()  # Lower ranks should be on the right
    
    plt.tight_layout()
    plt.savefig('feature_importance_analysis.png', dpi=300, bbox_inches='tight')
    plt.show()
    
    # Save consensus ranking
    consensus_scores.to_csv('feature_consensus_ranking.csv', index=False)
    print("💾 Feature consensus ranking saved to: feature_consensus_ranking.csv")
    
    return consensus_scores

def analyze_feature_correlations(X):
    """Analyze feature correlations and multicollinearity"""
    print("\\n🔗 FEATURE CORRELATION ANALYSIS")
    print("=" * 40)
    
    # Get numeric features only
    numeric_features = X.select_dtypes(include=[np.number])
    
    # Calculate correlation matrix
    corr_matrix = numeric_features.corr()
    
    # Find highly correlated pairs
    high_corr_pairs = []
    for i in range(len(corr_matrix.columns)):
        for j in range(i+1, len(corr_matrix.columns)):
            corr_val = abs(corr_matrix.iloc[i, j])
            if corr_val > 0.8:  # High correlation threshold
                high_corr_pairs.append({
                    'feature1': corr_matrix.columns[i],
                    'feature2': corr_matrix.columns[j],
                    'correlation': corr_val
                })
    
    if high_corr_pairs:
        print("⚠️  Highly correlated feature pairs (|correlation| > 0.8):")
        for pair in high_corr_pairs:
            print(f"  {pair['feature1']} - {pair['feature2']}: {pair['correlation']:.3f}")
    else:
        print("✅ No highly correlated feature pairs found")
    
    # Create correlation heatmap
    plt.figure(figsize=(12, 10))
    mask = np.triu(np.ones_like(corr_matrix, dtype=bool))
    sns.heatmap(corr_matrix, mask=mask, annot=True, cmap='coolwarm', center=0,
                square=True, fmt='.2f', cbar_kws={"shrink": .8})
    plt.title('Feature Correlation Matrix')
    plt.tight_layout()
    plt.savefig('feature_correlation_matrix.png', dpi=300, bbox_inches='tight')
    plt.show()
    
    return high_corr_pairs

def main():
    """Main feature analysis function"""
    print("🧬 COMPREHENSIVE FEATURE ANALYSIS FOR LOAN DEFAULT PREDICTION")
    print("=" * 70)
    
    # Run feature importance analysis
    results, X, y = analyze_feature_importance()
    
    # Create visualizations
    consensus_scores = create_feature_visualizations(results, X, y)
    
    # Analyze correlations
    high_corr_pairs = analyze_feature_correlations(X)
    
    # Generate recommendations
    print("\\n💡 FEATURE SELECTION RECOMMENDATIONS")
    print("=" * 45)
    
    top_features = consensus_scores.head(10)['feature'].tolist()
    print("🏆 Top 10 features by consensus ranking:")
    for i, feature in enumerate(top_features, 1):
        print(f"  {i:2d}. {feature}")
    
    # Features to consider removing due to low importance
    bottom_features = consensus_scores.tail(5)['feature'].tolist()
    print("\\n🚫 Features to consider removing (lowest consensus ranking):")
    for feature in bottom_features:
        print(f"     - {feature}")
    
    # Multicollinearity warnings
    if high_corr_pairs:
        print("\\n⚠️  Multicollinearity concerns:")
        for pair in high_corr_pairs:
            print(f"     - Consider removing one of: {pair['feature1']} or {pair['feature2']}")
    
    print("\\n📊 Analysis complete! Files saved:")
    print("   - feature_importance_analysis.png")
    print("   - feature_correlation_matrix.png") 
    print("   - feature_consensus_ranking.csv")
    
    return top_features, consensus_scores

if __name__ == "__main__":
    main()