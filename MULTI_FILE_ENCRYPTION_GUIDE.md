# VisioLock++ v2.1 — Multi-File & Multi-Encryption Implementation Guide

## Overview

This guide explains how to use the new multi-file and multi-encryption capabilities in VisioLock++ v2.1. The system now supports:

✅ **Multiple File Types**
- Image files (PNG, JPG, JPEG, BMP, GIF, WebP)
- Text files (TXT, JSON, XML, CSV, MD, JavaScript, Dart)
- Documents (PDF)
- Binary files (ZIP, EXE, DLL, SO, TAR, GZ)

✅ **Multiple Encryption Methods**
- **SAIC-ACT** - Spectrogram Adaptive Image Cipher (optimized for acoustic transmission)
- **AES-256-GCM** - Standard authenticated encryption (industry standard)
- **ChaCha20-Poly1305** - Modern stream cipher with authentication
- **XOR-Crypto** - Lightweight encryption for IoT/embedded systems
- **Hybrid Mode** - Combines multiple methods for maximum security

✅ **Intelligent Method Selection**
- AI-powered recommendations based on file type and channel conditions
- Automatic fallback to rule-based logic if API unavailable
- Security vs performance trade-offs configurable

---

## Architecture

```
┌─────────────────────────────────────────┐
│      Flutter UI (MultiFileScreen)       │
│  Select File Type → Pick File → Choose  │
│  Encryption → Configure → Encrypt       │
└────────────┬────────────────────────────┘
             │
      ┌──────┴──────┬──────────────────────┐
      │             │                      │
      ▼             ▼                      ▼
┌──────────────┐ ┌──────────────┐  ┌──────────────┐
│  Universal   │ │ Encryption   │  │ AI Service   │
│  File        │ │ Selector     │  │ V2 (Online   │
│  Processor   │ │ Service      │  │ or Local)    │
│  (all types) │ │ (9 methods)  │  │              │
└──────┬───────┘ └──────┬───────┘  └────┬─────────┘
       │                │               │
       │  ┌─────────────┴───────────────┘
       │  │
       ▼  ▼
  ┌──────────────────────┐
  │ Multi-Encryption     │
  │ Implementations      │
  │ - AES-GCM           │
  │ - ChaCha20-Poly1305 │
  │ - XOR-Crypto        │
  │ - SAIC-ACT          │
  └──────────────────────┘
       │
       ▼
  ┌──────────────────────┐
  │  Flask API v2        │
  │  (model_for_visolock/│
  │   app_v2.py)         │
  └──────────────────────┘
```

---

## Service Architecture

### 1. **UniversalFileProcessor** (`universal_file_processor.dart`)

Handles loading and processing files of any type:

```dart
final processor = UniversalFileProcessor();

// Load any file
final fileData = await processor.loadFile(File('/path/to/file.pdf'));

// Access metadata
print(fileData.metadata.category); // FileCategory.structured
print(fileData.fileSizeKb);        // File size in KB
print(fileData.sizeString);        // Human-readable size

// Calculate entropy
final entropy = processor.calculateEntropy(fileData.rawBytes);

// Get compression ratio estimate
final ratio = processor.estimateCompressionRatio(fileData.rawBytes);
```

### 2. **EncryptionSelectorService** (`encryption_selector_service.dart`)

Intelligently selects encryption methods:

```dart
final selector = EncryptionSelectorService();

// Get available encrypptions for file type
final available = selector.getAvailableEncryptions(FileCategory.text);

// Get optimal encryption based on conditions
final channel = ChannelStateEstimate(snrDb: 15.0, noiseLevel: 0.1);
final optimal = selector.selectOptimalEncryption(fileData.metadata, channel);

print(optimal.method);              // EncryptionMethod.aesGcm
print(optimal.securityLevel);       // 1.0
print(optimal.supportsStreaming);   // true
```

### 3. **Multi-Encryption Implementations** (`multi_encryption_implementations.dart`)

Concrete implementations of each encryption method:

```dart
// Create implementation
final aesGcm = AesGcmImplementation();
final chacha = ChaCha20Poly1305Implementation();
final xor = XorCryptoImplementation();

// Encrypt data
final encrypted = aesGcm.encrypt(plaintext, key);

// Decrypt data
final decrypted = aesGcm.decrypt(encrypted, key);

// Verify authentication (if supported)
print(aesGcm.requiresAuthentication); // true
print(xor.requiresAuthentication);    // false

// Or use factory
final encryptor = EncryptionFactory.create('AES-256-GCM');
```

### 4. **AiTransmissionServiceV2** (`ai_transmission_service_v2.dart`)

Connects to the backend API for intelligent configuration:

```dart
final aiService = AiTransmissionServiceV2(
  useLocalApi: true,
  deviceIp: '192.168.1.100:5000', // For physical devices
);

// Get optimal transmission configuration
final channel = ChannelStateEstimate(snrDb: 15.0, noiseLevel: 0.2);
final config = await aiService.getOptimalConfiguration(
  fileData: fileData,
  channelState: channel,
);

print(config.encoding);              // e.g., 'SAIC-ACT'
print(config.coding);                // e.g., 'RS'
print(config.modulation);            // e.g., '16-QAM'
print(config.recommendedEncryption); // EncryptionMethod.aesGcm

// Get encryption recommendations
final recommendations = await aiService.getEncryptionRecommendations(
  fileData: fileData,
  channelState: channel,
  priority: 'balanced'
);

for (final rec in recommendations) {
  print('${rec.method}: ${rec.score} (${rec.reason})');
}
```

### 5. **MultiFileTransmissionHandler** (`multi_file_transmission_handler.dart`)

High-level orchestrator for complete transmission workflow:

```dart
final handler = MultiFileTransmissionHandler();

// Set callbacks
handler.onStatusUpdate = (status) => print(status);
handler.onProgressUpdate = (progress) => print('Progress: ${progress*100}%');

// Load file
await handler.selectAndLoadFile(File('/path/to/document.pdf'));

// Get available encryption options
final options = await handler.getEncryptionOptions();

// Configure transmission
await handler.configureTransmission(
  channelState: ChannelStateEstimate(snrDb: 15.0, noiseLevel: 0.1),
);

// Set encryption method
handler.setEncryptionMethod(EncryptionMethod.aesGcm);

// Encrypt file
final encrypted = await handler.encryptFile(
  encryptionKey: derivedKey,
  encryptionMethod: EncryptionMethod.aesGcm,
);

// Check results
print(handler.fileTypeName);         // 'structured'
print(handler.selectedEncryptionName); // 'AES-256-GCM'
print(handler.isEncrypted);          // true
```

---

## Implementation Examples

### Example 1: Encrypt Any File with Auto-Selected Encryption

```dart
import 'package:file_picker/file_picker.dart';
import 'services/multi_file_transmission_handler.dart';

Future<void> encryptAnyFile() async {
  final handler = MultiFileTransmissionHandler();

  // Pick any file
  final result = await FilePicker.platform.pickFiles();
  if (result?.files.isEmpty ?? true) return;

  final file = File(result!.files.first.path!);

  // Load and configure
  await handler.selectAndLoadFile(file);
  await handler.configureTransmission();

  // Encryption key (from biometric, passphrase, etc.)
  final key = Uint8List(32); // Your actual key here

  // Encrypt with recommended method
  final encrypted = await handler.encryptFile(encryptionKey: key);

  print('✓ File encrypted: ${handler.selectedEncryptionName}');
  print('✓ File type: ${handler.fileTypeName}');
  print('✓ Encrypted size: ${encrypted.length} bytes');
}
```

### Example 2: Let User Choose Encryption Method

```dart
Future<void> selectiveEncryption() async {
  final handler = MultiFileTransmissionHandler();
  await handler.selectAndLoadFile(File('/path/to/file.zip'));

  // Get recommendations for current file
  final recommendations = await handler.getEncryptionOptions();

  // Display to user and let them choose
  // (In real UI, show this in a dialog or list)
  for (final rec in recommendations) {
    print('${rec.method}: Score ${rec.score} - ${rec.reason}');
  }

  // User selects one
  handler.setEncryptionMethod(EncryptionMethod.chaCha20);

  // Encrypt with user's choice
  final encrypted = await handler.encryptFile(encryptionKey: key);
}
```

### Example 3: Direct Encryption Method Usage

```dart
import 'services/multi_encryption_implementations.dart';

void demonstrateEncryption() {
  // Create key (32 bytes = 256 bits)
  final key = Uint8List(32)
    ..[0] = 0x42; // Your actual key derivation here

  // Example plaintext
  final plaintext = Uint8List.fromList('Hello, World!'.codeUnits);

  // AES-GCM
  final aesGcm = AesGcmImplementation();
  final encryptedAes = aesGcm.encrypt(plaintext, key);
  final decryptedAes = aesGcm.decrypt(encryptedAes, key);
  print('AES-GCM: ${String.fromCharCodes(decryptedAes)}');

  // ChaCha20-Poly1305
  final chacha = ChaCha20Poly1305Implementation();
  final encryptedChacha = chacha.encrypt(plaintext, key);
  final decryptedChacha = chacha.decrypt(encryptedChacha, key);
  print('ChaCha20: ${String.fromCharCodes(decryptedChacha)}');

  // XOR (fast, lightweight)
  final xor = XorCryptoImplementation();
  final encryptedXor = xor.encrypt(plaintext, key);
  final decryptedXor = xor.decrypt(encryptedXor, key);
  print('XOR: ${String.fromCharCodes(decryptedXor)}');
}
```

### Example 4: Channel-Aware Encryption Selection

```dart
Future<void> adaptiveEncryption() async {
  final aiService = AiTransmissionServiceV2();
  final handler = MultiFileTransmissionHandler();

  await handler.selectAndLoadFile(File('/path/to/file.txt'));

  // Simulate different channel conditions
  final scenarios = [
    ('Excellent', ChannelStateEstimate(snrDb: 25.0, noiseLevel: 0.05)),
    ('Good', ChannelStateEstimate(snrDb: 15.0, noiseLevel: 0.1)),
    ('Fair', ChannelStateEstimate(snrDb: 10.0, noiseLevel: 0.2)),
    ('Poor', ChannelStateEstimate(snrDb: 5.0, noiseLevel: 0.4)),
  ];

  for (final (condition, channel) in scenarios) {
    final recs = await aiService.getEncryptionRecommendations(
      fileData: handler.selectedFile!,
      channelState: channel,
      priority: 'balanced',
    );

    print('$condition channel (SNR: ${channel.snrDb} dB)');
    print('  Recommended: ${recs.first.method}');
    print('  Score: ${recs.first.score}');
  }
}
```

---

## Updated Python API (app_v2.py)

### Starting the Backend

```bash
cd model_for_visolock

# Install dependencies
pip install flask flask-cors

# Run the server
python app_v2.py

# Server runs on http://localhost:5000
```

### API Endpoints

#### 1. Health Check
```
GET /api/health

Response:
{
  "status": "healthy",
  "service": "VisioLock++ Adaptive Transmission API",
  "version": "2.0.0",
  "ai_model_loaded": true
}
```

#### 2. Get Transmission Configuration
```
POST /api/predict

Request:
{
  "file_type": "text|image|document|binary",
  "file_size_kb": 100.5,
  "snr": 15.0,
  "noise_level": 0.1,
  "encryption_method": "auto|SAIC-ACT|AES-256-GCM|ChaCha20-Poly1305|XOR-Crypto"
}

Response:
{
  "encoding": "DEFLATE",
  "coding": "RS",
  "modulation": "16-QAM",
  "recommended_encryption": "AES-256-GCM",
  "reasoning": "Text file detected - text content is compressible; Good channel quality - balanced configuration; Encryption: AES-256-GCM for this file type and channel conditions"
}
```

#### 3. Get Encryption Recommendations
```
POST /api/recommend-encryption

Request:
{
  "file_type": "text",
  "file_size_kb": 50.0,
  "snr": 15.0,
  "noise_level": 0.1,
  "priority": "balanced|security|performance"
}

Response:
{
  "recommendations": [
    {
      "method": "AES-256-GCM",
      "score": 0.95,
      "security_level": 1.0,
      "performance": 0.9,
      "streaming": true,
      "authenticated": true
    },
    ...
  ]
}
```

#### 4. Analyze File
```
POST /api/analyze-file

Request:
{
  "file_name": "document.pdf",
  "file_size_kb": 250.0,
  "snr": 15.0,
  "noise_level": 0.1
}

Response:
{
  "file_name": "document.pdf",
  "file_type": "document",
  "file_size_kb": 250.0,
  "estimated_transmission_time": 25.0,
  "recommended_encryption": "AES-256-GCM"
}
```

#### 5. Get Available Encryption Methods
```
GET /api/encryption-methods

Response:
{
  "available_methods": {
    "SAIC-ACT": { ... },
    "AES-256-GCM": { ... },
    "ChaCha20-Poly1305": { ... },
    ...
  }
}
```

---

## File Type Support Matrix

| File Type  | Extensions | Recommended Encryption | Supports Compression |
|------------|-----------|----------------------|----------------------|
| **Image** | PNG, JPG, JPEG, BMP, GIF, WebP | SAIC-ACT | No |
| **Text** | TXT, JSON, XML, CSV, MD, JS, Dart | AES-256-GCM | Yes |
| **Document** | PDF | AES-256-GCM | Yes |
| **Binary** | ZIP, EXE, DLL, SO, TAR, GZ | ChaCha20 | No |

---

## Encryption Comparison

| Method | Security | Speed | Streaming | Authentication | Best For |
|--------|----------|-------|-----------|-----------------|----------|
| **SAIC-ACT** | ★★★★★ | ★★★★ | ✗ | ✗ | Images for acoustic |
| **AES-256-GCM** | ★★★★★ | ★★★★ | ✓ | ✓ | General purpose |
| **ChaCha20-Poly1305** | ★★★★☆ | ★★★★★ | ✓ | ✓ | Performance-critical |
| **XOR-Crypto** | ★★☆☆☆ | ★★★★★ | ✓ | ✗ | IoT/Ultra-lightweight |
| **Hybrid** | ★★★★★ | ★★★☆ | ✗ | ✓ | Maximum security |

---

## Migration from v2.0 (Image-Only)

### Old Code (v2.0)
```dart
// Only images allowed
final result = await FilePicker.platform.pickFiles(
  type: FileType.custom,
  allowedExtensions: ['png', 'jpg', 'jpeg', 'bmp', 'webp'],
);

final imageFile = File(result!.files.first.path!);
final encrypted = _encryptionService.encryptBytes(
  dataBytes: payload,
  key: key,
);
```

### New Code (v2.1)
```dart
// Any file type supported
final result = await FilePicker.platform.pickFiles();

final file = File(result!.files.first.path!);
final handler = MultiFileTransmissionHandler();
await handler.selectAndLoadFile(file);

// Get recommendations
final recommendations = await handler.getEncryptionOptions();

// Encrypt with chosen method
final encrypted = await handler.encryptFile(
  encryptionKey: key,
  encryptionMethod: EncryptionMethod.aesGcm,
);
```

---

## Troubleshooting

### "API request timed out"
- Ensure Python backend is running: `python app_v2.py`
- Check network connectivity
- Adjust timeout in `AiTransmissionServiceV2`

### "Encryption method not suitable for this file type"
- Some methods only support specific file types
- Use `getAvailableEncryptions()` to see compatible methods

### "Authentication tag verification failed"
- Data may be corrupted in transit
- Use reliable channel or increase error correction coding

### Missing assets for TFLite
- Comment out asset if using online API only
- Run `python train_tflite_model.py` to generate offline model

---

## Performance Tips

1. **For large files**: Use streaming encryption (ChaCha20 or AES-GCM)
2. **For text files**: Enable compression before encryption
3. **For poor channels**: Increase error correction coding
4. **For offline mode**: Use XOR-Crypto for speed or SAIC-ACT for security

---

## Next Steps

1. Update UI screens to use `MultiFileTransmissionHandler`
2. Add file type selector to sender screen
3. Add encryption method selector UI
4. Test with various file types on different channels
5. Optimize for production (proper error handling, logging)

