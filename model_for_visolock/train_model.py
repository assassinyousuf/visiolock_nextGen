import pandas as pd
import numpy as np
import os
import joblib
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder, StandardScaler
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix

def train_and_export(data_path, output_dir):
    print("Loading labeled dataset...")
    df = pd.read_csv(data_path)
    
    # 1. Feature Engineering & Preprocessing
    # We combine target labels into a single configuration class for multiclass classification
    # This simplifies inference and makes evaluation/confusion matrix straightforward
    df['target_config'] = df['encoding'] + "+" + df['coding'] + "+" + df['modulation']
    
    # Feature columns: file_type, file_size_kb, snr, noise_level
    X_raw = df[['file_type', 'file_size_kb', 'snr', 'noise_level']]
    y_raw = df['target_config']
    
    # Label encode input categorical var (file_type)
    le_file_type = LabelEncoder()
    X = X_raw.copy()
    X['file_type'] = le_file_type.fit_transform(X['file_type'])
    
    # Label encode target variable
    le_target = LabelEncoder()
    y = le_target.fit_transform(y_raw)
    
    # Scale numerical features (optional but good practice)
    scaler = StandardScaler()
    X[['file_size_kb', 'snr', 'noise_level']] = scaler.fit_transform(X[['file_size_kb', 'snr', 'noise_level']])
    
    # 2. Train-Test Split (80/20)
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    
    print(f"Training on {len(X_train)} samples, testing on {len(X_test)} samples...")
    print(f"Number of unique optimal configurations (classes): {len(le_target.classes_)}")
    
    # 3. Model Training (Random Forest Default)
    clf = RandomForestClassifier(n_estimators=100, random_state=42, n_jobs=-1)
    clf.fit(X_train, y_train)
    
    # 4. Evaluation
    y_pred = clf.predict(X_test)
    acc = accuracy_score(y_test, y_pred)
    
    print("\n=== Model Evaluation ===")
    print(f"Accuracy: {acc * 100:.2f}%")
    
    # We might have classes in y_test that are not all classes, so handle labels properly
    report = classification_report(y_test, y_pred, target_names=le_target.inverse_transform(np.unique(y_test)), zero_division=0)
    print("\nClassification Report:\n", report)
    
    # 5. Confusion Matrix Visualization (Bonus)
    cm = confusion_matrix(y_test, y_pred)
    plt.figure(figsize=(10, 8))
    # Simplify axes if there are too many classes
    unique_classes_in_test = le_target.inverse_transform(np.unique(y_test))
    sns.heatmap(cm, annot=False, cmap="Blues", fmt='g', 
                xticklabels=unique_classes_in_test, yticklabels=unique_classes_in_test)
    plt.title('Confusion Matrix: Predicted vs Actual Configurations')
    plt.xlabel('Predicted')
    plt.ylabel('Actual')
    plt.xticks(rotation=90)
    plt.tight_layout()
    cm_path = os.path.join(output_dir, "confusion_matrix.png")
    plt.savefig(cm_path)
    print(f"\nSaved confusion matrix plot to {cm_path}")
    
    # 6. Export Models and Transformers
    model_path = os.path.join(output_dir, "adaptive_model.pkl")
    # Save a dictionary of all required components for inference
    export_dict = {
        'model': clf,
        'scaler': scaler,
        'le_file_type': le_file_type,
        'le_target': le_target
    }
    joblib.dump(export_dict, model_path)
    print(f"Saved trained pipeline to {model_path}")

if __name__ == "__main__":
    current_dir = os.path.dirname(os.path.abspath(__file__))
    data_file = os.path.join(current_dir, "labeled_transmission_data.csv")
    
    if not os.path.exists(data_file):
        print(f"Error: {data_file} not found. Please run dataset_generator.py first.")
    else:
        train_and_export(data_file, current_dir)
