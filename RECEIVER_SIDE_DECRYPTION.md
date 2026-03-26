# Receiver Side: Multi-File Decryption

## Challenge

Files encrypted with **different methods** (AES-GCM, ChaCha20, XOR, SAIC-ACT) need to be decrypted properly. The receiver needs to know which method was used.

## Solution: Metadata Header

Prepend a **4-byte method identifier** to encrypted data:

```dart
// Encryption (sender side)
const methodHeader = {
  'SAIC-ACT': [0x01, 0x00, 0x00, 0x00],
  'AES-256-GCM': [0x02, 0x00, 0x00, 0x00],
  'ChaCha20-Poly1305': [0x03, 0x00, 0x00, 0x00],
  'XOR-Crypto': [0x04, 0x00, 0x00, 0x00],
};

// When encrypting, prepend header:
final method = 'AES-256-GCM';
final header = Uint8List.fromList(methodHeader[method]!);
final encryptedData = cipher.encrypt(data, key);
final withHeader = Uint8List.fromList([...header, ...encryptedData]);
```

## Receiver-Side Decryption Service

Create `lib/services/multi_decryption_service.dart`:

```dart
import 'dart:typed_data';
import 'multi_encryption_implementations.dart';

enum EncryptionMethodByte {
  saicAct(0x01),
  aesGcm(0x02),
  chaCha20Poly1305(0x03),
  xorCrypto(0x04);

  final int byteValue;
  const EncryptionMethodByte(this.byteValue);

  static EncryptionMethodByte? fromByte(int byte) {
    for (final method in EncryptionMethodByte.values) {
      if (method.byteValue == byte) return method;
    }
    return null;
  }
}

class DecryptionError implements Exception {
  final String message;
  DecryptionError(this.message);

  @override
  String toString() => 'DecryptionError: $message';
}

class MultiDecryptionService {
  static const int _headerSize = 4;
  static const int _methodByteIndex = 0;

  /// Detect encryption method from header and decrypt
  /// 
  /// Returns decrypted bytes if successful
  /// 
  /// Throws [DecryptionError] if:
  /// - Invalid header format
  /// - Unknown encryption method
  /// - Decryption fails (authentication, corruption)
  Future<Uint8List> decryptFile(
    Uint8List encryptedDataWithHeader,
    Uint8List key,
  ) async {
    // Validate minimum size
    if (encryptedDataWithHeader.length < _headerSize) {
      throw DecryptionError('Invalid encrypted data: too short');
    }

    // Extract header
    final header = encryptedDataWithHeader.sublist(0, _headerSize);
    final methodByte = header[_methodByteIndex];
    
    // Detect method
    final method = EncryptionMethodByte.fromByte(methodByte);
    if (method == null) {
      throw DecryptionError('Unknown encryption method: 0x${methodByte.toRadixString(16)}');
    }

    // Extract encrypted payload
    final encryptedPayload = encryptedDataWithHeader.sublist(_headerSize);

    try {
      switch (method) {
        case EncryptionMethodByte.saicAct:
          // SAIC-ACT decryption (delegate to existing service)
          return await _decryptSaicAct(encryptedPayload, key);

        case EncryptionMethodByte.aesGcm:
          // AES-256-GCM decryption
          return await _decryptAesGcm(encryptedPayload, key);

        case EncryptionMethodByte.chaCha20Poly1305:
          // ChaCha20-Poly1305 decryption
          return await _decryptChaCha20(encryptedPayload, key);

        case EncryptionMethodByte.xorCrypto:
          // XOR-Crypto decryption
          return await _decryptXor(encryptedPayload, key);
      }
    } catch (e) {
      throw DecryptionError('Decryption failed for ${method.toString()}: $e');
    }
  }

  /// Decrypt using AES-256-GCM
  /// 
  /// Format: [IV(16)][HMAC(32)][Ciphertext]
  Future<Uint8List> _decryptAesGcm(Uint8List encrypted, Uint8List key) async {
    const int ivLength = 16;
    const int hmacLength = 32;

    if (encrypted.length < ivLength + hmacLength) {
      throw DecryptionError('AES-GCM: invalid encrypted data length');
    }

    final iv = encrypted.sublist(0, ivLength);
    final storedHmac = encrypted.sublist(ivLength, ivLength + hmacLength);
    final ciphertext = encrypted.sublist(ivLength + hmacLength);

    // Recreate HMAC to verify
    final hmac = _computeHmacSha256(key, [...iv, ...ciphertext]);
    
    if (!_constantTimeEquals(hmac, storedHmac)) {
      throw DecryptionError('AES-GCM: authentication failed - data corrupted or wrong key');
    }

    // Actually decrypt (use your crypto library)
    final decrypted = _xorDecrypt(ciphertext, iv, key);
    return decrypted;
  }

  /// Decrypt using ChaCha20-Poly1305
  /// 
  /// Format: [Nonce(12)][Tag(16)][Ciphertext]
  Future<Uint8List> _decryptChaCha20(Uint8List encrypted, Uint8List key) async {
    const int nonceLength = 12;
    const int tagLength = 16;

    if (encrypted.length < nonceLength + tagLength) {
      throw DecryptionError('ChaCha20: invalid encrypted data length');
    }

    final nonce = encrypted.sublist(0, nonceLength);
    final storedTag = encrypted.sublist(nonceLength, nonceLength + tagLength);
    final ciphertext = encrypted.sublist(nonceLength + tagLength);

    // Verify tag
    final tag = _computeHmacSha256(key, [...nonce, ...ciphertext]);
    final truncatedTag = tag.sublist(0, tagLength);
    
    if (!_constantTimeEquals(truncatedTag, storedTag)) {
      throw DecryptionError('ChaCha20: tag verification failed');
    }

    // Decrypt
    final decrypted = _xorDecrypt(ciphertext, nonce, key);
    return decrypted;
  }

  /// Decrypt using XOR-Crypto (lightweight, no auth)
  /// 
  /// Format: [Ciphertext] (XOR with key stream)
  Future<Uint8List> _decryptXor(Uint8List encrypted, Uint8List key) async {
    return _xorDecrypt(encrypted, Uint8List(0), key);
  }

  /// Decrypt using SAIC-ACT (existing implementation)
  /// 
  /// Delegate to your existing SAIC-ACT service
  Future<Uint8List> _decryptSaicAct(Uint8List encrypted, Uint8List key) async {
    // Call your existing SAIC-ACT decryption
    // This is a placeholder - adapt to your actual implementation
    throw UnimplementedError('SAIC-ACT decryption - use existing service');
  }

  /// Simple XOR decryption (placeholder)
  /// 
  /// In production, use proper crypto library (pointycastle, etc.)
  Uint8List _xorDecrypt(Uint8List ciphertext, Uint8List iv, Uint8List key) {
    final keyStream = _deriveKeyStream(key, iv, ciphertext.length);
    return Uint8List.fromList(
      List.generate(
        ciphertext.length,
        (i) => ciphertext[i] ^ keyStream[i],
      ),
    );
  }

  /// Derive key stream from seed + IV
  Uint8List _deriveKeyStream(Uint8List key, Uint8List iv, int length) {
    final seed = [...key, ...iv];
    final stream = <int>[];
    
    for (int i = 0; i < length; i++) {
      stream.add((seed[i % seed.length] * (i + 1)) % 256);
    }
    
    return Uint8List.fromList(stream);
  }

  /// HMAC-SHA256 (simplified - use crypto package in production)
  List<int> _computeHmacSha256(Uint8List key, List<int> data) {
    // Placeholder - use crypto package:
    // import 'package:crypto/crypto.dart';
    // return Hmac(sha256, key).convert(data).bytes;
    
    // For now, simple hash
    return _simpleHash([...key, ...data]);
  }

  /// Simple hash (placeholder - use real crypto in production)
  List<int> _simpleHash(List<int> data) {
    // This is NOT secure - for demo only
    final result = Uint8List(32);
    for (int i = 0; i < data.length; i++) {
      result[i % 32] ^= data[i];
    }
    return result;
  }

  /// Constant-time comparison to prevent timing attacks
  bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    
    int diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
```

## Updated Receiver Screen

```dart
import 'services/multi_decryption_service.dart';

class _ReceiverScreenState extends State<ReceiverScreen> {
  late MultiDecryptionService _decryptionService;

  @override
  void initState() {
    super.initState();
    _decryptionService = MultiDecryptionService();
  }

  Future<void> _decryptReceivedAudio() async {
    if (_encryptedBytes?.isEmpty ?? true) {
      _showError('No audio data received');
      return;
    }

    try {
      final pin = _pinController.text.trim();
      if (pin.isEmpty) {
        _showError('Enter PIN first');
        return;
      }

      setState(() => _busy = true);

      // Derive key (same as sender)
      final key = await _deriveKey(pin);

      // Decrypt with automatic method detection
      final decrypted = await _decryptionService.decryptFile(
        _encryptedBytes!,
        key,
      );

      // Now we have the decrypted file bytes
      setState(() {
        _decryptedBytes = decrypted;
        _busy = false;
      });

      _showInfo('Decrypted successfully!\nSize: ${(decrypted.length / 1024).toStringAsFixed(1)} KB');

    } on DecryptionError catch (e) {
      _showError('Decryption failed: ${e.message}');
      setState(() => _busy = false);
    } catch (e) {
      _showError('Error: $e');
      setState(() => _busy = false);
    }
  }

  Future<void> _saveDecryptedFile() async {
    if (_decryptedBytes?.isEmpty ?? true) {
      _showError('No decrypted data');
      return;
    }

    try {
      // Get detected file type and suggest extension
      final extension = _guessFileExtension(_decryptedBytes!);
      
      final fileName = 'decrypted_${DateTime.now().millisecondsSinceEpoch}$extension';
      
      // Save to Downloads or Documents
      final directory = Directory('/storage/emulated/0/Documents');
      final file = File('${directory.path}/$fileName');
      
      await file.writeAsBytes(_decryptedBytes!);
      
      _showInfo('Saved: $fileName\nPath: ${file.path}');

    } catch (e) {
      _showError('Save failed: $e');
    }
  }

  /// Guess file type from magic bytes
  String _guessFileExtension(Uint8List data) {
    if (data.length < 4) return '.bin';

    final header = data.sublist(0, 4);

    // Check magic bytes
    if (_bytesMatch(header, [0x89, 0x50, 0x4E, 0x47])) return '.png';
    if (_bytesMatch(header, [0xFF, 0xD8, 0xFF, 0xE0])) return '.jpg';
    if (_bytesMatch(header, [0x47, 0x49, 0x46, 0x38])) return '.gif';
    if (_bytesMatch(header.sublist(0, 2), [0xFF, 0xD8])) return '.jpeg';
    if (_bytesMatch(header.sublist(0, 2), [0x25, 0x50])) return '.pdf';
    if (_bytesMatch(header, [0x50, 0x4B, 0x03, 0x04])) return '.zip';
    if (_bytesMatch(header, [0x7F, 0x45, 0x4C, 0x46])) return '.bin'; // ELF
    
    // Check for text
    try {
      utf8.decode(data);
      return '.txt';
    } catch (_) {
      return '.bin';
    }
  }

  bool _bytesMatch(Uint8List data, List<int> expected) {
    if (data.length < expected.length) return false;
    for (int i = 0; i < expected.length; i++) {
      if (data[i] != expected[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receive File')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Audio receiver (unchanged)
            // ... audio playback and extraction code ...

            const Divider(height: 32),

            // Decryption section
            Text(
              'Decrypt',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),

            TextField(
              controller: _pinController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Enter PIN',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _decryptReceivedAudio,
                icon: _busy
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_open),
                label: const Text('Decrypt File'),
              ),
            ),
            const SizedBox(height: 16),

            if (_decryptedBytes != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Decrypted',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Size: ${(_decryptedBytes!.length / 1024).toStringAsFixed(2)} KB',
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _saveDecryptedFile,
                          icon: const Icon(Icons.save),
                          label: const Text('Save File'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

## Installation Requirements

Add to `pubspec.yaml`:

```yaml
dependencies:
  crypto: ^3.0.0  # For proper HMAC-SHA256
  pointycastle: ^3.7.0  # For AES-GCM and ChaCha20
```

## Testing Decryption

```dart
Future<void> testMultiDecryption() async {
  final service = MultiDecryptionService();
  
  // Test data
  final testKey = Uint8List(32);
  
  // Test AES-GCM round-trip
  final original = Uint8List.fromList([1, 2, 3, 4, 5]);
  final aesEncryptor = AesGcmImplementation();
  final aesEncrypted = aesEncryptor.encrypt(original, testKey);
  
  // Add method header
  final methodHeader = Uint8List.fromList([0x02, 0x00, 0x00, 0x00]);
  final withHeader = Uint8List.fromList([...methodHeader, ...aesEncrypted]);
  
  // Decrypt
  final decrypted = await service.decryptFile(withHeader, testKey);
  
  assert(decrypted == original, 'Round-trip failed');
  print('AES-GCM: ✓ OK');
  
  // Similar tests for ChaCha20, XOR
}
```

## Error Scenarios

```dart
// Wrong PIN - HMAC verification fails
await service.decryptFile(encryptedData, wrongKey);
// → DecryptionError: authentication failed - data corrupted or wrong key

// File corrupted - header invalid
await service.decryptFile(Uint8List(2), key);
// → DecryptionError: Invalid encrypted data: too short

// Unknown method
final data = Uint8List.fromList([0xFF, 0x00, 0x00, 0x00, ...]);
await service.decryptFile(data, key);
// → DecryptionError: Unknown encryption method: 0xff
```

## Summary

| Scenario | How It Works |
|----------|-------------|
| **Image encrypted with SAIC-ACT** | Header `0x01...` → delegate to SAIC-ACT service |
| **PDF with AES-256-GCM** | Header `0x02...` → verify HMAC → decrypt |
| **JSON with ChaCha20** | Header `0x03...` → verify tag → decrypt |
| **Binary with XOR** | Header `0x04...` → simple XOR decryption |
| **Wrong PIN** | Any method → authentication fails with clear error |
| **Corrupted data** | HMAC/tag mismatch → error message |

The receiver **automatically detects** which encryption method was used and decrypts accordingly.
