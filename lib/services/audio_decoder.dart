import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import '../utils/binary_converter.dart';

class AudioDecoder {
  static const int bitDurationMs = 2;
  static const double freq0Hz = 1500.0;
  static const double freq1Hz = 3000.0;

  Future<Uint8List> decodeAudioToBytes(
    File wavFile, {
    int? bitDurationMsOverride,
    double? frequency0HzOverride,
    double? frequency1HzOverride,
  }) async {
    final raf = await wavFile.open(mode: FileMode.read);
    try {
      final header = await _parseWavPcm16Header(raf);

      final durationMs = bitDurationMsOverride ?? bitDurationMs;
      final f0 = frequency0HzOverride ?? freq0Hz;
      final f1 = frequency1HzOverride ?? freq1Hz;

      final spb = (header.sampleRate * durationMs / 1000).round();
      if (spb <= 0) {
        throw StateError('Invalid samples-per-bit: $spb');
      }

      final bytesPerBit = spb * 2;
      final totalSamples = header.dataSizeBytes ~/ 2;
      final totalBits = totalSamples ~/ spb;
      if (totalBits <= 0) {
        throw const FormatException('Audio too short to decode.');
      }

      final totalBytes = totalBits ~/ 8;
      if (totalBytes <= 0) {
        throw const FormatException('Audio does not contain full bytes.');
      }

      final out = Uint8List(totalBytes);
      var outIndex = 0;

      await raf.setPosition(header.dataOffset);

      const bitsPerChunk = 2048;
      final buffer = Uint8List(bitsPerChunk * bytesPerBit);

      var currentByte = 0;
      var bitsInCurrentByte = 0;

      var bitIndex = 0;
      while (bitIndex < totalBits && outIndex < out.length) {
        final remainingBits = totalBits - bitIndex;
        final bitsThisChunk =
            remainingBits > bitsPerChunk ? bitsPerChunk : remainingBits;
        final bytesToRead = bitsThisChunk * bytesPerBit;

        final read = await raf.readInto(buffer, 0, bytesToRead);
        if (read <= 0) {
          break;
        }

        final usableBits = read ~/ bytesPerBit;
        for (var localBit = 0; localBit < usableBits; localBit++) {
          final startByte = localBit * bytesPerBit;
          final p0 = _goertzelPowerPcm16le(
            pcm16leBytes: buffer,
            startByte: startByte,
            sampleCount: spb,
            sampleRate: header.sampleRate,
            targetFrequencyHz: f0,
          );
          final p1 = _goertzelPowerPcm16le(
            pcm16leBytes: buffer,
            startByte: startByte,
            sampleCount: spb,
            sampleRate: header.sampleRate,
            targetFrequencyHz: f1,
          );

          final bit = p1 > p0 ? 1 : 0;
          currentByte = (currentByte << 1) | bit;
          bitsInCurrentByte++;

          if (bitsInCurrentByte == 8) {
            out[outIndex++] = currentByte;
            if (outIndex >= out.length) {
              break;
            }
            currentByte = 0;
            bitsInCurrentByte = 0;
          }
        }

        bitIndex += usableBits;
        if (usableBits < bitsThisChunk) {
          break;
        }
      }

      if (outIndex == out.length) {
        return out;
      }
      return Uint8List.fromList(out.sublist(0, outIndex));
    } finally {
      await raf.close();
    }
  }

  Future<List<int>> decodeAudioToBinary(
    File wavFile, {
    int? bitDurationMsOverride,
    double? frequency0HzOverride,
    double? frequency1HzOverride,
  }) async {
    final decodedBytes = await decodeAudioToBytes(
      wavFile,
      bitDurationMsOverride: bitDurationMsOverride,
      frequency0HzOverride: frequency0HzOverride,
      frequency1HzOverride: frequency1HzOverride,
    );
    return BinaryConverter.bytesToBits(decodedBytes);
  }
}

class _WavPcm16Header {
  final int sampleRate;
  final int channels;
  final int dataOffset;
  final int dataSizeBytes;

  const _WavPcm16Header({
    required this.sampleRate,
    required this.channels,
    required this.dataOffset,
    required this.dataSizeBytes,
  });
}

Future<_WavPcm16Header> _parseWavPcm16Header(RandomAccessFile raf) async {
  final fileLen = await raf.length();
  if (fileLen < 44) {
    throw const FormatException('Not a valid WAV file (too short).');
  }

  await raf.setPosition(0);
  final riffHeader = await raf.read(12);
  if (riffHeader.length < 12) {
    throw const FormatException('Not a valid WAV file (truncated).');
  }

  final riff = _readAscii(riffHeader, 0, 4);
  final wave = _readAscii(riffHeader, 8, 4);
  if (riff != 'RIFF' || wave != 'WAVE') {
    throw const FormatException('Not a RIFF/WAVE file.');
  }

  int? sampleRate;
  int? channels;
  int? bitsPerSample;
  int? audioFormat;
  int? dataOffset;
  int? dataSize;

  var offset = 12;
  while (offset + 8 <= fileLen) {
    await raf.setPosition(offset);
    final chunkHeader = await raf.read(8);
    if (chunkHeader.length < 8) {
      break;
    }

    final chunkId = _readAscii(chunkHeader, 0, 4);
    final chunkSize = _readUint32le(chunkHeader, 4);
    final chunkDataStart = offset + 8;
    final next = chunkDataStart + chunkSize + (chunkSize.isOdd ? 1 : 0);

    if (next > fileLen) {
      break;
    }

    if (chunkId == 'fmt ') {
      if (chunkSize < 16) {
        throw const FormatException('Invalid fmt chunk size.');
      }

      await raf.setPosition(chunkDataStart);
      final fmt = await raf.read(16);
      if (fmt.length < 16) {
        throw const FormatException('Invalid fmt chunk (truncated).');
      }

      audioFormat = _readUint16le(fmt, 0);
      channels = _readUint16le(fmt, 2);
      sampleRate = _readUint32le(fmt, 4);
      bitsPerSample = _readUint16le(fmt, 14);
    } else if (chunkId == 'data') {
      dataOffset = chunkDataStart;
      dataSize = chunkSize;
      break;
    }

    offset = next;
  }

  if (audioFormat == null ||
      channels == null ||
      bitsPerSample == null ||
      sampleRate == null ||
      dataOffset == null ||
      dataSize == null) {
    throw const FormatException('Missing required WAV chunks.');
  }

  if (audioFormat != 1) {
    throw const FormatException('Only PCM WAV is supported.');
  }
  if (channels != 1) {
    throw FormatException(
      'Only mono WAV is supported (got $channels channels).',
    );
  }
  if (bitsPerSample != 16) {
    throw FormatException(
      'Only 16-bit WAV is supported (got $bitsPerSample bits).',
    );
  }

  var safeDataSize = dataSize;
  if (dataOffset + safeDataSize > fileLen) {
    safeDataSize = fileLen - dataOffset;
  }
  safeDataSize -= safeDataSize % 2;

  return _WavPcm16Header(
    sampleRate: sampleRate,
    channels: channels,
    dataOffset: dataOffset,
    dataSizeBytes: safeDataSize,
  );
}

double _goertzelPowerPcm16le({
  required Uint8List pcm16leBytes,
  required int startByte,
  required int sampleCount,
  required int sampleRate,
  required double targetFrequencyHz,
}) {
  if (sampleCount <= 0) {
    throw ArgumentError('sampleCount must be > 0');
  }
  if (startByte < 0 || startByte + sampleCount * 2 > pcm16leBytes.length) {
    throw RangeError('Invalid start/sampleCount for PCM buffer.');
  }

  final k = (0.5 + (sampleCount * targetFrequencyHz / sampleRate)).floor();
  final w = (2.0 * math.pi * k) / sampleCount;
  final cosine = math.cos(w);
  final coefficient = 2.0 * cosine;

  double q0 = 0.0;
  double q1 = 0.0;
  double q2 = 0.0;

  var offset = startByte;
  for (var i = 0; i < sampleCount; i++) {
    final lo = pcm16leBytes[offset];
    final hi = pcm16leBytes[offset + 1];
    var v = (hi << 8) | lo;
    if ((v & 0x8000) != 0) {
      v -= 0x10000;
    }
    final sample = v / 32768.0;
    q0 = coefficient * q1 - q2 + sample;
    q2 = q1;
    q1 = q0;
    offset += 2;
  }

  return q1 * q1 + q2 * q2 - coefficient * q1 * q2;
}

String _readAscii(Uint8List bytes, int offset, int length) {
  if (offset < 0 || offset + length > bytes.length) {
    return '';
  }
  return String.fromCharCodes(bytes.sublist(offset, offset + length));
}

int _readUint32le(Uint8List bytes, int offset) {
  final bd = ByteData.sublistView(bytes, offset, offset + 4);
  return bd.getUint32(0, Endian.little);
}

int _readUint16le(Uint8List bytes, int offset) {
  final bd = ByteData.sublistView(bytes, offset, offset + 2);
  return bd.getUint16(0, Endian.little);
}
