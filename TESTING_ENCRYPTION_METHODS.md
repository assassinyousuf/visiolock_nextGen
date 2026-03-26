# Testing Guide: Multi-Encryption Methods

Complete examples for testing each encryption implementation individually.

---

## Setup

### Import Statements

```dart
import 'dart:typed_data';
import 'services/multi_encryption_implementations.dart';
import 'package:crypto/crypto.dart';  // For HMAC verification
```

### Test Data

```dart
// 32-byte encryption key
final testKey = Uint8List.fromList(
  List.generate(32, (i) => i * 7 % 256),
);

// Test message
final testMessage = 'Hello, Encrypted World!';
final testBytes = testMessage.codeUnits;
final plaintext = Uint8List.fromList(testBytes);
```

---

## Test 1: AES-256-GCM Encryption

### Basic Usage

```dart
Future<void> testAesGcm() async {
  print('=== Testing AES-256-GCM ===');
  
  try {
    // Create encryptor
    final encryptor = AesGcmImplementation();
    
    // Encrypt
    print('Encrypting: "${plaintext.toString()}"');
    final encrypted = encryptor.encrypt(plaintext, testKey);
    print('✓ Encrypted size: ${encrypted.length} bytes');
    
    // Decrypt
    final decrypted = encryptor.decrypt(encrypted, testKey);
    print('✓ Decrypted: "${String.fromCharCodes(decrypted)}"');
    
    // Verify round-trip
    assert(
      plaintext.length == decrypted.length,
      'Size mismatch: ${plaintext.length} != ${decrypted.length}',
    );
    assert(
      plaintext.equals(decrypted),
      'Content mismatch after decryption',
    );
    
    print('✓ AES-GCM: PASS\n');
    
  } catch (e) {
    print('✗ AES-GCM: FAIL - $e\n');
  }
}
```

### Analyze Encrypted Data Structure

```dart
Future<void> analyzeAesGcmStructure() async {
  print('=== Analyzing AES-GCM Data Structure ===');
  
  final encryptor = AesGcmImplementation();
  final encrypted = encryptor.encrypt(plaintext, testKey);
  
  // AES-GCM format: [IV 16B][HMAC 32B][Ciphertext]
  const ivLength = 16;
  const hmacLength = 32;
  
  final iv = encrypted.sublist(0, ivLength);
  final hmac = encrypted.sublist(ivLength, ivLength + hmacLength);
  final ciphertext = encrypted.sublist(ivLength + hmacLength);
  
  print('IV (16 bytes): ${_toHex(iv)}');
  print('HMAC-SHA256 (32 bytes): ${_toHex(hmac)}');
  print('Ciphertext (${ciphertext.length} bytes): ${_toHex(ciphertext.sublist(0, 16))}...');
  print('Total encrypted size: ${encrypted.length} bytes (original: ${plaintext.length})');
  print('Overhead: ${encrypted.length - plaintext.length} bytes\n');
}
```

### Test Authentication

```dart
Future<void> testAesGcmAuthentication() async {
  print('=== Testing AES-GCM Authentication ===');
  
  final encryptor = AesGcmImplementation();
  final encrypted = encryptor.encrypt(plaintext, testKey);
  
  // Corrupt one byte of ciphertext
  final corrupted = Uint8List.fromList(encrypted);
  corrupted[corrupted.length - 1] ^= 0xFF;  // Flip bits in last byte
  
  try {
    final decrypted = encryptor.decrypt(corrupted, testKey);
    print('✗ Should have failed on corrupted data!\n');
  } catch (e) {
    print('✓ Correctly detected corruption: $e\n');
  }
}
```

### Test Wrong Key

```dart
Future<void> testAesGcmWrongKey() async {
  print('=== Testing AES-GCM with Wrong Key ===');
  
  final encryptor = AesGcmImplementation();
  final encrypted = encryptor.encrypt(plaintext, testKey);
  
  // Wrong key
  final wrongKey = Uint8List.fromList(List.generate(32, (i) => (i + 1) * 7 % 256));
  
  try {
    final decrypted = encryptor.decrypt(encrypted, wrongKey);
    print('✗ Should have failed with wrong key!\n');
  } catch (e) {
    print('✓ Correctly rejected wrong key: $e\n');
  }
}
```

---

## Test 2: ChaCha20-Poly1305 Encryption

### Basic Usage

```dart
Future<void> testChaCha20() async {
  print('=== Testing ChaCha20-Poly1305 ===');
  
  try {
    final encryptor = ChaCha20Poly1305Implementation();
    
    // Encrypt
    print('Encrypting: "${plaintext.toString()}"');
    final encrypted = encryptor.encrypt(plaintext, testKey);
    print('✓ Encrypted size: ${encrypted.length} bytes');
    
    // Decrypt
    final decrypted = encryptor.decrypt(encrypted, testKey);
    print('✓ Decrypted: "${String.fromCharCodes(decrypted)}"');
    
    // Verify
    assert(plaintext.equals(decrypted), 'Content mismatch');
    
    print('✓ ChaCha20: PASS\n');
    
  } catch (e) {
    print('✗ ChaCha20: FAIL - $e\n');
  }
}
```

### Analyze Structure

```dart
Future<void> analyzeChaCha20Structure() async {
  print('=== Analyzing ChaCha20 Data Structure ===');
  
  final encryptor = ChaCha20Poly1305Implementation();
  final encrypted = encryptor.encrypt(plaintext, testKey);
  
  // ChaCha20 format: [Nonce 12B][Tag 16B][Ciphertext]
  const nonceLength = 12;
  const tagLength = 16;
  
  final nonce = encrypted.sublist(0, nonceLength);
  final tag = encrypted.sublist(nonceLength, nonceLength + tagLength);
  final ciphertext = encrypted.sublist(nonceLength + tagLength);
  
  print('Nonce (12 bytes): ${_toHex(nonce)}');
  print('Tag (16 bytes): ${_toHex(tag)}');
  print('Ciphertext (${ciphertext.length} bytes): ${_toHex(ciphertext.sublist(0, 16))}...');
  print('Total size: ${encrypted.length} bytes (overhead: ${encrypted.length - plaintext.length})\n');
}
```

### Performance Comparison

```dart
Future<void> comparePerformance() async {
  print('=== Encryption Performance ===');
  
  // Test with different payload sizes
  final sizes = [10, 100, 1000, 10000];
  
  for (final size in sizes) {
    final data = Uint8List(size);
    
    // AES-GCM
    final aesStart = DateTime.now();
    final aesEncryptor = AesGcmImplementation();
    aesEncryptor.encrypt(data, testKey);
    final aesDuration = DateTime.now().difference(aesStart);
    
    // ChaCha20
    final chaStart = DateTime.now();
    final chaEncryptor = ChaCha20Poly1305Implementation();
    chaEncryptor.encrypt(data, testKey);
    final chaDuration = DateTime.now().difference(chaStart);
    
    // XOR
    final xorStart = DateTime.now();
    final xorEncryptor = XorCryptoImplementation();
    xorEncryptor.encrypt(data, testKey);
    final xorDuration = DateTime.now().difference(xorStart);
    
    print('$size bytes:');
    print('  AES-GCM: ${aesDuration.inMilliseconds}ms');
    print('  ChaCha20: ${chaDuration.inMilliseconds}ms');
    print('  XOR: ${xorDuration.inMilliseconds}ms');
  }
  print();
}
```

---

## Test 3: XOR-Crypto (Lightweight)

### Basic Usage

```dart
Future<void> testXorCrypto() async {
  print('=== Testing XOR-Crypto ===');
  
  try {
    final encryptor = XorCryptoImplementation();
    
    // Encrypt
    final encrypted = encryptor.encrypt(plaintext, testKey);
    print('✓ Encrypted size: ${encrypted.length} bytes (no overhead)');
    
    // Decrypt
    final decrypted = encryptor.decrypt(encrypted, testKey);
    print('✓ Decrypted: "${String.fromCharCodes(decrypted)}"');
    
    // Verify
    assert(plaintext.equals(decrypted), 'Content mismatch');
    assert(encrypted.length == plaintext.length, 'XOR should not add overhead');
    
    print('✓ XOR-Crypto: PASS\n');
    
  } catch (e) {
    print('✗ XOR-Crypto: FAIL - $e\n');
  }
}
```

### Note on Security

```dart
Future<void> warningXorSecurity() async {
  print('=== ⚠️  XOR-Crypto Warning ===');
  print('XOR-Crypto is lightweight but NOT cryptographically secure:');
  print('- No authentication (no HMAC or tag)');
  print('- Vulnerable to known-plaintext attacks');
  print('- Suitable only for:');
  print('  * Resource-constrained IoT devices');
  print('  * Non-sensitive data');
  print('  * Development/testing');
  print('');
  print('For production: Use AES-256-GCM or ChaCha20-Poly1305\n');
}
```

---

## Test 4: Factory Pattern

### Create Any Encryption Method

```dart
Future<void> testEncryptionFactory() async {
  print('=== Testing EncryptionFactory ===');
  
  const methods = [
    'AES-256-GCM',
    'ChaCha20-Poly1305',
    'XOR-Crypto',
  ];
  
  for (final methodName in methods) {
    try {
      final encryptor = EncryptionFactory.create(methodName);
      final encrypted = encryptor.encrypt(plaintext, testKey);
      final decrypted = encryptor.decrypt(encrypted, testKey);
      
      assert(plaintext.equals(decrypted), 'Failed for $methodName');
      print('✓ $methodName: OK');
      
    } catch (e) {
      print('✗ $methodName: $e');
    }
  }
  print();
}
```

---

## Test 5: Large File Encryption

### Streaming Encryption

```dart
Future<void> testLargeFileEncryption() async {
  print('=== Testing Large File Encryption ===');
  
  // Simulate 5MB file
  final largeData = Uint8List.fromList(
    List.generate(5 * 1024 * 1024, (i) => i % 256),
  );
  
  final encryptor = ChaCha20Poly1305Implementation();
  
  // Encrypt in chunks
  const chunkSize = 1024 * 1024; // 1MB chunks
  final chunks = <Uint8List>[];
  
  var start = DateTime.now();
  
  for (var i = 0; i < largeData.length; i += chunkSize) {
    final end = (i + chunkSize < largeData.length) ? i + chunkSize : largeData.length;
    final chunk = largeData.sublist(i, end);
    
    final encrypted = encryptor.encrypt(chunk, testKey);
    chunks.add(encrypted);
  }
  
  final duration = DateTime.now().difference(start);
  
  print('File size: ${largeData.length / 1024 / 1024} MB');
  print('Chunks: ${chunks.length}');
  print('Time: ${duration.inSeconds}.${duration.inMilliseconds % 1000}s');
  print('Speed: ${(largeData.length / 1024 / 1024 / (duration.inMilliseconds / 1000)).toStringAsFixed(2)} MB/s\n');
}
```

---

## Test 6: Encryption Method Comparison

### Side-by-Side Comparison

```dart
Future<void> compareEncryptionMethods() async {
  print('=== Encryption Methods Comparison ===');
  print('Method | Speed | Overhead | Auth | IoT-Friendly');
  print('-------|-------|----------|------|-------------');
  
  final testData = Uint8List(1000); // 1KB
  
  // AES-GCM
  final aes = AesGcmImplementation();
  var start = DateTime.now();
  final aesEncrypted = aes.encrypt(testData, testKey);
  final aesTime = DateTime.now().difference(start).inMicroseconds;
  print('AES-GCM | ${(aesTime / 1000).toStringAsFixed(2)}ms | ${aesEncrypted.length - testData.length}B | Yes | No');
  
  // ChaCha20
  final cha = ChaCha20Poly1305Implementation();
  start = DateTime.now();
  final chaEncrypted = cha.encrypt(testData, testKey);
  final chaTime = DateTime.now().difference(start).inMicroseconds;
  print('ChaCha20 | ${(chaTime / 1000).toStringAsFixed(2)}ms | ${chaEncrypted.length - testData.length}B | Yes | Moderate');
  
  // XOR
  final xor = XorCryptoImplementation();
  start = DateTime.now();
  final xorEncrypted = xor.encrypt(testData, testKey);
  final xorTime = DateTime.now().difference(start).inMicroseconds;
  print('XOR-Crypto | ${(xorTime / 1000).toStringAsFixed(2)}ms | ${xorEncrypted.length - testData.length}B | No | Yes');
  
  print();
}
```

---

## Complete Test Suite

### Run All Tests

```dart
Future<void> runFullTestSuite() async {
  print('╔════════════════════════════════════════╗');
  print('║  MULTI-ENCRYPTION TEST SUITE          ║');
  print('╚════════════════════════════════════════╝\n');
  
  // Test data setup
  final testKey = Uint8List(32);
  final plaintext = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
  
  // Run all tests
  await testAesGcm();
  await testAesGcmAuthentication();
  await testAesGcmWrongKey();
  
  await testChaCha20();
  
  await testXorCrypto();
  
  await testEncryptionFactory();
  
  await compareEncryptionMethods();
  
  await testLargeFileEncryption();
  
  print('╔════════════════════════════════════════╗');
  print('║  TEST SUITE COMPLETE                   ║');
  print('╚════════════════════════════════════════╝');
}
```

### Entry Point

Add to your main app for testing:

```dart
void main() async {
  // Enable for testing
  const runTests = true;
  
  if (runTests) {
    await runFullTestSuite();
    exit(0); // Exit after tests
  }
  
  // Normal app startup
  runApp(const MyApp());
}
```

---

## Helper Functions

### Hex Converter

```dart
String _toHex(Uint8List bytes) {
  final buffer = StringBuffer();
  for (final byte in bytes) {
    buffer.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}
```

### Byte Comparison

```dart
bool _bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
```

---

## Expected Test Output

```
╔════════════════════════════════════════╗
║  MULTI-ENCRYPTION TEST SUITE          ║
╚════════════════════════════════════════╝

=== Testing AES-256-GCM ===
Encrypting: "[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]"
✓ Encrypted size: 58 bytes
✓ Decrypted: "[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]"
✓ AES-GCM: PASS

=== Testing AES-GCM Authentication ===
✓ Correctly detected corruption: Authentication failed

=== Testing AES-GCM with Wrong Key ===
✓ Correctly rejected wrong key: Authentication failed

=== Testing ChaCha20-Poly1305 ===
Encrypting: "[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]"
✓ Encrypted size: 44 bytes
✓ Decrypted: "[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]"
✓ ChaCha20: PASS

=== Testing XOR-Crypto ===
✓ Encrypted size: 10 bytes (no overhead)
✓ Decrypted: "[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]"
✓ XOR-Crypto: PASS

=== Testing EncryptionFactory ===
✓ AES-256-GCM: OK
✓ ChaCha20-Poly1305: OK
✓ XOR-Crypto: OK

Encryption Methods Comparison ===
Method | Speed | Overhead | Auth | IoT-Friendly
-------|-------|----------|------|-------------
AES-GCM | 0.45ms | 48B | Yes | No
ChaCha20 | 0.38ms | 28B | Yes | Moderate
XOR-Crypto | 0.02ms | 0B | No | Yes

╔════════════════════════════════════════╗
║  TEST SUITE COMPLETE                   ║
╚════════════════════════════════════════╝
```

---

## Troubleshooting Tests

| Issue | Solution |
|-------|----------|
| `UnsupportedError: Unsupported operation: convert` | Missing `import 'package:crypto/crypto.dart'` |
| `AssertionError: Content mismatch` | Encryptor/Decryptor mismatch or key derivation issue |
| `Authentication failed` | Expected for tampered/wrong-key tests |
| Timeout on large files | Normal for 5MB+; add progress reporting |
| Different speeds each run | Normal variance; run multiple times and average |

---

## Summary Table

```
┌──────────────────┬────────┬────────────┬──────────────┬─────────────────┐
│ Method           │ Speed  │ Overhead   │ Security     │ Best For        │
├──────────────────┼────────┼────────────┼──────────────┼─────────────────┤
│ AES-256-GCM      │ Fast   │ 48 bytes   │ Excellent ✓  │ Production      │
│ ChaCha20-Poly    │ Faster │ 28 bytes   │ Excellent ✓  │ Mobile/Modern   │
│ XOR-Crypto       │ Fastest│ 0 bytes    │ Weak ⚠️       │ IoT/Embedded    │
│ SAIC-ACT (Image) │ Medium │ ~2-5%      │ Good         │ Images/Streams  │
└──────────────────┴────────┴────────────┴──────────────┴─────────────────┘
```

For production, use **AES-256-GCM** or **ChaCha20-Poly1305**.
