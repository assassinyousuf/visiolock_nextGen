import pandas as pd
import numpy as np
import os
import joblib
import warnings

# Suppress scikit-learn warnings for cleaner output during inference
warnings.filterwarnings("ignore", category=UserWarning)

class AdaptiveTransmissionModel:
    def __init__(self, model_dir="."):
        model_path = os.path.join(model_dir, "adaptive_model.pkl")
        if not os.path.exists(model_path):
            raise FileNotFoundError(f"Model file not found at {model_path}. Please train the model first.")
        
        # Load the pipeline components
        components = joblib.load(model_path)
        self.model = components['model']
        self.scaler = components['scaler']
        self.le_file_type = components['le_file_type']
        self.le_target = components['le_target']
        
    def predict_config(self, file_type, file_size_kb, snr, noise_level):
        """
        Predicts the optimal transmission configuration for the given scenario.
        
        Args:
            file_type (str): 'image', 'text', 'binary', or 'pdf'
            file_size_kb (float): Size of the file in KB
            snr (float): Signal-to-noise ratio in dB
            noise_level (float): Noise penalty factor (e.g., 0.01 to 0.5)
            
        Returns:
            dict: The predicted optimal encoding, coding, and modulation schemes.
        """
        # Encode the file type
        try:
            encoded_type = self.le_file_type.transform([file_type])[0]
        except ValueError:
            print(f"Warning: Unknown file type '{file_type}'. Defaulting to 'binary'.")
            encoded_type = self.le_file_type.transform(['binary'])[0]
            
        # Create input array for scaling numerical features
        X_num = pd.DataFrame(
            [[file_size_kb, snr, noise_level]], 
            columns=['file_size_kb', 'snr', 'noise_level']
        )
        
        # Scale numerical features
        X_scaled = self.scaler.transform(X_num)
        
        # Combine all features into single DataFrame to match training feature names
        # Training order: file_type, file_size_kb, snr, noise_level
        X_input = pd.DataFrame(
            [[encoded_type, X_scaled[0][0], X_scaled[0][1], X_scaled[0][2]]],
            columns=['file_type', 'file_size_kb', 'snr', 'noise_level']
        )
        
        # Predict combined class label
        pred_encoded = self.model.predict(X_input)
        
        # Decode the class label
        pred_str = self.le_target.inverse_transform(pred_encoded)[0]
        
        # Split back into encoding, coding, modulation
        parts = pred_str.split('+')
        
        return {
            'encoding': parts[0],
            'coding': parts[1],
            'modulation': parts[2]
        }

if __name__ == "__main__":
    # Example usage for testing the inference pipeline locally
    current_dir = os.path.dirname(os.path.abspath(__file__))
    try:
        predictor = AdaptiveTransmissionModel(current_dir)
        print("--- Loaded VisioLock++ Adaptive Transmission AI ---")
        
        # Test Case 1: High SNR, large file
        # Expected behavior: fast modulation (64-QAM), less redundant coding, strong encryption
        print("\n[Scenario 1] File: PDF (5000KB) | SNR: 25dB | Noise: 0.02")
        conf1 = predictor.predict_config('pdf', 5000.0, 25.0, 0.02)
        print(f"-> Predicted Config: {conf1}")
        
        # Test Case 2: Low SNR, small file
        # Expected behavior: robust modulation (QPSK/FSK), strong error coding (Convolutional/RS)
        print("\n[Scenario 2] File: Text (50KB) | SNR: 8dB | Noise: 0.3")
        conf2 = predictor.predict_config('text', 50.0, 8.0, 0.3)
        print(f"-> Predicted Config: {conf2}")
        
    except FileNotFoundError as e:
        print(e)
