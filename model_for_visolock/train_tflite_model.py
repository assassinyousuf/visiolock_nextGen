"""
Train a Scikit-Learn MLP for VisioLock++ AI Offline (Custom JSON Weights)
This script trains a lightweight Multi-Layer Perceptron and exports its weights/biases to JSON
for offline inference directly in Flutter apps (manual implementation).
"""

import pandas as pd
import numpy as np
import json
from sklearn.neural_network import MLPClassifier
from sklearn.preprocessing import LabelEncoder, StandardScaler
from sklearn.model_selection import train_test_split
import joblib
import os

# Configuration
DATASET_PATH = 'labeled_transmission_data.csv'
OUTPUT_MODEL = 'model_weights.json'
SCALER_OUTPUT = 'scaler.pkl'
ENCODER_OUTPUT = 'label_encoder.pkl'

def load_and_prepare_data():
    """Load labeled transmission data and prepare for training"""
    print("📊 Loading dataset...")
    df = pd.read_csv(DATASET_PATH)
    
    # Extract features and target
    X = df[['file_type', 'file_size_kb', 'snr', 'noise_level']].values
    y = df['optimal_config'].values  # Combined label like "AES-128+RS+16-QAM"
    
    # Encode file_type to numeric
    le_file_type = LabelEncoder()
    X[:, 0] = le_file_type.fit_transform(X[:, 0])
    
    # Encode target labels
    le_target = LabelEncoder()
    y_encoded = le_target.fit_transform(y)
    
    # Standardize numerical features
    scaler = StandardScaler()
    X[:, 1:] = scaler.fit_transform(X[:, 1:])
    
    # Save encoder and scaler for inference
    joblib.dump(le_file_type, 'file_type_encoder.pkl')
    joblib.dump(le_target, 'target_encoder.pkl')
    joblib.dump(scaler, SCALER_OUTPUT)
    
    print(f"✓ Dataset loaded: {len(df)} samples")
    print(f"✓ Classes: {list(le_target.classes_)}")
    print(f"✓ Feature shape: {X.shape}")
    
    return X, y_encoded, le_target, scaler, le_file_type

def train_model(X, y_encoded, le_target):
    """Train the MLP neural network using scikit-learn"""
    print("\n🤖 Training neural network (MLP)...")
    
    # Split data
    X_train, X_test, y_train, y_test = train_test_split(
        X, y_encoded, test_size=0.2, random_state=42, stratify=y_encoded
    )
    
    # Build model (3 hidden layers: 64, 32, 16)
    model = MLPClassifier(
        hidden_layer_sizes=(64, 32, 16),
        activation='relu',
        solver='adam',
        max_iter=500,
        random_state=42,
        early_stopping=True
    )
    
    # Train
    model.fit(X_train, y_train)
    
    # Evaluate
    test_accuracy = model.score(X_test, y_test)
    print(f"\n✓ Training complete!")
    print(f"✓ Test Accuracy: {test_accuracy * 100:.2f}%")
    
    return model

def export_weights_to_json(model):
    """Export MLP weights and biases to JSON for use in Dart"""
    print("\n📱 Converting to JSON weights format...")
    
    weights = []
    biases = []
    
    # Extract coefficients (weights) and intercepts (biases)
    for i in range(len(model.coefs_)):
        w = model.coefs_[i].tolist()
        b = model.intercepts_[i].tolist()
        weights.append(w)
        biases.append(b)
        print(f"  Layer {i}: Weights {np.array(w).shape}, Biases {np.array(b).shape}")
    
    model_data = {
        'weights': weights,
        'biases': biases,
        'activation': 'relu',
        'output_activation': 'softmax'
    }
    
    # Save
    with open(OUTPUT_MODEL, 'w') as f:
        json.dump(model_data, f)
    
    file_size_kb = os.path.getsize(OUTPUT_MODEL) / 1024
    print(f"✓ JSON model saved: {OUTPUT_MODEL}")
    print(f"✓ Model size: {file_size_kb:.2f} KB")
    
    return model_data

def create_flutter_config(le_target, scaler, le_file_type):
    """Generate configuration values for Flutter OfflineTransmissionAI"""
    print("\n📋 Generating Flutter configuration...")
    
    # Get target classes
    target_classes = list(le_target.classes_)
    print("\n// Add these to OfflineTransmissionAI.dart targetClasses:")
    print("final List<String> targetClasses = [")
    for i, cls in enumerate(target_classes):
        print(f"  '{cls}',  // index {i}")
    print("];")
    
    # Get file type encoding
    file_types = list(le_file_type.classes_)
    print("\n// Add these to OfflineTransmissionAI.dart fileTypes:")
    print("final List<String> fileTypes = [")
    for ft in file_types:
        print(f"  '{ft}',")
    print("];")
    
    # Get scaler parameters
    print("\n// Add these StandardScaler parameters to OfflineTransmissionAI.dart:")
    print(f"final double meanFileSize = {scaler.mean_[0]};")
    print(f"final double scaleFileSize = {scaler.scale_[0]};")
    print(f"final double meanSnr = {scaler.mean_[1]};")
    print(f"final double scaleSnr = {scaler.scale_[1]};")
    print(f"final double meanNoise = {scaler.mean_[2]};")
    print(f"final double scaleNoise = {scaler.scale_[2]};")
    
    return {
        'target_classes': target_classes,
        'file_types': file_types,
        'scaler_mean': scaler.mean_.tolist(),
        'scaler_scale': scaler.scale_.tolist()
    }

def main():
    """Main training pipeline"""
    print("=" * 60)
    print("VisioLock++ AI Model Training (JSON Export)")
    print("=" * 60)
    
    # Check if dataset exists
    if not os.path.exists(DATASET_PATH):
        print(f"❌ Error: {DATASET_PATH} not found!")
        print("Please ensure labeled_transmission_data.csv is in the current directory.")
        return
    
    # Load and prepare data
    X, y_encoded, le_target, scaler, le_file_type = load_and_prepare_data()
    
    # Train model
    model = train_model(X, y_encoded, le_target)
    
    # Convert to JSON
    export_weights_to_json(model)
    
    # Generate Flutter configuration
    config = create_flutter_config(le_target, scaler, le_file_type)

if __name__ == "__main__":
    main()
    
    print("\n" + "=" * 60)
    print("✅ Training Complete!")
    print("=" * 60)
    print(f"\n📁 Output files:")
    print(f"   - {OUTPUT_MODEL} (TensorFlow Lite model for Flutter)")
    print(f"   - {SCALER_OUTPUT} (Feature scaler parameters)")
    print(f"   - file_type_encoder.pkl (File type encoder)")
    print(f"   - target_encoder.pkl (Config label encoder)")
    print(f"\n💡 Next steps:")
    print(f"   1. Copy {OUTPUT_MODEL} to Flutter: assets/models/")
    print(f"   2. Update pubspec.yaml with 'tflite_flutter: ^0.10.4'")
    print(f"   3. Update OfflineTransmissionAI.dart with the Dart config above")
    print(f"   4. Run: flutter pub get && flutter run")

if __name__ == '__main__':
    main()
