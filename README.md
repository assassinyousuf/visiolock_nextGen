# VisioLock++ (v2.0)

**A Cognitive Acoustic Communication System with AI-Optimized Modulation and Hybrid Encryption.**

VisioLock++ is a next-generation Flutter application that enables secure, air-gapped data transmission between devices using sound waves. Unlike traditional acoustic modems with fixed parameters, VisioLock++ utilizes an on-device AI (TensorFlow Lite) to analyze environmental noise in real-time and adapt its transmission strategy—switching modulation schemes, error correction rates, and encryption protocols to ensure reliability in any environment.

---

## 🚀 Key Features (v2.0)

### 🧠 AI-Optimized Adaptive Modulation
- **Cognitive Decision Engine**: A lightweight MLP neural network runs on-device (TFLite) to analyze Channel State Information (SNR, Noise Floor).
- **Dynamic Switching**: Automatically selects the optimal balance between speed and reliability:
    - **High SNR (>25dB)**: 16-QAM + AES-256-GCM (High Speed)
    - **Medium SNR**: 8-PSK + RS(255, 223)
    - **Low SNR (<10dB)**: BFSK + SAIC-ACT + 3x Repetition (Maximum Reliability)

### 📦 Multi-File Support (I2A3++ Protocol)
- **Batch Transmission**: Send mixed content (images, PDFs, JSON, text) in a single stream.
- **Robust Framing**: New **I2A3++** protocol allows for partial recovery of files even if some frames are corrupted.
- **Metadata Encapsulation**: Preserves filenames, types, and sizes across the air-gap.

### 🛡️ Hybrid Security Architecture
- **Biometric Binding**: Encryption keys are derived from hardware-backed biometric secrets (fingerprint/FaceID) coupled with a PIN.
- **SAIC-ACT (Spectrogram Adaptive Image Cipher)**: A custom stream cipher designed for hostile acoustic environments. It shapes the ciphertext to minimize "destructive interference" patterns (like `000` or `111` sequences) in the analog signal.
- **AES-256-GCM**: Industry-standard authenticated encryption for high-throughput scenarios.

---

## 🛠️ Tech Stack

- **Frontend**: Flutter 3.19+ (Dart)
- **AI Engine**: TensorFlow Lite (Python training, Dart inference)
- **Audio DSP**: Custom Dart FFI + `flutter_sound`
- **State Management**: Riverpod 2.0
- **Cryptography**: PointyCastle + Android Keystore + `cryptography`

---

## 🏗️ System Architecture

The app operates in a closed loop:

1.  **Sensing**: Microphone captures ambient noise signature.
2.  **Inference**: TFLite model predicts the Packet Error Rate (PER) for various configurations.
3.  **Selection**: System picks the highest-throughput configuration that satisfies reliability thresholds.
4.  **Transmission**: Data is encrypted, framed (I2A3++), modulated, and played via audio channels.

---

## 📥 Installation

### Prerequisites
- Flutter SDK (3.19+)
- Python 3.9+ (Only for retraining models, not for running the app)
- Android Studio / Xcode

### Build & Run
```bash
# 1. Get dependencies
flutter pub get

# 2. Run on device (Emulator microphone support is limited)
flutter run --release
```

*Note: The TFLite model is already bundled in `assets/models/`. You do not need to run a Python server.*

---

## 🧪 Documentation

Detailed guides are available in the repository:

- **[paper.md](paper.md)**: Full academic paper describing the theoretical framework.
- **[MULTI_FILE_ENCRYPTION_GUIDE.md](MULTI_FILE_ENCRYPTION_GUIDE.md)**: Details on the I2A3++ protocol and file batching.
- **[AI_INTEGRATION_GUIDE.md](AI_INTEGRATION_GUIDE.md)**: How the TFLite model was trained and integrated.
- **[TESTING_ENCRYPTION_METHODS.md](TESTING_ENCRYPTION_METHODS.md)**: Benchmarks of AES-GCM vs. SAIC-ACT.

---

## 🤝 Contributing

1.  Fork the repository.
2.  Create your feature branch (`git checkout -b feature/amazing-feature`).
3.  Commit your changes (`git commit -m 'Add some amazing feature'`).
4.  Push to the branch (`git push origin feature/amazing-feature`).
5.  Open a Pull Request.

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.
