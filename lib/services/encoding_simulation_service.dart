import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../models/encoding_payload.dart';
import '../models/model_prediction.dart';
import 'multi_encryption_implementations.dart';

class EncodingSimulationService {
  final Map<String, EncryptionImplementation> _strategies = {
    'saic': SaicActImplementation(),
    'chacha': ChaCha20Poly1305Implementation(),
    'xor': XorCryptoImplementation(),
    'aes': AesGcmImplementation(),
  };

  EncodingPayload encode({
    required List<int> sourceBytes,
    required ModelPrediction prediction,
  }) {
    // 1. Adaptive Compression
    final compressed = _compress(sourceBytes, prediction.encodingClass);
    
    // 2. Adaptive Encryption Strategy selection
    final encrypted = _encrypt(compressed, prediction.encodingClass);
    
    final chunks = _chunkCountFor(encrypted.lengthInBytes);

    return EncodingPayload(
      pseudoEncryptedBytes: encrypted.toList(),
      compressedSize: compressed.length,
      segmentCount: chunks,
    );
  }

  Uint8List _compress(List<int> data, int encodingClass) {
    // Strategy 0 (SAIC-ACT/Image): No extra compression (usually already compressed)
    // Strategy 1 (Light/Text): GZip
    // Strategy 2 (Entropy/Binary): GZip
    
    if (encodingClass == 1 || encodingClass == 2) {
      try {
        return Uint8List.fromList(GZipCodec().encode(data));
      } catch (e) {
        // Fallback if compression fails or overhead is too high
        return Uint8List.fromList(data);
      }
    }
    return Uint8List.fromList(data);
  }

  Uint8List _encrypt(Uint8List data, int encodingClass) {
    // Generate a random session key (Simulated)
    // In production, this would be derived from ECDH exchange
    final key = _generateRandomKey(32); 

    EncryptionImplementation impl;
    switch (encodingClass) {
      case 0:
        impl = _strategies['saic']!; // Chaos (Images)
        break;
      case 1:
        impl = _strategies['chacha']!; // Light (Text)
        break;
      case 2:
      default:
        impl = _strategies['aes']!; // Standard/Strong (Binary)
        break;
    }

    return impl.encrypt(data, key);
  }

  Uint8List _generateRandomKey(int length) {
    final random = Random.secure();
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return bytes;
  }

  int _chunkCountFor(int byteLength) {
    const chunkSize = 64 * 1024;
    return (byteLength / chunkSize).ceil().clamp(1, 1000000);
  }
}
