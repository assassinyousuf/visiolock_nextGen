# Quick Start: Adding Multi-File Support to Sender Screen

## Minimal Changes to Existing Code

### Step 1: Update file picker to accept all types

**Old Code:**
```dart
final result = await FilePicker.platform.pickFiles(
  type: FileType.custom,
  allowedExtensions: const ['png', 'jpg', 'jpeg', 'bmp', 'webp'],
);
```

**New Code:**
```dart
final result = await FilePicker.platform.pickFiles(
  type: FileType.any, // Accept any file
  // OR custom with all types:
  // allowedExtensions: const [
  //   'png', 'jpg', 'jpeg', 'bmp', 'webp', 'gif',  // Images
  //   'txt', 'json', 'xml', 'csv', 'md', 'dart', 'js',  // Text
  //   'pdf',  // Documents
  //   'zip', 'tar', 'gz', 'exe', 'dll',  // Binary
  // ],
);
```

---

### Step 2: Use UniversalFileProcessor instead of ImageProcessor

**Old Code:**
```dart
final _imageProcessor = ImageProcessor();

final payload = await _imageProcessor.convertImageToBinary(imageFile);
```

**New Code:**
```dart
final _fileProcessor = UniversalFileProcessor();

final fileData = await _fileProcessor.loadFile(file);

// fileData now contains:
// - fileData.rawBytes: file content
// - fileData.metadata.category: FileCategory enum
// - fileData.metadata.fileName: name
// - fileData.metadata.mimeType: MIME type
// - fileData.fileSizeKb: size in KB
```

---

### Step 3: Select encryption method before encrypting

**Old Code:**
```dart
final encrypted = _encryptionService.encryptBytes(
  dataBytes: payload.payloadBytes,
  key: key,
);
```

**New Code:**
```dart
import 'services/encryption_selector_service.dart';
import 'services/multi_encryption_implementations.dart';
import 'models/channel_state.dart';

// Get optimal encryption for file type
final encryptionSelector = EncryptionSelectorService();
final channel = ChannelStateEstimate(snrDb: 15.0, noiseLevel: 0.1);
final optimalConfig = encryptionSelector.selectOptimalEncryption(
  fileData.metadata,
  channel,
);

// Or use AI service for smart selection
final aiService = AiTransmissionServiceV2();
final config = await aiService.getOptimalConfiguration(
  fileData: fileData,
  channelState: channel,
);

// Encrypt with selected method
final methodName = config.recommendedEncryption.toString().split('.').last;
final encryptor = EncryptionFactory.create(_encryptionMethodToString(methodName));

try {
  final encrypted = encryptor.encrypt(fileData.rawBytes, key);
  // Use encrypted bytes
} catch (e) {
  print('Encryption failed: $e');
  // Handle authentication failure or tampering
}
```

---

### Step 4: Helper function to convert enum to string

```dart
String _encryptionMethodToString(EncryptionMethod method) {
  switch (method) {
    case EncryptionMethod.saicAct:
      return 'SAIC-ACT';
    case EncryptionMethod.aesGcm:
      return 'AES-256-GCM';
    case EncryptionMethod.chaCha20:
      return 'ChaCha20-Poly1305';
    case EncryptionMethod.xorCrypto:
      return 'XOR-Crypto';
    case EncryptionMethod.hybridMode:
      return 'Hybrid';
  }
}
```

---

## Complete Updated Sender Screen Function

```dart
import 'services/multi_file_transmission_handler.dart';

class _SenderScreenState extends State<SenderScreen> {
  // Replace old services with handler
  late MultiFileTransmissionHandler _handler = MultiFileTransmissionHandler();

  @override
  void initState() {
    super.initState();
    _handler.onStatusUpdate = (status) {
      if (mounted) {
        _showSnackBar(status);
      }
    };
    _handler.onProgressUpdate = (progress) {
      if (mounted) {
        setState(() {
          // Update UI with progress
        });
      }
    };
  }

  Future<void> _pickAndEncryptFile() async {
    await PermissionService.requestImagePickerPermissions();
    
    // Pick any file
    final result = await FilePicker.platform.pickFiles();
    if (result?.files.isEmpty ?? true) return;

    final file = File(result!.files.first.path!);

    try {
      // Load file
      await _handler.selectAndLoadFile(file);

      // Show file type
      _showSnackBar('File type: ${_handler.fileTypeName}');

      // Get encryption options
      final options = await _handler.getEncryptionOptions();
      
      // Show recommendations to user (in real app, show dialog)
      for (final option in options) {
        print('${option.method}: ${option.reason}');
      }

      // Auto-select or let user choose
      _handler.setEncryptionMethod(options.first.method);

      // Get PIN/key
      final pin = _pinController.text;
      if (pin.trim().isEmpty) {
        _showSnackBar('Enter PIN first');
        return;
      }

      // Derive key
      final Uint8List key;
      if (_crossDevice) {
        key = _passphraseKeyService.deriveKey(pin);
      } else {
        final authed = await _biometricAuth.authenticate(
          reason: 'Authenticate to encrypt ${file.name}',
        );
        if (!authed) return;
        
        final biometricKey = await _biometricKeyService.getOrCreateBiometricKey();
        key = _combinedKeyService.deriveCombinedKey(
          biometricKey: biometricKey,
          pin: pin,
        );
      }

      // Encrypt with selected method
      setState(() => _busy = true);
      final encrypted = await _handler.encryptFile(encryptionKey: key);

      _showSnackBar(
        'Encrypted with ${_handler.selectedEncryptionName}\n'
        'Original: ${_handler.selectedFile!.sizeString} → '
        'Encrypted: ${(encrypted.length / 1024).toStringAsFixed(1)} KB'
      );

      setState(() {
        _encryptedBytes = encrypted;
        _busy = false;
      });

    } catch (e) {
      _showSnackBar('Error: $e');
      setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _handler.dispose();
    super.dispose();
  }
}
```

---

## Integration with Audio Encoding

After encryption, the audio encoding step remains the same:

```dart
Future<void> _convertToAudio() async {
  final encryptedBytes = _encryptedBytes;
  if (encryptedBytes == null) {
    _showSnackBar('Encrypt the file first');
    return;
  }

  setState(() => _busy = true);
  try {
    // Protection and audio encoding (unchanged)
    final protectedBytes = _nrsts.protectEncryptedBytes(encryptedBytes);
    final packet = await _audioEncoder.encodeBytesToAudioFile(protectedBytes);

    setState(() {
      _audioPacket = packet;
      _busy = false;
    });
    
    _showSnackBar(
      'Converted to audio\n'
      'Audio: ${packet.audioData.length} samples'
    );

  } catch (e) {
    _showSnackBar('Audio conversion failed: $e');
    setState(() => _busy = false);
  }
}
```

---

## UI: Display File Type and Encryption

```dart
Card(
  child: ListTile(
    title: Text(_handler.selectedFile?.metadata.fileName ?? 'No file selected'),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Type: ${_handler.fileTypeName}'),
        Text('Size: ${_handler.selectedFile?.sizeString ?? "N/A"}'),
        Text('Encryption: ${_handler.selectedEncryptionName}'),
      ],
    ),
    leading: Icon(_getFileIcon(_handler.fileTypeName)),
  ),
)

IconData _getFileIcon(String type) {
  switch (type) {
    case 'image':
      return Icons.image;
    case 'text':
      return Icons.text_fields;
    case 'structured':
      return Icons.description;
    case 'binary':
      return Icons.binary;
    default:
      return Icons.file_copy;
  }
}
```

---

## Testing Different File Types

```dart
// Test with different files
final testFiles = [
  'image.png',      // Uses SAIC-ACT crypto
  'document.pdf',   // Uses AES-256-GCM
  'data.json',      // Uses AES-256-GCM + compression
  'archive.zip',    // Uses ChaCha20-Poly1305
];

for (final fileName in testFiles) {
  final file = File('/path/to/$fileName');
  await _handler.selectAndLoadFile(file);
  
  print('File: $fileName');
  print('Type: ${_handler.fileTypeName}');
  print('Encryption: ${_handler.selectedEncryptionName}');
  
  // Verify available methods
  final available = _handler.getAvailableEncryptions();
  print('Available: ${available.map((e) => e.description).join(', ')}');
}
```

---

## Error Handling

```dart
try {
  await _handler.selectAndLoadFile(file);
  await _handler.configureTransmission();
  await _handler.encryptFile(encryptionKey: key);
} on FileSystemException catch (e) {
  _showSnackBar('File error: ${e.message}');
} on TransmissionConfigException catch (e) {
  _showSnackBar('Configuration error: ${e.message}');
} on Exception catch (e) {
  _showSnackBar('Error: $e');
}
```

---

## Summary of Changes

| Old | New |
|-----|-----|
| `ImageProcessor` | `UniversalFileProcessor` |
| Image files only | All file types |
| Single encryption method | Multiple methods with selection |
| No file type awareness | Automatic file type detection |
| No API integration | Connects to AI service |
| Manual configuration | Intelligent auto-configuration |

That's it! With these minimal changes, you've upgraded from image-only to full multi-file, multi-encryption support.

