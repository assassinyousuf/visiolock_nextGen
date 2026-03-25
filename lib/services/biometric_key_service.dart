import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricKeyService {
  static const String _storageKey = 'i2a_biometric_secret_v1';

  final FlutterSecureStorage _storage;
  final Random _random;

  BiometricKeyService({FlutterSecureStorage? storage, Random? random})
      : _storage = storage ?? const FlutterSecureStorage(),
        _random = random ?? Random.secure();

  Future<Uint8List> getOrCreateBiometricKey({int lengthBytes = 32}) async {
    if (lengthBytes <= 0) {
      throw ArgumentError('lengthBytes must be > 0');
    }

    final existing = await _storage.read(key: _storageKey);
    if (existing != null && existing.isNotEmpty) {
      try {
        final bytes = base64Url.decode(existing);
        if (bytes.length == lengthBytes) {
          return Uint8List.fromList(bytes);
        }
      } catch (_) {
        // Ignore and regenerate.
      }
    }

    final fresh = Uint8List.fromList(
      List<int>.generate(lengthBytes, (_) => _random.nextInt(256)),
    );

    await _storage.write(key: _storageKey, value: base64Url.encode(fresh));
    return fresh;
  }
}
