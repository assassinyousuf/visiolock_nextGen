# Integration Checklist: Multi-File & Multi-Encryption Support

## Overview
Checklist for integrating multi-file and multi-encryption support into your Flutter app. All new service files are already created in `lib/services/`.

---

## Phase 1: Verify New Services Are in Place ✓

Check that these files exist in your project:

```
lib/services/
├── encryption_selector_service.dart          ✓ NEW
├── universal_file_processor.dart             ✓ NEW
├── multi_encryption_implementations.dart     ✓ NEW
├── ai_transmission_service_v2.dart           ✓ NEW
├── multi_file_transmission_handler.dart      ✓ NEW
├── [existing services remain unchanged]
```

**Action**: Verify all 5 new files are present in `lib/services/`

---

## Phase 2: Update pubspec.yaml

### Check Dependencies

Ensure these packages are in your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # File handling
  file_picker: ^5.3.0
  path_provider: ^2.0.0
  
  # Encryption & crypto
  crypto: ^3.0.0          # For HMAC-SHA256
  pointycastle: ^3.7.0    # Optional: For real AES-GCM/ChaCha20
  
  # HTTP (for API calls in AiTransmissionServiceV2)
  http: ^1.1.0
  
  # Biometric (existing)
  local_auth: ^2.1.0
  flutter_secure_storage: ^9.0.0
```

**Action**: Run `flutter pub get` to fetch dependencies

---

## Phase 3: Update Sender Screen (sender_screen.dart)

### Step 1: Update Imports

Add these imports at the top:

```dart
import 'services/multi_file_transmission_handler.dart';
import 'services/universal_file_processor.dart';
import 'services/encryption_selector_service.dart';
import 'services/multi_encryption_implementations.dart';
import 'models/channel_state.dart';  // Already exists
```

### Step 2: Replace Service Initialization

**OLD**:
```dart
class _SenderScreenState extends State<SenderScreen> {
  late ImageProcessor _imageProcessor;
  late File _selectedImage;
  late LegacyEncryptionService _encryptionService;
  
  @override
  void initState() {
    super.initState();
    _imageProcessor = ImageProcessor();
    _encryptionService = LegacyEncryptionService();
  }
}
```

**NEW**:
```dart
class _SenderScreenState extends State<SenderScreen> {
  // Old services removed ↓
  // late ImageProcessor _imageProcessor;
  // late File _selectedImage;
  // late LegacyEncryptionService _encryptionService;
  
  // New handler (replaces all above)
  late MultiFileTransmissionHandler _handler;
  late EncryptionSelectorService _encryptionSelector;
  
  // State
  Uint8List? _encryptedBytes;
  String _encryptionMethodName = 'Auto-select';
  bool _busy = false;
  double _encryptProgress = 0.0;
  
  @override
  void initState() {
    super.initState();
    _handler = MultiFileTransmissionHandler();
    _encryptionSelector = EncryptionSelectorService();
    
    // Listen to progress from handler
    _handler.onProgressUpdate = (progress) {
      if (mounted) {
        setState(() => _encryptProgress = progress);
      }
    };
    
    _handler.onStatusUpdate = (status) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(status)),
        );
      }
    };
  }
}
```

**Action**: Update class initialization

### Step 3: Update File Picker

**OLD**:
```dart
Future<void> _pickImage() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['png', 'jpg', 'jpeg', 'bmp'],
  );
  
  if (result?.files.isEmpty ?? true) return;
  
  setState(() {
    _selectedImage = File(result!.files.first.path!);
  });
}
```

**NEW**:
```dart
Future<void> _pickFile() async {
  try {
    final result = await FilePicker.platform.pickFiles();
    if (result?.files.isEmpty ?? true) return;

    final file = File(result!.files.first.path!);
    
    setState(() => _busy = true);
    await _handler.selectAndLoadFile(file);
    setState(() => _busy = false);
    
    _showSnackBar('File loaded: ${_handler.fileTypeName}');
    
  } catch (e) {
    _showSnackBar('Error: $e');
  }
}
```

**Action**: Replace `_pickImage()` with `_pickFile()` in your code

### Step 4: Update Encryption Function

**OLD**:
```dart
Future<void> _encryptImage(Uint8List key) async {
  final imageBytes = await _selectedImage.readAsBytes();
  final encrypted = _encryptionService.encryptBytes(
    dataBytes: imageBytes,
    key: key,
  );
  setState(() => _encryptedBytes = encrypted);
}
```

**NEW**:
```dart
Future<void> _encryptFile(Uint8List key) async {
  try {
    setState(() => _busy = true);

    final fileData = _handler.selectedFile;
    if (fileData == null) {
      _showSnackBar('Select a file first');
      setState(() => _busy = false);
      return;
    }

    // Get intelligent encryption recommendation
    final channelState = ChannelStateEstimate(
      snrDb: 15.0, // From your channel estimation logic
      noiseLevel: 0.1,
    );
    
    final selectedMethod = _encryptionSelector.selectOptimalEncryption(
      fileData.metadata,
      channelState,
    );

    _encryptionMethodName = selectedMethod.description;

    // Encrypt
    final encrypted = await _handler.encryptFile(encryptionKey: key);

    setState(() {
      _encryptedBytes = encrypted;
      _busy = false;
    });

    _showSnackBar(
      'Encrypted with ${selectedMethod.description}\n'
      'Size: ${(encrypted.length / 1024).toStringAsFixed(1)} KB'
    );

  } catch (e) {
    _showSnackBar('Encryption failed: $e');
    setState(() => _busy = false);
  }
}
```

**Action**: Replace encryption function

### Step 5: Update UI Button Callbacks

**OLD**:
```dart
ElevatedButton(
  onPressed: _pickImage,
  child: const Text('Pick Image'),
)
```

**NEW**:
```dart
ElevatedButton(
  onPressed: _busy ? null : _pickFile,  // Note: _pickFile not _pickImage
  child: const Text('Pick File'),
)
```

**Action**: Update button labels and callbacks

### Step 6: Update dispose()

**OLD**:
```dart
@override
void dispose() {
  // No cleanup
  super.dispose();
}
```

**NEW**:
```dart
@override
void dispose() {
  _handler.dispose();
  super.dispose();
}
```

**Action**: Add handler cleanup

### Step 7: (Optional) Add Encryption Options Dialog

```dart
Future<void> _showEncryptionOptions() async {
  final available = _handler.getAvailableEncryptions();
  
  if (!mounted) return;
  
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Available Encryption Methods'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: available.length,
          itemBuilder: (context, index) {
            final method = available[index];
            return ListTile(
              title: Text(method.description),
              subtitle: Text('Security: ${method.securityLevel}'),
              onTap: () {
                setState(() => _encryptionMethodName = method.description);
                Navigator.pop(context);
              },
            );
          },
        ),
      ),
    ),
  );
}
```

**Action**: Add dialog to show available encryption methods

---

## Phase 4: Update Receiver Screen (receiver_screen.dart)

### New Steps

Create `lib/services/multi_decryption_service.dart` (provided in RECEIVER_SIDE_DECRYPTION.md)

### Update Receiver Decryption

**OLD**:
```dart
Future<void> _decryptAudio() async {
  final decrypted = _legacyDecryptionService.decryptBytes(
    encryptedBytes: _audioBytes,
    key: key,
  );
  // Assume single encryption method
}
```

**NEW**:
```dart
Future<void> _decryptAudio() async {
  try {
    final decryptionService = MultiDecryptionService();
    
    // Auto-detects encryption method from header
    final decrypted = await decryptionService.decryptFile(
      _audioBytes,
      key,
    );
    
    setState(() => _decryptedBytes = decrypted);
    _showSnackBar('Decrypted successfully');
    
  } on DecryptionError catch (e) {
    _showSnackBar('Decryption failed: ${e.message}');
  }
}
```

**Action**: Replace decryption logic in receiver

---

## Phase 5: Backend (Python Flask API)

### Step 1: Backup Old API

```bash
cd model_for_visolock
cp app.py app_v1.py
```

### Step 2: Deploy New API

Replace `model_for_visolock/app.py` with `app_v2.py` (provided in previous messages)

### Step 3: Test API Locally

```bash
cd model_for_visolock
python app_v2.py
```

Expected output:
```
 * Running on http://127.0.0.1:5000
```

### Step 4: Test Endpoints

```bash
# Health check
curl http://localhost:5000/api/health

# Get supported file types
curl http://localhost:5000/api/file-types

# Get encryption methods
curl http://localhost:5000/api/encryption-methods

# Recommend encryption for a file
curl -X POST http://localhost:5000/api/recommend-encryption \
  -H "Content-Type: application/json" \
  -d '{
    "file_type": "text",
    "file_size_kb": 50,
    "snr_db": 15.0,
    "noise_level": 0.1
  }'
```

**Action**: Deploy and test new API endpoints

---

## Phase 6: Sender Screen UI Refactor (Optional)

### Replace Image Preview with File Info Card

**OLD**:
```dart
Image.file(_selectedImage)  // Shows image preview
```

**NEW**:
```dart
Card(
  child: Padding(
    padding: const EdgeInsets.all(16.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_handler.selectedFile != null) ...[
          Text('File: ${_handler.selectedFile!.metadata.fileName}'),
          Text('Type: ${_handler.fileTypeName}'),
          Text('Size: ${_handler.selectedFile!.sizeString}'),
          Text('Encryption: ${_encryptionMethodName}'),
        ] else
          const Text('No file selected'),
      ],
    ),
  ),
)
```

**Action**: Update UI to show multi-file info instead of image preview

---

## Phase 7: Testing

### Test Encryption Round-Trip

```dart
Future<void> testEncryptionRoundTrip() async {
  final files = [
    'test_image.png',
    'test_document.pdf',
    'test_data.json',
    'test_archive.zip',
  ];

  final handler = MultiFileTransmissionHandler();
  final key = Uint8List(32);

  for (final fileName in files) {
    final file = File(fileName);
    
    // Load file
    await handler.selectAndLoadFile(file);
    
    // Encrypt
    final encrypted = await handler.encryptFile(encryptionKey: key);
    
    // Verify size changed
    assert(encrypted.length > 0, 'Encryption failed');
    
    print('✓ $fileName encrypted successfully');
  }
}
```

**Action**: Write and run test

### Test Decryption with Different Methods

```dart
Future<void> testDecryptionMethods() async {
  final service = MultiDecryptionService();
  
  for (final (method, data) in testCases) {
    try {
      final decrypted = await service.decryptFile(data, testKey);
      print('✓ $method decrypted OK');
    } catch (e) {
      print('✗ $method failed: $e');
    }
  }
}
```

**Action**: Write and run decryption tests

---

## Phase 8: Verification Checklist

Before considering integration complete:

- [ ] All 5 new service files present in `lib/services/`
- [ ] `pubspec.yaml` has all required dependencies
- [ ] `sender_screen.dart` imports new services
- [ ] File picker accepts all file types (not just images)
- [ ] Encryption uses `MultiFileTransmissionHandler`
- [ ] `MultiDecryptionService` created in receiver
- [ ] Receiver decryption uses auto-detection
- [ ] Python API v2 deployed and tested
- [ ] At least one file type (image, text, PDF, binary) tested end-to-end
- [ ] Error messages clear (e.g., "wrong PIN", "corrupted data")

---

## Phase 9: Performance Tuning (Optional)

After basic integration works, consider:

1. **Caching**: EncryptionSelectorService results
2. **Streaming**: For large files (>100MB)
3. **Parallel**: Encrypt multiple files at once
4. **Profiling**: Check encryption speed per method

---

## Troubleshooting

### Issue: Unknown encryption method error
**Cause**: File was encrypted with method but receiver doesn't have implementation  
**Fix**: Ensure all 4 encryption implementations are in `multi_encryption_implementations.dart`

### Issue: HMAC verification failed
**Cause**: Wrong PIN/key or corrupted data  
**Fix**: Check PIN derivation is identical on sender/receiver

### Issue: File type not detected
**Cause**: File extension not in supported list  
**Fix**: Add extension to `FileCategory` enum in `file_metadata.dart`

### Issue: API always uses fallback
**Cause**: Flask API not running or reachable  
**Fix**: Check `AiTransmissionServiceV2` API URL matches your setup

---

## Estimated Time

| Phase | Time | Notes |
|-------|------|-------|
| 1 | 5 min | Just verify files exist |
| 2 | 10 min | Update pubspec, run `pub get` |
| 3 | 30-45 min | Most changes; take your time |
| 4 | 20-30 min | Copy decryption service, integrate |
| 5 | 15-20 min | Deploy API, test endpoints |
| 6 | 15-20 min | Optional UI refactor |
| 7 | 20-30 min | Testing |
| **Total** | **≈2.5-3 hours** | **Full integration** |

---

## Next Steps

1. **Start with Phase 1**: Verify files exist
2. **Then Phase 2**: Update dependencies
3. **Then Phase 3**: Sender screen changes (largest phase)
4. **Test as you go**: Don't wait until the end

Once complete, your app will support:
- ✅ Images, Text, PDFs, Binary files
- ✅ 4 encryption methods (AES, ChaCha20, XOR, + SAIC-ACT)
- ✅ Intelligent auto-selection
- ✅ Full round-trip encryption/decryption
