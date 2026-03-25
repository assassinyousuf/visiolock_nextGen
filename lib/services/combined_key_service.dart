import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

class CombinedKeyService {
  Uint8List deriveCombinedKey({
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
