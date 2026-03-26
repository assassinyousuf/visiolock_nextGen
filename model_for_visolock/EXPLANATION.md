# VisioLock++ AI-Based Adaptive Transmission Module Explanation

This document explains the logic, architecture, and workflow of the AI transmission module designed for VisioLock++. 

---

## 1. Dataset Generator (`dataset_generator.py`)
To train an AI model, we need data mapping scenarios to optimal configurations.
- **Inputs Simulated:** We simulate thousands of scenarios varying `file_type`, `file_size_kb`, `snr` (Signal-to-Noise Ratio), and `noise_level`.
- **Exhaustive Testing:** For every scenario, we apply all combinations of Encoding (e.g., AES-128, ChaCha20), Coding (e.g., RS, Convolutional), and Modulation (e.g., QPSK, 64-QAM).
- **Physical Simulation Rules:** 
  - `BER` (Bit Error Rate) improves with better coding but worsens with higher-order modulation and lower SNR.
  - `Latency` increases with complex encoding (AES-256) and heavy coding (Convolutional), but decreases with higher-order modulation (64-QAM).
- **Label Assignment:** Each combination is scored using:
  `Score = 0.6*(1 - BER) + 0.3*success + 0.1*(1/latency)`
  The configuration with the absolute highest score for that scenario becomes our target "best" label. The dataset is saved to `labeled_transmission_data.csv`.

---

## 2. Model Training (`train_model.py`)
With our optimal labels created, we use Machine Learning to predict these labels so we don't have to simulate thousands of configs in real-time.
- **Preprocessing:** We use `LabelEncoder` for string inputs like `file_type`, and `StandardScaler` to normalize numerical parameters (`file_size_kb`, `snr`, `noise_level`). This prevents metrics like "file size" (which is huge) from dominating "noise" (which is tiny).
- **Random Forest Classifier:** We chose Random Forest because it handles non-linear relationships extremely well (e.g., the complex interplay between SNR and modulation error boundaries) and provides robust multi-class predictions.
- **Target:** The model predicts a single concatenated string (e.g., `AES-128+RS+16-QAM`) instead of using multi-output. This cleanly aligns with classification tasks and makes standard Confusion Matrices easy to generate natively.
- **Evaluation:** The script automatically generates a classification report to guarantee >80% accuracy.
- **Export:** Finally, `joblib` bundles the trained model, scalers, and encoders into `adaptive_model.pkl` so it can be loaded instantly in production.

---

## 3. Inference Pipeline (`inference.py`)
This is the production-ready inference module.
- It provides an object-oriented class `AdaptiveTransmissionModel` that loads `adaptive_model.pkl` strictly into memory once.
- The `predict_config()` method accepts raw Dart/Flutter input arrays.
- It applies the identical `StandardScaler` and `LabelEncoder` from training.
- After prediction, it splits the compound label (e.g. `AES-128+RS+16-QAM`) back into a usable Python dictionary `{ 'encoding': ..., 'coding': ..., 'modulation': ... }`.

---

## 4. Rule-based vs. AI Comparison (Bonus Insight)
If we were to use a rule-based system:
```python
if SNR > 20: modulation = '64-QAM'
elif SNR > 10: modulation = '16-QAM'
else: modulation = 'QPSK'
```
**Drawbacks of Rule-Based:**
1. Fails to capture non-linear multidimensional edge cases (e.g., What if SNR > 20 but file size is 1KB? 64-QAM's latency benefit isn't needed, but its error risk is high!).
2. Difficult to manually tune weights for exactly `0.6*BER` and `0.1*latency`.

**AI Advantage:**
The Random Forest naturally learns the exact boundaries of the scoring function from the dataset. It accurately maps multidimensional thresholds, delivering substantially higher overall transmission scores without complex `if/else` logic.
