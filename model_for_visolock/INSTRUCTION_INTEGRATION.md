# VisioLock++ Integration Guide: AI Transmission Module to Flutter

This guide explains how to integrate the Python-based AI transmission model into the VisioLock++ Flutter application.

## System Architecture

The most robust way to connect a Python machine learning model to a mobile framework like Flutter is through a **RESTful API backend**. 
Since `adaptive_model.pkl` requires Python (`scikit-learn`, `pandas`, `joblib`) to run inference, we wrap the inference logic in a lightweight web server like Flask or FastAPI.

```text
[ Flutter App ] <--- HTTP JSON ---> [ Python Server (API) ]
  (Frontend)                           (Inference Backend)
```

## Step 1: Create the Prediction API (Python)

Create a file named `app.py` in the same directory as `inference.py`:

```python
from flask import Flask, request, jsonify
from inference import AdaptiveTransmissionModel

app = Flask(__name__)
predictor = AdaptiveTransmissionModel()

@app.route('/predict', methods=['POST'])
def predict():
    data = request.json
    
    file_type = data.get('file_type', 'binary')
    file_size_kb = data.get('file_size_kb', 100.0)
    snr = data.get('snr', 15.0)
    noise_level = data.get('noise_level', 0.1)
    
    # Run Inference
    config = predictor.predict_config(file_type, file_size_kb, snr, noise_level)
    
    return jsonify(config)

if __name__ == '__main__':
    # Run the server on port 5000
    app.run(host='0.0.0.0', port=5000)
```

**Run the server:**
```bash
pip install flask
python app.py
```

---

## Step 2: Call the API from Flutter (Dart)

To make HTTP requests from Flutter, add the `http` package to your `pubspec.yaml`:
```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.1.0
```

Create a Dart service class, e.g., `ai_transmission_service.dart`, to handle real-time fetching:

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class AiTransmissionService {
  // Use your computer's local IP address if testing on a physical device,
  // or 10.0.2.2 if testing on an Android Emulator.
  final String apiUrl = 'http://127.0.0.1:5000/predict';

  Future<Map<String, dynamic>> getOptimalConfiguration({
    required String fileType,
    required double fileSizeKb,
    required double snr,
    required double noiseLevel,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'file_type': fileType,
          'file_size_kb': fileSizeKb,
          'snr': snr,
          'noise_level': noiseLevel,
        }),
      );

      if (response.statusCode == 200) {
        // Example Response: {"coding": "RS", "encoding": "AES-128", "modulation": "16-QAM"}
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load configuration');
      }
    } catch (e) {
      print('Error calling AI Model: $e');
      // Fallback rule-based logic if AI server is unreachable
      return {
        'encoding': 'AES-128',
        'coding': 'RS',
        'modulation': 'QPSK',
      };
    }
  }
}
```

---

## Step 3: Use the Result in the Transmission Pipeline

When the user selects a file to send, calculate its size and fetch the real-time SNR from the channel state. 
Wait for the AI to return the optimal config, then use those parameters in your physical layer logic.

```dart
// Example Usage inside a Flutter Widget or Bloc
void _startSecureTransmission() async {
    // 1. Gather file metadata and channel state
    String fileType = 'image';
    double fileSizeKb = 2048.0; 
    double currentSnr = 12.5; // From hardware/channel estimator
    double currentNoise = 0.15;
    
    // 2. Predict optimal setup via AI
    final aiService = AiTransmissionService();
    final config = await aiService.getOptimalConfiguration(
      fileType: fileType,
      fileSizeKb: fileSizeKb,
      snr: currentSnr,
      noiseLevel: currentNoise,
    );
    
    print("AI Decided Parameters: ");
    print("Encoding: \${config['encoding']}");
    print("Coding: \${config['coding']}");
    print("Modulation: \${config['modulation']}");
    
    // 3. Pass to hardware or software transmission pipeline
    // prepareData(fileBytes, config['encoding'], config['coding']);
    // transmit(modulatedData, config['modulation']);
}
```

## Summary of the Data Flow
1. **User Action**: The user selects a file in Flutter.
2. **Channel Sensing**: Flutter queries the local device/network layer for the current SNR and Noise levels.
3. **AI Inference**: Flutter sends (`file_type`, `file_size_kb`, `snr`, `noise_level`) to the Python pipeline.
4. **Adaptive Reaction**: The Random Forest AI returns the predicted best `encoding`, `coding`, and `modulation` schema.
5. **Execution**: Flutter applies the returned config to process and transmit the data.
