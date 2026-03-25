// ignore_for_file: implementation_imports

import 'dart:typed_data';

import 'package:dart_reed_solomon_nullsafety/dart_reed_solomon_nullsafety.dart';
import 'package:dart_reed_solomon_nullsafety/src/galois_field.dart';
import 'package:dart_reed_solomon_nullsafety/src/polynomial.dart';

class ErrorCorrectionService {
  static const int _symbolSizeInBits = 8;
  static const int _primitivePolynomial = 0x11d;
  static const int _initialRoot = 1;

  final int correctableSymbols;

  late final GaloisField _galoisField = GaloisField(
    _primitivePolynomial,
    1 << _symbolSizeInBits,
  );

  late final GFPolynomial _polynomialGenerator = _buildGenerator();
  late final ReedSolomon _rs = ReedSolomon(
    symbolSizeInBits: _symbolSizeInBits,
    numberOfCorrectableSymbols: correctableSymbols,
    primitivePolynomial: _primitivePolynomial,
    initialRoot: _initialRoot,
  );

  ErrorCorrectionService({this.correctableSymbols = 8}) {
    if (correctableSymbols <= 0) {
      throw ArgumentError('correctableSymbols must be > 0');
    }
    if (paritySymbols >= codewordLength) {
      throw ArgumentError(
        'Too many correctable symbols for GF(256): paritySymbols=$paritySymbols, codewordLength=$codewordLength',
      );
    }
  }

  int get paritySymbols => 2 * correctableSymbols;

  int get codewordLength => (1 << _symbolSizeInBits) - 1;

  int get dataSymbolsPerBlock => codewordLength - paritySymbols;

  GFPolynomial _buildGenerator() {
    var generator = GFPolynomial(_galoisField, <int>[1]);
    for (var i = 0; i < paritySymbols; i++) {
      generator = generator.multiply(
        GFPolynomial(_galoisField, <int>[
          1,
          _galoisField.pow(2, i + _initialRoot),
        ]),
      );
    }
    return generator;
  }

  List<int> _systematicParity(List<int> dataBlock) {
    final ecc = paritySymbols;
    final shifted = <int>[...dataBlock, ...List<int>.filled(ecc, 0)];
    final remainder = GFPolynomial(
      _galoisField,
      shifted,
    ).divide(_polynomialGenerator)[1].coefficients;

    final parity = List<int>.filled(ecc, 0);
    parity.setAll(ecc - remainder.length, remainder);
    return parity;
  }

  Uint8List encode(Uint8List messageBytes) {
    if (messageBytes.isEmpty) {
      return Uint8List(0);
    }

    final k = dataSymbolsPerBlock;
    final out = BytesBuilder(copy: false);

    for (var offset = 0; offset < messageBytes.length; offset += k) {
      final end = (offset + k <= messageBytes.length)
          ? offset + k
          : messageBytes.length;
      final dataBlock = messageBytes.sublist(offset, end);
      if (dataBlock.length > k) {
        throw StateError(
          'Internal error: block larger than max payload block.',
        );
      }

      final parity = _systematicParity(dataBlock);

      out.add(dataBlock);
      out.add(parity);
    }

    return out.toBytes();
  }

  Uint8List decode(Uint8List encodedBytes) {
    if (encodedBytes.isEmpty) {
      return Uint8List(0);
    }

    final n = codewordLength;
    final ecc = paritySymbols;
    if (encodedBytes.length <= ecc) {
      throw const FormatException(
        'Encoded data is too short to contain parity.',
      );
    }

    final out = BytesBuilder(copy: false);
    var offset = 0;

    while (offset < encodedBytes.length) {
      final remaining = encodedBytes.length - offset;
      final blockLen = remaining >= n ? n : remaining;
      if (blockLen <= ecc) {
        throw const FormatException('Trailing encoded data is incomplete.');
      }

      final block = encodedBytes.sublist(offset, offset + blockLen);
      final decoded = _rs.decode(block);
      out.add(decoded);
      offset += blockLen;
    }

    return out.toBytes();
  }
}
