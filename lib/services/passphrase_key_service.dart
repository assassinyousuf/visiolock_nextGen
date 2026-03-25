import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

class PassphraseKeyService {
  Uint8List deriveKey(String passphrase) {
    final trimmed = passphrase.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Passphrase must not be empty.');
    }

    final digest = sha256.convert(utf8.encode(trimmed));
    return Uint8List.fromList(digest.bytes);
  }
}
