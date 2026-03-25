import 'dart:typed_data';

import '../utils/binary_converter.dart';
import 'error_correction_service.dart';

class NoiseResistantTransmissionService {
  final ErrorCorrectionService _ecc;
  final int repetitions;

  NoiseResistantTransmissionService({
    int correctableSymbols = 8,
    this.repetitions = 3,
  }) : _ecc = ErrorCorrectionService(correctableSymbols: correctableSymbols) {
    if (repetitions <= 0) {
      throw ArgumentError('repetitions must be >= 1');
    }
    if (repetitions.isEven) {
      throw ArgumentError('repetitions must be odd for majority voting');
    }
  }

  List<int> protectEncryptedBits(List<int> encryptedBits) {
    if (encryptedBits.isEmpty) {
      return <int>[];
    }

    final encryptedBytes = BinaryConverter.bitsToBytes(encryptedBits);
    final fecBytes = _ecc.encode(encryptedBytes);
    final fecBits = BinaryConverter.bytesToBits(fecBytes);

    if (repetitions == 1) {
      return fecBits;
    }

    final out = List<int>.filled(
      fecBits.length * repetitions,
      0,
      growable: false,
    );
    for (var r = 0; r < repetitions; r++) {
      out.setRange(r * fecBits.length, (r + 1) * fecBits.length, fecBits);
    }
    return out;
  }

  Uint8List protectEncryptedBytes(Uint8List encryptedBytes) {
    if (encryptedBytes.isEmpty) {
      return Uint8List(0);
    }

    final fecBytes = _ecc.encode(encryptedBytes);
    if (repetitions == 1) {
      return fecBytes;
    }

    final out = Uint8List(fecBytes.length * repetitions);
    for (var r = 0; r < repetitions; r++) {
      out.setRange(r * fecBytes.length, (r + 1) * fecBytes.length, fecBytes);
    }
    return out;
  }

  Uint8List recoverEncryptedBytes(Uint8List receivedBytes) {
    if (receivedBytes.isEmpty) {
      return Uint8List(0);
    }

    final candidates = <int>{repetitions, 1}.toList(growable: false);

    for (final rep in candidates) {
      final segments = rep == 1
          ? <Uint8List>[receivedBytes]
          : _splitEvenlyBytes(receivedBytes, rep);
      if (segments == null) {
        continue;
      }

      for (final seg in segments) {
        final recovered = _tryRecoverBytesFromSegment(seg);
        if (recovered != null) {
          return recovered;
        }
      }

      if (rep > 1) {
        final voted = _majorityVoteBytes(segments);
        final recovered = _tryRecoverBytesFromSegment(voted);
        if (recovered != null) {
          return recovered;
        }
      }
    }

    return receivedBytes;
  }

  List<int> recoverEncryptedBits(List<int> receivedBits) {
    if (receivedBits.isEmpty) {
      return <int>[];
    }

    final candidates = <int>{repetitions, 1}.toList(growable: false);

    for (final rep in candidates) {
      final segments = rep == 1
          ? <List<int>>[receivedBits]
          : _splitEvenly(receivedBits, rep);
      if (segments == null) {
        continue;
      }

      for (final seg in segments) {
        final recovered = _tryRecoverFromSegment(seg);
        if (recovered != null) {
          return recovered;
        }
      }

      if (rep > 1) {
        final voted = _majorityVoteBits(segments);
        final recovered = _tryRecoverFromSegment(voted);
        if (recovered != null) {
          return recovered;
        }
      }
    }

    final trimmedLen = receivedBits.length - (receivedBits.length % 8);
    return trimmedLen == receivedBits.length
        ? List<int>.from(receivedBits)
        : receivedBits.sublist(0, trimmedLen);
  }

  Uint8List? _tryRecoverBytesFromSegment(Uint8List segmentBytes) {
    if (segmentBytes.isEmpty) {
      return null;
    }

    try {
      return _ecc.decode(segmentBytes);
    } catch (_) {
      return null;
    }
  }

  List<Uint8List>? _splitEvenlyBytes(Uint8List bytes, int parts) {
    if (parts <= 1) {
      return <Uint8List>[bytes];
    }
    if (bytes.length % parts != 0) {
      return null;
    }

    final segLen = bytes.length ~/ parts;
    final out = <Uint8List>[];
    for (var i = 0; i < parts; i++) {
      final start = i * segLen;
      out.add(Uint8List.sublistView(bytes, start, start + segLen));
    }
    return out;
  }

  Uint8List _majorityVoteBytes(List<Uint8List> segments) {
    if (segments.isEmpty) {
      return Uint8List(0);
    }

    final len = segments.first.length;
    for (final s in segments) {
      if (s.length != len) {
        throw ArgumentError('All segments must have the same length.');
      }
    }

    final out = Uint8List(len);
    final threshold = segments.length ~/ 2;

    for (var i = 0; i < len; i++) {
      var b = 0;
      for (var bit = 0; bit < 8; bit++) {
        var ones = 0;
        final mask = 1 << bit;
        for (final s in segments) {
          if ((s[i] & mask) != 0) {
            ones++;
          }
        }
        if (ones > threshold) {
          b |= mask;
        }
      }
      out[i] = b;
    }

    return out;
  }

  List<int>? _tryRecoverFromSegment(List<int> segmentBits) {
    final trimmedLen = segmentBits.length - (segmentBits.length % 8);
    if (trimmedLen <= 0) {
      return null;
    }

    final safeBits = trimmedLen == segmentBits.length
        ? segmentBits
        : segmentBits.sublist(0, trimmedLen);

    try {
      final encodedBytes = BinaryConverter.bitsToBytes(safeBits);
      final decodedBytes = _ecc.decode(encodedBytes);
      return BinaryConverter.bytesToBits(decodedBytes);
    } catch (_) {
      return null;
    }
  }

  List<List<int>>? _splitEvenly(List<int> bits, int parts) {
    if (parts <= 1) {
      return <List<int>>[bits];
    }
    if (bits.length % parts != 0) {
      return null;
    }

    final segLen = bits.length ~/ parts;
    final out = <List<int>>[];
    for (var i = 0; i < parts; i++) {
      final start = i * segLen;
      out.add(bits.sublist(start, start + segLen));
    }
    return out;
  }

  List<int> _majorityVoteBits(List<List<int>> segments) {
    if (segments.isEmpty) {
      return <int>[];
    }

    final len = segments.first.length;
    for (final s in segments) {
      if (s.length != len) {
        throw ArgumentError('All segments must have the same length.');
      }
    }

    final out = List<int>.filled(len, 0, growable: false);
    final threshold = segments.length ~/ 2;

    for (var i = 0; i < len; i++) {
      var ones = 0;
      for (final s in segments) {
        final b = s[i];
        if (b == 1) {
          ones++;
        } else if (b != 0) {
          throw ArgumentError('Bits must be 0 or 1.');
        }
      }
      out[i] = ones > threshold ? 1 : 0;
    }

    return out;
  }
}
