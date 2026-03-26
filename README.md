# VisioLock++

VisioLock++ is a Flutter app for AI-powered adaptive secure cross-media transmission. It converts encrypted content into modulated signals, transmits them over audio channels, and reconstructs the original content on the receiver side with intelligent parameter selection.

The app uses a pre-trained Random Forest ML model to analyze channel conditions and file properties, automatically selecting optimal encoding, error correction, and modulation schemes for reliable transmission.

## Core Workflow

1. Sender analyzes file properties and channel conditions
2. AI model predicts optimal transmission parameters
3. File payload is encrypted and FEC-protected based on AI recommendations
4. Data is modulated into audio and exported as WAV
5. Receiver imports WAV, demodulates, decrypts, and reconstructs the original content

## Features

- **AI-Powered Parameter Selection**: Random Forest model analyzes {file_type, size, SNR, noise_level} for optimal config
- **Multi-format Support**: Images, audio, video, and text files
- **Adaptive Transmission**: Real-time channel estimation with dynamic parameter adjustment
- **Advanced Encryption**: AES-128 and AES-256 with enhanced key derivation
- **Robust Error Correction**: Reed-Solomon and convolutional codes
- **Flexible Modulation**: 16-QAM, 64-QAM, 256-QAM schemes
- **Fallback Logic**: Rule-based configuration if AI server unavailable
- **Cross-Platform**: Runs on Android, iOS, Web, Windows, macOS, Linux

## Tech Stack

- **Frontend**: Flutter / Dart
- **Backend**: Flask API (Python) with scikit-learn ML model
- **Encryption**: AES (crypto package)
- **Error Correction**: Reed-Solomon, convolutional codes
- **Modulation**: FSK, QAM with Goertzel demodulation
- **Machine Learning**: Random Forest Classifier (>80% accuracy)

## Requirements

- Flutter SDK (3.9.2+)
- Dart SDK (via Flutter)
- Android SDK / Android Studio (for Android builds)
- Python 3.8+ with Flask, scikit-learn, pandas, joblib (for AI backend)

## Quick Start

### 1. Setup Flutter App
```bash
flutter pub get
flutter run
```

### 2. Start AI Model Server (in model_for_visolock directory)
```bash
pip install flask joblib scikit-learn pandas numpy
python app.py
```

Server runs on `http://127.0.0.1:5000` (or `http://10.0.2.2:5000` for Android emulator)

## Build APK

```bash
flutter build apk
```

Release APK output: `build/app/outputs/flutter-apk/app-release.apk`

## AI Integration

The app integrates a pre-trained ML model for adaptive transmission:

- **Model Type**: scikit-learn Random Forest Classifier
- **Input Features**: file_type, file_size_kb, snr, noise_level
- **Output**: Optimal {encoding, coding, modulation}
- **Accuracy**: >80% on validation set
- **API**: RESTful endpoint POST `/predict` with JSON I/O

See [AI_INTEGRATION_GUIDE.md](AI_INTEGRATION_GUIDE.md) for detailed setup and usage.

## Architecture

## Release Process

This repository includes automated GitHub release publishing via:

- `.github/workflows/release.yml`

When a tag matching `v*` is pushed, GitHub Actions creates a release and attaches the latest APK found in `release/*.apk`.

Typical release steps:

1. Build the app: `flutter build apk`
2. Copy APK to versioned file (example): `release/app-release-v1.0.2.apk`
3. Commit changes
4. Create tag: `git tag -a v1.0.2 -m "VisioLock v1.0.2"`
5. Push: `git push origin main --follow-tags`

## Current Published Artifacts

- `release/app-release-v1.0.0.apk`
- `release/app-release-v1.0.1.apk`

## Notes

- Exported WAV and decoded image files are stored in the app documents directory.
- On Android 13+, media read permissions are requested when selecting image/audio files.
