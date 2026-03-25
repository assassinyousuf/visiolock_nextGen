import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:image_to_audio/services/audio_decoder.dart';
import 'package:image_to_audio/services/audio_encoder.dart';
import 'package:image_to_audio/services/combined_key_service.dart';
import 'package:image_to_audio/services/encryption_service.dart';
import 'package:image_to_audio/services/image_processor.dart';
import 'package:image_to_audio/services/image_reconstructor.dart';
import 'package:image_to_audio/services/noise_resistant_transmission_service.dart';
import 'package:image_to_audio/utils/binary_converter.dart';

void main() {
  // ──────────────────────────────────────────────────────────────
  // SAIC-ACT unit tests
  // ──────────────────────────────────────────────────────────────

  group('SAIC-ACT EncryptionService', () {
    final key = Uint8List.fromList(
      List<int>.generate(32, (i) => (i * 31 + 17) & 0xff),
    );
    final enc = EncryptionService();

    test('encrypt then decrypt restores original bytes', () {
      final plain = Uint8List.fromList(
        List<int>.generate(256, (i) => i & 0xff),
      );
      final cipher = enc.encryptBytes(dataBytes: plain, key: key);
      expect(cipher, isNot(equals(plain)),
          reason: 'Ciphertext must differ from plaintext');
      final recovered = enc.decryptBytes(encryptedBytes: cipher, key: key);
      expect(recovered, equals(plain));
    });

    test('different keys produce different ciphertexts', () {
      final plain = Uint8List.fromList(List<int>.filled(64, 0xAB));
      final key2 = Uint8List.fromList(
        List<int>.generate(32, (i) => (i * 17 + 5) & 0xff),
      );
      final c1 = enc.encryptBytes(dataBytes: plain, key: key);
      final c2 = enc.encryptBytes(dataBytes: plain, key: key2);
      expect(c1, isNot(equals(c2)),
          reason: 'Different keys must yield different ciphertexts');
    });

    test('avalanche: single plaintext bit flip changes many ciphertext bits',
        () {
      final plain = Uint8List.fromList(List<int>.filled(32, 0x00));
      final plainFlipped = Uint8List.fromList(plain)
        ..[0] ^= 0x01; // flip LSB of first byte

      final c1 = enc.encryptBytes(dataBytes: plain, key: key);
      final c2 = enc.encryptBytes(dataBytes: plainFlipped, key: key);

      int diffBits = 0;
      for (int i = 0; i < c1.length; i++) {
        int diff = c1[i] ^ c2[i];
        while (diff != 0) {
          diffBits += diff & 1;
          diff >>= 1;
        }
      }
      // A strong cipher should flip roughly 50 % of 256 bits → ≥ 64 flips.
      expect(diffBits, greaterThan(64),
          reason: 'Expected strong avalanche effect');
    });

    test('noise-aware binary shaping reduces all-zero/all-one bytes', () {
      // Feed all-zero bytes through encryption and check no 0x00 or 0xFF bytes
      // survive in the shaped output (NABS removes maximal-run triplets).
      final plain = Uint8List.fromList(List<int>.filled(300, 0x00));
      final cipher = enc.encryptBytes(dataBytes: plain, key: key);
      final zeroCount = cipher.where((b) => b == 0x00 || b == 0xFF).length;
      // After permutation + diffusion + shaping these should be very rare.
      expect(zeroCount, lessThan(cipher.length ~/ 4),
          reason: 'NABS should reduce all-zero/all-one bytes significantly');
    });

    test('empty input returns empty output', () {
      expect(enc.encryptBytes(dataBytes: Uint8List(0), key: key), isEmpty);
      expect(enc.decryptBytes(encryptedBytes: Uint8List(0), key: key), isEmpty);
    });
  });

  // ──────────────────────────────────────────────────────────────
  // Full end-to-end lossless round-trip through WAV
  // ──────────────────────────────────────────────────────────────

  test(
    'Lossless I2A3 SAIC-ACT round-trip through WAV (clean file)',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'i2a_saic_roundtrip_',
      );
      addTearDown(() async {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {
          // Best-effort cleanup.
        }
      });

      // Create a tiny but non-trivial PNG so the byte stream is realistic.
      const width = 2;
      const height = 2;
      final rgba = Uint8List(width * height * 4);
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          final i = (y * width + x) * 4;
          rgba[i + 0] = (x * 120 + 10) & 0xff; // R
          rgba[i + 1] = (y * 120 + 20) & 0xff; // G
          rgba[i + 2] = ((x + y) * 80 + 30) & 0xff; // B
          rgba[i + 3] = 255; // A
        }
      }

      final image = img.Image.fromBytes(
        width: width,
        height: height,
        bytes: rgba.buffer,
        numChannels: 4,
        order: img.ChannelOrder.rgba,
      );
      final originalPngBytes = Uint8List.fromList(img.encodePng(image));

      final imageFile = File(
        '${tempDir.path}${Platform.pathSeparator}sample.png',
      );
      await imageFile.writeAsBytes(originalPngBytes, flush: true);

      // ── Sender pipeline ──────────────────────────────────────
      final processor = ImageProcessor();
      final payload = await processor.convertImageToBinary(imageFile);
      expect(payload.extension, equals('png'));

      final biometricKey = Uint8List.fromList(
        List<int>.generate(32, (i) => (i * 31 + 17) & 0xff),
      );
      final key = CombinedKeyService().deriveCombinedKey(
        biometricKey: biometricKey,
        pin: '1234',
      );

      final encryption = EncryptionService();

      // SAIC-ACT encryption (permutation + diffusion + NABS)
      final encryptedBytes = encryption.encryptBytes(
        dataBytes: payload.payloadBytes,
        key: key,
      );

      // NRSTS: Reed–Solomon FEC + 3× repetition
      final nrsts = NoiseResistantTransmissionService(
        correctableSymbols: 8,
        repetitions: 3,
      );
      final protectedBytes = nrsts.protectEncryptedBytes(encryptedBytes);
      final protectedBits = BinaryConverter.bytesToBits(protectedBytes);

      // FSK audio encoding
      final encoder = AudioEncoder();
      final packet = encoder.encodeBinaryToAudio(protectedBits);

      final wavFile = File(
        '${tempDir.path}${Platform.pathSeparator}encoded.wav',
      );
      await wavFile.writeAsBytes(packet.wavBytes!, flush: true);

      // ── Receiver pipeline ────────────────────────────────────
      final decoder = AudioDecoder();

      // Decode FSK audio → bytes
      final receivedBytes = await decoder.decodeAudioToBytes(wavFile);

      // NRSTS majority-vote recovery
      final recoveredEncryptedBytes =
          nrsts.recoverEncryptedBytes(receivedBytes);

      // SAIC-ACT decryption (inverse NABS + inverse diffusion + inverse perm)
      final decryptedBytes = encryption.decryptBytes(
        encryptedBytes: recoveredEncryptedBytes,
        key: key,
      );

      // Image reconstruction with SHA-256 integrity check
      final reconstructor = ImageReconstructor();
      final decoded =
          reconstructor.reconstructImageFromPayloadBytes(decryptedBytes);

      expect(decoded.extension, equals('png'));
      expect(decoded.payloadMagic, equals('I2A3'));
      expect(decoded.integrityVerified, isTrue);
      expect(decoded.bytes, equals(originalPngBytes));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
