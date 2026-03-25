import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:image_to_audio/services/error_correction_service.dart';
import 'package:image_to_audio/services/noise_resistant_transmission_service.dart';

void main() {
  test('Reed–Solomon FEC round-trips with correctable symbol errors', () {
    final ecc = ErrorCorrectionService(correctableSymbols: 8);

    final rnd = Random(42);
    final k = ecc.dataSymbolsPerBlock;
    final message = Uint8List.fromList(
      List<int>.generate(k * 2, (_) => rnd.nextInt(256)),
    );

    final encoded = ecc.encode(message);
    final corrupted = Uint8List.fromList(encoded);

    final n = ecc.codewordLength;
    final t = ecc.correctableSymbols;
    final errorsPerBlock = t ~/ 2;
    final blocks = corrupted.length ~/ n;

    for (var blockIndex = 0; blockIndex < blocks; blockIndex++) {
      final start = blockIndex * n;

      final positions = <int>{};
      while (positions.length < errorsPerBlock) {
        positions.add(rnd.nextInt(n));
      }

      for (final p in positions) {
        final idx = start + p;
        corrupted[idx] = corrupted[idx] ^ (1 << rnd.nextInt(8));
      }
    }

    final decoded = ecc.decode(corrupted);

    expect(decoded.sublist(0, message.length), equals(message));
  });

  test('NRSTS protects and recovers encrypted bits', () {
    final rnd = Random(7);
    final ecc = ErrorCorrectionService(correctableSymbols: 8);
    final k = ecc.dataSymbolsPerBlock;
    final originalBytes = Uint8List.fromList(
      List<int>.generate(k, (_) => rnd.nextInt(256)),
    );

    final originalBits = <int>[];
    for (final b in originalBytes) {
      for (var i = 7; i >= 0; i--) {
        originalBits.add((b >> i) & 1);
      }
    }

    final nrsts = NoiseResistantTransmissionService(
      correctableSymbols: 8,
      repetitions: 3,
    );

    final protectedBits = nrsts.protectEncryptedBits(originalBits);

    final corrupted = List<int>.from(protectedBits);
    final segmentLen = protectedBits.length ~/ 3;

    // Flip bits in a bounded number of bytes per codeword per segment.
    // This keeps us under the Reed–Solomon correction capability.
    final codewordBits = ecc.codewordLength * 8;
    final maxByteErrorsPerCodeword = 3;

    for (var seg = 0; seg < 3; seg++) {
      final segOffset = seg * segmentLen;
      final codewords = segmentLen ~/ codewordBits;

      for (var cw = 0; cw < codewords; cw++) {
        final cwOffset = segOffset + cw * codewordBits;

        final bytePositions = <int>{};
        while (bytePositions.length < maxByteErrorsPerCodeword) {
          bytePositions.add(rnd.nextInt(ecc.codewordLength));
        }

        for (final bytePos in bytePositions) {
          final bitInByte = rnd.nextInt(8);
          final bitIndex = cwOffset + (bytePos * 8) + bitInByte;
          corrupted[bitIndex] = corrupted[bitIndex] == 1 ? 0 : 1;
        }
      }
    }

    final recoveredBits = nrsts.recoverEncryptedBits(corrupted);

    expect(recoveredBits.sublist(0, originalBits.length), equals(originalBits));
  });

  test('NRSTS recovery falls back for unprotected data', () {
    // 20 bytes (160 bits) is too short to be a full RS codeword, so recovery
    // should just return the original bits (trimmed to multiple-of-8).
    final bits = List<int>.generate(160, (i) => i.isEven ? 0 : 1);

    final nrsts = NoiseResistantTransmissionService(
      correctableSymbols: 8,
      repetitions: 3,
    );

    final recovered = nrsts.recoverEncryptedBits(bits);

    expect(recovered, equals(bits));
  });
}
