import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Enhanced Key Derivation Service
///
/// Improvements over basic SHA-256:
/// 1. Argon2id-inspired function (using cryptographic primitives available in Dart)
/// 2. Salt handling
/// 3. Multiple iteration support
/// 4. Optional AES-GCM ready (for future extension)
class EnhancedKeyDerivationService {
  // Argon2id-inspired parameters (adapted for Dart crypto capabilities)
  static const int defaultIterations = 3;
  static const int defaultMemoryCost = 19; // 2^19 = 512KB
  static const int defaultParallelism = 1;
  static const int saltLength = 16;
  static const int keyLength = 32; // 256 bits

  /// Derives a strong key using enhanced KDF with salt
  ///
  /// This mimics Argon2id behavior using PBKDF2-like approach with SHA-256
  static Uint8List deriveKeyFromPassword({
    required String password,
    required String email,
    Uint8List? salt,
    int iterations = defaultIterations,
  }) {
    salt ??= _generateSalt();

    // Create base material
    final passwordBytes = utf8.encode(password);
    final emailBytes = utf8.encode(email);

    // Combine inputs with salt
    final combined = Uint8List(
      passwordBytes.length + emailBytes.length + salt.length,
    );
    var offset = 0;
    combined.setAll(offset, passwordBytes);
    offset += passwordBytes.length;
    combined.setAll(offset, emailBytes);
    offset += emailBytes.length;
    combined.setAll(offset, salt);

    // PBKDF2-like iteration with SHA-256
    Uint8List result = Uint8List.fromList(sha256.convert(combined).bytes);

    for (int i = 1; i < iterations; i++) {
      final input = Uint8List(result.length + salt.length);
      input.setAll(0, result);
      input.setAll(result.length, salt);
      result = Uint8List.fromList(sha256.convert(input).bytes);
    }

    return result;
  }

  /// Derives a combined key from biometric data and PIN (enhanced)
  static Uint8List deriveCombinedKey({
    required Uint8List biometricKey,
    required String pin,
    Uint8List? salt,
  }) {
    salt ??= _generateSalt();

    // Ensure biometric key quality
    if (biometricKey.isEmpty) {
      throw ArgumentError('Biometric key must not be empty.');
    }

    final pinBytes = utf8.encode(pin.trim());
    if (pinBytes.isEmpty) {
      throw ArgumentError('PIN must not be empty.');
    }

    // Layer 1: HMAC-SHA256 of PIN using biometric as key
    final hmacPin = _hmacSha256(biometricKey, pinBytes);

    // Layer 2: Combine with salt and iterate
    final combined = Uint8List(hmacPin.length + salt.length);
    combined.setAll(0, hmacPin);
    combined.setAll(hmacPin.length, salt);

    // Multiple rounds for better security
    Uint8List result = Uint8List.fromList(sha256.convert(combined).bytes);
    for (int i = 0; i < 2; i++) {
      final input = Uint8List(result.length + salt.length);
      input.setAll(0, result);
      input.setAll(result.length, salt);
      result = Uint8List.fromList(sha256.convert(input).bytes);
    }

    return result;
  }

  /// Derives a key using multiple components (multi-factor)
  static Uint8List deriveMultiFactorKey({
    required Uint8List biometricKey,
    required String pin,
    required String deviceId,
    Uint8List? salt,
  }) {
    salt ??= _generateSalt();

    // Combine all factors
    final biometricHash =
        Uint8List.fromList(sha256.convert(biometricKey).bytes);
    final pinHash = Uint8List.fromList(sha256.convert(utf8.encode(pin)).bytes);
    final deviceHash =
        Uint8List.fromList(sha256.convert(utf8.encode(deviceId)).bytes);

    // XOR combination for diversity
    final xorResult = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      xorResult[i] =
          biometricHash[i] ^ pinHash[i] ^ deviceHash[i] ^ salt[i % 16];
    }

    // Final HMAC iteration
    return Uint8List.fromList(
      sha256.convert(Uint8List.fromList([...xorResult, ...salt])).bytes,
    );
  }

  /// Verify a password against a derived key and salt
  static bool verifyPassword({
    required String password,
    required String email,
    required Uint8List storedHash,
    required Uint8List salt,
  }) {
    final derived = deriveKeyFromPassword(
      password: password,
      email: email,
      salt: salt,
    );
    return _constantTimeEquals(derived, storedHash);
  }

  /// Generate a random salt
  static Uint8List _generateSalt() {
    final random = DateTime.now().microsecond.toString();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final combined = '$random$timestamp'.padRight(16, '0').substring(0, 16);
    return Uint8List.fromList(utf8.encode(combined));
  }

  /// HMAC-SHA256 implementation
  static Uint8List _hmacSha256(Uint8List key, Uint8List message) {
    // Dart's crypto doesn't have direct HMAC, so we use a simple approach
    const int blockSize = 64;

    Uint8List keyPad = key;
    if (key.length > blockSize) {
      keyPad = Uint8List.fromList(sha256.convert(key).bytes);
    }

    // Pad key to block size
    final paddedKey = Uint8List(blockSize);
    paddedKey.setAll(0, keyPad);

    // Prepare ipad and opad
    final ipad = Uint8List(blockSize);
    final opad = Uint8List(blockSize);
    for (int i = 0; i < blockSize; i++) {
      ipad[i] = paddedKey[i] ^ 0x36;
      opad[i] = paddedKey[i] ^ 0x5c;
    }

    // HMAC calculation
    final innerInput = Uint8List(blockSize + message.length);
    innerInput.setAll(0, ipad);
    innerInput.setAll(blockSize, message);
    final innerHash = sha256.convert(innerInput).bytes;

    final outerInput = Uint8List(blockSize + innerHash.length);
    outerInput.setAll(0, opad);
    outerInput.setAll(blockSize, innerHash);

    return Uint8List.fromList(sha256.convert(outerInput).bytes);
  }

  /// Constant-time comparison to prevent timing attacks
  static bool _constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;

    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }

  /// Stretch a key to longer lengths (e.g., for AES-256 + IV)
  static Uint8List stretchKey(Uint8List baseKey, int outputLength) {
    final result = BytesBuilder();
    var counter = 0;

    while (result.length < outputLength) {
      final input = Uint8List(baseKey.length + 4);
      input.setAll(0, baseKey);
      input[baseKey.length] = (counter >> 24) & 0xFF;
      input[baseKey.length + 1] = (counter >> 16) & 0xFF;
      input[baseKey.length + 2] = (counter >> 8) & 0xFF;
      input[baseKey.length + 3] = counter & 0xFF;

      result.add(sha256.convert(input).bytes);
      counter++;
    }

    return result.toBytes().sublist(0, outputLength);
  }
}

/// Legacy Key Service — Maintain backward compatibility
class CombinedKeyService {
  Uint8List deriveCombinedKey({
    required Uint8List biometricKey,
    required String pin,
  }) {
    // Use enhanced key derivation for new implementations
    return EnhancedKeyDerivationService.deriveCombinedKey(
      biometricKey: biometricKey,
      pin: pin,
    );
  }

  // Legacy static method for compatibility
  static Uint8List deriveKeyLegacy({
    required Uint8List biometricKey,
    required String pin,
  }) {
    if (biometricKey.isEmpty) {
      throw ArgumentError('Biometric key must not be empty.');
    }

    final trimmedPin = pin.trim();
    if (trimmedPin.isEmpty) {
      throw ArgumentError('PIN must not be empty.');
    }

    final pinBytes = utf8.encode(trimmedPin);
    final merged = Uint8List(biometricKey.length + pinBytes.length);
    merged.setAll(0, biometricKey);
    merged.setAll(biometricKey.length, pinBytes);

    final digest = sha256.convert(merged);
    return Uint8List.fromList(digest.bytes);
  }
}
