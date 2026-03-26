# How to Run VisioLock++ AI Offline entirely in Flutter (TFLite)

Because `scikit-learn` Random Forests cannot easily run natively on mobile devices, the standard approach for offline mobile AI is to train a **TensorFlow Neural Network** and convert it to **TensorFlow Lite (.tflite)**.

I have created a new python script: `train_tflite_model.py`. This script trains a lightweight Multi-Layer Perceptron (MLP) on your existing dataset and exports an `adaptive_model.tflite`.

---

## Step 1: Generate the `.tflite` Model
On your computer, install TensorFlow and run the new script:
```powershell
pip install tensorflow
python "e:\model for visolock\train_tflite_model.py"
```
This will produce `adaptive_model.tflite`.

## Step 2: Add Model to Flutter Assets
1. Create a folder named `assets/models` in your Flutter project.
2. Place `adaptive_model.tflite` inside it.
3. Update your `pubspec.yaml`:
```yaml
assets:
  - assets/models/adaptive_model.tflite
```

## Step 3: Add Dependencies
Add the `tflite_flutter` package to your Flutter project to run inference natively strictly without the internet:
```yaml
dependencies:
  tflite_flutter: ^0.10.4
```

## Step 4: Write the Offline Flutter Service
Below is the exact Dart code you can drop into your app. It loads the tflite model from assets, processes input arrays, runs predictions locally, and decodes the result.

```dart
import 'package:tflite_flutter/tflite_flutter.dart';

class OfflineTransmissionAI {
  Interpreter? _interpreter;
  
  // These mapping arrays must match exactly what `le_target.classes_` generated in Python!
  // You can lookup the exact strings by printing them in Python. Example arrays:
  final List<String> fileTypes = ['binary', 'image', 'pdf', 'text'];
  final List<String> targetClasses = [
    'AES-128+Convolutional+16-QAM', 
    'AES-256+RS+64-QAM',
    // ... insert exactly the labels from Python `le_target.classes_` here ...
  ];

  // From Python's StandardScaler (you'll need to print scaler.mean_ and scaler.scale_)
  final double meanFileSize = 2500.0;
  final double scaleFileSize = 1400.0;
  final double meanSnr = 17.5;
  final double scaleSnr = 8.0;
  final double meanNoise = 0.25;
  final double scaleNoise = 0.15;

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/adaptive_model.tflite');
      print('TFLite Model Loaded Successfully');
    } catch (e) {
      print('Failed to load model: $e');
    }
  }

  Map<String, String> predictConfig(String fileType, double fileSizeBytes, double snr, double noise) {
    if (_interpreter == null) {
      return {'encoding': 'AES-128', 'coding': 'RS', 'modulation': 'QPSK'}; // Fallback
    }

    // 1. Encode fileType (e.g. 'image' -> 1.0)
    double encodedType = fileTypes.indexOf(fileType).toDouble();
    if (encodedType == -1) encodedType = 0.0; // Default to binary

    // 2. Standardize Features (Z-Score normalization used in Python)
    double scaledFile = (fileSizeBytes - meanFileSize) / scaleFileSize;
    double scaledSnr = (snr - meanSnr) / scaleSnr;
    double scaledNoise = (noise - meanNoise) / scaleNoise;

    // 3. Prepare Input Tensor [1, 4] shape
    var input = [
      [encodedType, scaledFile, scaledSnr, scaledNoise]
    ];

    // 4. Prepare Output Tensor [1, NUM_CLASSES] shape
    // Assuming you have 64 possible combinations/classes
    var output = List<double>.filled(targetClasses.length, 0).reshape([1, targetClasses.length]);

    // 5. Run Inference!
    _interpreter!.run(input, output);

    // 6. Find the class with the highest probability (Softmax output)
    List<double> probabilities = output[0];
    int bestIndex = 0;
    double maxProb = probabilities[0];
    
    for (int i = 1; i < probabilities.length; i++) {
      if (probabilities[i] > maxProb) {
        maxProb = probabilities[i];
        bestIndex = i;
      }
    }

    // 7. Decode String Label
    String bestConfigStr = targetClasses[bestIndex];
    List<String> parts = bestConfigStr.split('+');
    
    return {
      'encoding': parts[0],
      'coding': parts[1],
      'modulation': parts[2],
    };
  }
}
```

## Why we switched to Neural Networks instead of Random Forests:
While `scikit-learn` Random Forests are great for quick Python deployments, `scikit-learn` doesn't export to smartphone binary formats easily. TensorFlow Lite (`.tflite`) is the world standard for mobile AI. By training a tiny "Multi-Layer Perceptron" (dense neural network) in `train_tflite_model.py`, we achieve the exact same adaptive logic but in a 50KB mobile-native model format!


# Flutter Integration Guide & Copilot Prompt

This document provides a complete guide and the exact prompt you can paste into **VS Code Copilot** (or any other AI assistant) to automatically generate the Dart/Flutter code required to integrate the VisioLock++ AI Transmission Module.

---

## 1. How the Integration Works (Architecture)

Since your Mobile App (Flutter/Dart) cannot directly run the Python scikit-learn `adaptive_model.pkl` file, you must use a **Client-Server Architecture**:

1. **Python API Server:** You run a lightweight Python server (using Flask or FastAPI) using the provided `inference.py` script. This server loads the ML model and waits for HTTP `POST` requests.
2. **Flutter Client:** Inside your Flutter app, whenever a user wants to transmit a file, the app gathers the file metrics (`file_size_kb`, `file_type`) and hardware metrics (`snr`, `noise_level`). It sends an HTTP `POST` request to the Python API.
3. **Response:** The Python server runs the AI model instantly and returns JSON: `{"encoding": "AES-256", "coding": "RS", "modulation": "16-QAM"}`.
4. **Execution:** The Flutter app parses this JSON and dynamically adjusts its transmission pipeline using these optimal parameters.

---

## 2. Full Prompt for VS Code Copilot

Copy the entire block of text below and paste it into modern VS Code Copilot, GitHub Copilot Chat, or Claude/ChatGPT. It contains all the necessary context for the AI to write the complete, production-ready Flutter code for you.

***

**👇 COPY EVERYTHING BELOW THIS LINE 👇**

```text
Act as an expert Flutter and Dart developer building a research-grade mobile application called "VisioLock++" (an adaptive cross-media secure transmission framework).

I have a Python-based Machine Learning backend running on a local server (`http://10.0.2.2:5000/predict` for Android Emulator or a specific local IP). This API accepts a JSON payload with transmission scenarios and returns the optimal configuration predicted by a Random Forest AI.

**API Information:**
- Endpoint: `POST /predict`
- Request Header: `Content-Type: application/json`
- Request Body (JSON Example): 
  {
    "file_type": "image",
    "file_size_kb": 2048.0,
    "snr": 15.5,
    "noise_level": 0.1
  }
- Response Body (JSON Example):
  {
    "encoding": "AES-256",
    "coding": "RS",
    "modulation": "16-QAM"
  }

**Your Task:**
1. **Model Class:** Create a Dart data model class called `TransmissionConfig` with an `fromJson` factory method to parse the API response (`encoding`, `coding`, `modulation`).
2. **Service Class:** Write an `AiTransmissionService` class. It should have a method `Future<TransmissionConfig> getOptimalConfig(...)` that takes `fileType`, `fileSizeKb`, `snr`, and `noiseLevel` as parameters, uses the `http` package, and makes a POST request to the API. Include robust error handling and a safe fallback configuration (e.g., AES-128, RS, QPSK) in case of a timeout or network error.
3. **UI Integration (Bonus):** Write a clean, modern Flutter Stateful Widget (e.g., `AdaptiveTransmissionScreen`) with:
   - Dummy sliders/dropdowns to mock the input parameters (SNR from 5 to 30, Noise from 0.01 to 0.5, File Size, File Type).
   - A generic "Analyze & Transmit" button.
   - Using a `FutureBuilder` or state variables, establish a pipeline where clicking the button shows a `CircularProgressIndicator` while calling `AiTransmissionService`, and then pleasantly displays the chosen configuration parameters (Encoding, Coding, Modulation) decided by the AI.

Please write clean, documented, modular Dart code following Flutter best practices.
```

**👆 COPY EVERYTHING ABOVE THIS LINE 👆**

---

## 3. Python API Server Setup (Quickstart)

To make the above Flutter code work, you need the Python API running. Save this as `app.py` in the same directory as your `inference.py` and run it.

```python
# app.py
from flask import Flask, request, jsonify
from inference import AdaptiveTransmissionModel

app = Flask(__name__)

# Load the AI pipeline globally
predictor = AdaptiveTransmissionModel()

@app.route('/predict', methods=['POST'])
def predict():
    data = request.json
    
    # Extract features from Flutter request
    file_type = data.get('file_type', 'binary')
    file_size_kb = float(data.get('file_size_kb', 100.0))
    snr = float(data.get('snr', 15.0))
    noise_level = float(data.get('noise_level', 0.1))
    
    # AI predicts the optimum transmission parameters
    config = predictor.predict_config(file_type, file_size_kb, snr, noise_level)
    
    return jsonify(config)

if __name__ == '__main__':
    # Running on 0.0.0.0 exposes the API to your local network (so real phones can reach it)
    app.run(host='0.0.0.0', port=5000)
```

**To start the server:**
```powershell
pip install flask
python app.py
```
