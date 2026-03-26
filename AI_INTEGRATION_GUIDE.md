# VisioLock++ AI Integration Guide

## Overview
VisioLock++ now integrates a pre-trained Random Forest machine learning model for adaptive transmission parameter selection. The AI model analyzes channel conditions and file properties to recommend optimal encoding, coding, and modulation schemes in real-time.

## Architecture

### Components
1. **Backend API Server**: Flask application wrapping the ML model
2. **Dart Service Client**: `ai_transmission_service.dart` for API communication
3. **Fallback Logic**: Rule-based configuration if API is unavailable

### Model Information
- **Type**: scikit-learn Random Forest Classifier
- **Training Data**: 1000+ simulated transmission scenarios
- **Input Features**:
  - `file_type`: Type of content (image, audio, video, text)
  - `file_size_kb`: File size in kilobytes
  - `snr`: Signal-to-Noise Ratio in dB
  - `noise_level`: Normalized noise level (0.0-1.0)
- **Output**: Optimal {encoding, coding, modulation} combination
- **Accuracy**: >80% on validation set

## Setup Instructions

### Step 1: Install Python Dependencies

Navigate to the model directory and install required packages:

```bash
cd model_for_visolock
pip install flask joblib scikit-learn pandas numpy
# or if using a virtual environment:
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install flask joblib scikit-learn pandas numpy
```

### Step 2: Start the Flask API Server

From the `model_for_visolock` directory:

```bash
python app.py
```

Expected output:
```
 * Running on http://127.0.0.1:5000
 * WARNING: This is a development server...
✓ AI Model loaded successfully
```

**Note for different platforms:**
- **Physical Android Device & Linux**: Update the API URL to your machine's IP (e.g., `http://192.168.1.100:5000`)
- **Android Emulator**: Uses `http://10.0.2.2:5000` automatically
- **iOS Simulator**: Uses `http://localhost:5000`

### Step 3: Configure Dart Service (Optional)

The `ai_transmission_service.dart` is pre-configured for most scenarios. Modify the API URL if needed:

```dart
static const String apiUrl = 'http://127.0.0.1:5000';
static const String androidEmulatorUrl = 'http://10.0.2.2:5000';
```

## Usage

### Using the AI Service in Your Code

```dart
import 'package:visiolock_nextgen/services/ai_transmission_service.dart';

// Check if API server is available
bool isAvailable = await AiTransmissionService.isServerAvailable();

if (isAvailable) {
  // Get optimal configuration from AI model
  final config = await AiTransmissionService.getOptimalConfiguration(
    fileType: 'image',
    fileSizeKb: 2048.0,
    snr: 20.0,  // Signal-to-Noise Ratio in dB
    noiseLevel: 0.1,  // Normalized 0-1
  );
  
  print('Encoding: ${config['encoding']}');
  print('Coding: ${config['coding']}');
  print('Modulation: ${config['modulation']}');
  print('Source: ${config['source']}');  // 'ai_model' or 'fallback'
}
```

### With Fallback Logic

```dart
final config = await AiTransmissionService.getConfigurationWithFallback(
  fileType: 'video',
  fileSizeKb: 5000.0,
  snr: 15.0,
  noiseLevel: 0.3,
  fallbackFunction: () async {
    // Your rule-based fallback logic
    return {
      'encoding': 'AES-256',
      'coding': 'turbo',
      'modulation': '64-QAM',
    };
  },
);
```

## API Endpoints

### POST /predict
Predicts optimal transmission configuration

**Request:**
```json
{
  "file_type": "image",
  "file_size_kb": 2048.0,
  "snr": 20.0,
  "noise_level": 0.1
}
```

**Response (Success):**
```json
{
  "success": true,
  "source": "ai_model",
  "encoding": "AES-128",
  "coding": "RS",
  "modulation": "16-QAM"
}
```

**Response (Fallback):**
```json
{
  "success": true,
  "source": "fallback",
  "encoding": "AES-128",
  "coding": "RS",
  "modulation": "16-QAM",
  "note": "Using fallback configuration (model unavailable)"
}
```

### GET /health
Health check endpoint

**Response:**
```json
{
  "status": "healthy",
  "model_loaded": true,
  "version": "2.0.0"
}
```

## Troubleshooting

### API Connection Issues

**Problem**: `❌ AI Server unavailable`
- **Solution**: Ensure `python app.py` is running
- **Check**: Verify network connectivity between device/emulator and server
- **For Android Emulator**: Ensure using `10.0.2.2:5000`, not `127.0.0.1:5000`
- **For Physical Device**: Replace `127.0.0.1` with actual machine IP

### Model Loading Failed

**Problem**: `✗ Failed to load AI model: [error message]`
- **Solution**: Verify `adaptive_model.pkl` exists in `model_for_visolock` directory
- **Check**: Run `pip install scikit-learn joblib` to ensure dependencies are installed
- **Reinstall**: Delete `adaptive_model.pkl` and run `python train_model.py` to retrain

### Timeout Errors

**Problem**: `⏱️ AI API request timed out`
- **Solution**: Increase timeout in `ai_transmission_service.dart`:
  ```dart
  static const Duration timeoutDuration = Duration(seconds: 15);
  ```
- **Check**: Verify network speed and server workload

### Module Import Errors in Python

**Problem**: `ModuleNotFoundError: No module named 'flask'`
- **Solution**: Ensure pip install completed successfully
  ```bash
  pip install flask joblib scikit-learn pandas numpy --upgrade
  ```

## Performance Metrics

- **API Latency**: ~100-200ms (depends on network)
- **Model Prediction Latency**: ~10-50ms
- **Memory Usage**: ~150MB (Python process)
- **Accuracy**: >80% on validation set
- **Throughput**: 100+ predictions/second

## File Compatibility

The AI model predicts optimal configurations for:

**File Types**:
- image (JPG, PNG, GIF, WebP)
- audio (MP3, WAV, AAC)
- video (MP4, MOV, MKV)
- text (TXT, PDF, DOC)

**Encoding Methods**:
- AES-128 (lightweight)
- AES-256 (maximum security)

**Error Correction Codes**:
- RS (Reed-Solomon)
- convolutional (fast)
- turbo (robust)

**Modulation Schemes**:
- 16-QAM (robust, lower bandwidth)
- 64-QAM (balanced)
- 256-QAM (high bandwidth, requires good SNR)

## Integration with Adaptive Services

The AI model works alongside existing adaptive services:

1. **ContentAnalyzerService**: Analyzes file properties (size, type, compression)
2. **ChannelStateEstimatorService**: Estimates SNR and noise from channel conditions
3. **AiTransmissionService**: Queries ML model with analyzed parameters
4. **AdaptiveEncodingSelectorService**: Applies selected encoding
5. **AdaptiveTransmissionSystem**: Orchestrates entire pipeline

## Advanced Usage

### Batch Configuration Prediction

```dart
final scenarios = [
  {'file_type': 'image', 'file_size_kb': 2048.0, 'snr': 20.0, 'noise_level': 0.1},
  {'file_type': 'video', 'file_size_kb': 5000.0, 'snr': 15.0, 'noise_level': 0.3},
  {'file_type': 'audio', 'file_size_kb': 512.0, 'snr': 25.0, 'noise_level': 0.05},
];

final results = await AiTransmissionService.getBatchConfigurations(
  scenarios: scenarios,
);
```

## Upgrading the Model

To retrain the model with new data:

1. **Update training data**: Place new CSV in `model_for_visolock/` with columns: `file_type`, `file_size_kb`, `snr`, `noise_level`, `optimal_encoding`, `optimal_coding`, `optimal_modulation`

2. **Retrain**:
   ```bash
   cd model_for_visolock
   python train_model.py
   ```

3. **Restart API server**: Stop and restart `app.py`

## References

- **Framework**: Flask (Python)
- **ML Library**: scikit-learn
- **HTTP Client**: Dart `http` package
- **Model Format**: joblib pickle (.pkl)

## Support

For issues or questions:
1. Check the logs in the Flask server console
2. Verify network connectivity
3. Confirm all dependencies are installed
4. Review error messages from `ai_transmission_service.dart` (logged with ❌ or ⚠️ symbols)
