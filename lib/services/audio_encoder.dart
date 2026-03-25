import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../models/audio_packet.dart';

class AudioEncoder {
  static const int sampleRate = 8000;
  static const int bitDurationMs = 2;

  static const double freq0Hz = 1500.0;
  static const double freq1Hz = 3000.0;

  static const int _channels = 1;
  static const double _amplitude = 0.8;

  int get samplesPerBit => (sampleRate * bitDurationMs / 1000).round();

  AudioPacket encodeBinaryToAudio(List<int> encryptedBits) {
    if (encryptedBits.isEmpty) {
      throw ArgumentError('Encrypted data is empty.');
    }

    final spb = samplesPerBit;
    if (spb <= 0) {
      throw StateError('Invalid samples-per-bit computed: $spb');
    }

    final totalSamples = encryptedBits.length * spb;

    // This in-memory encoder is only safe for small payloads.
    // Prefer encodeBytesToAudioFile() to avoid OOM.
    final estimatedBytes = 44 + (totalSamples * 2);
    if (estimatedBytes > 128 * 1024 * 1024) {
      throw const FormatException(
        'Audio output too large for in-memory encoding. Use file-based encoding.',
      );
    }
    final samples = Int16List(totalSamples);

    var phase = 0.0;
    final twoPi = 2.0 * math.pi;
    final amp = _amplitude * 32767.0;

    for (var bitIndex = 0; bitIndex < encryptedBits.length; bitIndex++) {
      final bit = encryptedBits[bitIndex];
      if (bit != 0 && bit != 1) {
        throw ArgumentError('Bits must be 0 or 1.');
      }

      final freq = bit == 0 ? freq0Hz : freq1Hz;
      final phaseInc = twoPi * freq / sampleRate;

      final base = bitIndex * spb;
      for (var i = 0; i < spb; i++) {
        phase += phaseInc;
        final sample = (math.sin(phase) * amp).round();
        samples[base + i] = sample < -32768
            ? -32768
            : (sample > 32767 ? 32767 : sample);
      }
    }

    final wavBytes = _writeWavPcm16(
      samples: samples,
      sampleRate: sampleRate,
      channels: _channels,
    );

    return AudioPacket(
      sampleRate: sampleRate,
      bitDurationMs: bitDurationMs,
      frequency0Hz: freq0Hz,
      frequency1Hz: freq1Hz,
      wavBytes: wavBytes,
    );
  }

  /// Encodes protected bytes to a WAV file without loading the whole waveform
  /// into memory.
  ///
  /// Bit order matches [BinaryConverter.bytesToBits]: MSB -> LSB per byte.
  Future<AudioPacket> encodeBytesToAudioFile(
    Uint8List protectedBytes, {
    String? fileName,
  }) async {
    if (protectedBytes.isEmpty) {
      throw ArgumentError('Encrypted data is empty.');
    }

    final spb = samplesPerBit;
    if (spb <= 0) {
      throw StateError('Invalid samples-per-bit computed: $spb');
    }

    final totalBits = protectedBytes.length * 8;
    final totalSamples = totalBits * spb;
    final dataSizeBytes = totalSamples * 2;

    // WAV uses uint32 sizes.
    const maxU32 = 0xFFFFFFFF;
    final riffChunkSize = 36 + dataSizeBytes;
    if (dataSizeBytes > maxU32 || riffChunkSize > maxU32) {
      throw const FormatException(
        'Audio output too large for WAV format (exceeds 4GB limit).',
      );
    }

    final tempDir = await getTemporaryDirectory();
    final name =
        fileName ??
        'encoded_audio_${DateTime.now().millisecondsSinceEpoch}_tmp.wav';
    final file = File('${tempDir.path}${Platform.pathSeparator}$name');

    final raf = await file.open(mode: FileMode.write);
    try {
      final header = _wavHeaderPcm16(
        sampleRate: sampleRate,
        channels: _channels,
        dataSizeBytes: dataSizeBytes,
      );
      await raf.writeFrom(header);

      const bitsPerChunk = 512;
      final chunkSamples = bitsPerChunk * spb;
      final chunkBytes = Uint8List(chunkSamples * 2);

      var chunkOffset = 0;
      var bitsInChunk = 0;

      var phase = 0.0;
      final twoPi = 2.0 * math.pi;
      final amp = _amplitude * 32767.0;

      for (var byteIndex = 0; byteIndex < protectedBytes.length; byteIndex++) {
        final byte = protectedBytes[byteIndex];
        for (var bitPos = 7; bitPos >= 0; bitPos--) {
          final bit = (byte >> bitPos) & 1;
          final freq = bit == 0 ? freq0Hz : freq1Hz;
          final phaseInc = twoPi * freq / sampleRate;

          for (var i = 0; i < spb; i++) {
            phase += phaseInc;
            if (phase >= twoPi) {
              phase -= twoPi;
            }
            final sample = (math.sin(phase) * amp).round();
            final clamped = sample < -32768
                ? -32768
                : (sample > 32767 ? 32767 : sample);
            final u = clamped & 0xFFFF;
            chunkBytes[chunkOffset++] = u & 0xFF;
            chunkBytes[chunkOffset++] = (u >> 8) & 0xFF;
          }

          bitsInChunk++;
          if (bitsInChunk >= bitsPerChunk) {
            await raf.writeFrom(chunkBytes, 0, chunkOffset);
            chunkOffset = 0;
            bitsInChunk = 0;
          }
        }
      }

      if (chunkOffset > 0) {
        await raf.writeFrom(chunkBytes, 0, chunkOffset);
      }
    } finally {
      await raf.close();
    }

    return AudioPacket(
      sampleRate: sampleRate,
      bitDurationMs: bitDurationMs,
      frequency0Hz: freq0Hz,
      frequency1Hz: freq1Hz,
      wavFilePath: file.path,
    );
  }

  Future<File> saveAudioFile(Uint8List wavBytes, {String? fileName}) async {
    final outputDir = await _bestOutputDirectory();
    final name =
        fileName ??
        'encoded_audio_${DateTime.now().millisecondsSinceEpoch}.wav';
    final file = File('${outputDir.path}${Platform.pathSeparator}$name');
    await file.writeAsBytes(wavBytes, flush: true);
    return file;
  }

  Future<File> saveAudioFileFromPath(
    String sourcePath, {
    String? fileName,
  }) async {
    final src = File(sourcePath);
    if (!await src.exists()) {
      throw FileSystemException('Generated audio file not found.', sourcePath);
    }

    final outputDir = await _bestOutputDirectory();
    final name =
        fileName ??
        'encoded_audio_${DateTime.now().millisecondsSinceEpoch}.wav';
    final destPath = '${outputDir.path}${Platform.pathSeparator}$name';

    // If the source is already in the target directory, don't rename/move it.
    if (src.parent.path == outputDir.path) {
      return src.copy(destPath);
    }

    try {
      final moved = await src.rename(destPath);
      return moved;
    } catch (_) {
      final copied = await src.copy(destPath);
      try {
        await src.delete();
      } catch (_) {
        // Best-effort cleanup.
      }
      return copied;
    }
  }

  Future<Directory> _bestOutputDirectory() async {
    if (Platform.isAndroid) {
      final dir = Directory('/storage/emulated/0/EncryptAudio');
      try {
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return dir;
      } on FileSystemException catch (e) {
        throw FileSystemException(
          'Unable to write to /storage/emulated/0/EncryptAudio. Grant "All files access" permission and try again.',
          e.path,
          e.osError,
        );
      }
    }

    final external = await getExternalStorageDirectory();
    if (external != null) {
      return external;
    }
    return getApplicationDocumentsDirectory();
  }

  Uint8List _writeWavPcm16({
    required Int16List samples,
    required int sampleRate,
    required int channels,
  }) {
    const bitsPerSample = 16;
    final dataSize = samples.length * 2;
    final byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
    final blockAlign = channels * (bitsPerSample ~/ 8);
    final riffChunkSize = 36 + dataSize;

    final out = Uint8List(44 + dataSize);
    final bd = ByteData.sublistView(out);

    _writeAscii(bd, 0, 'RIFF');
    bd.setUint32(4, riffChunkSize, Endian.little);
    _writeAscii(bd, 8, 'WAVE');

    _writeAscii(bd, 12, 'fmt ');
    bd.setUint32(16, 16, Endian.little);
    bd.setUint16(20, 1, Endian.little);
    bd.setUint16(22, channels, Endian.little);
    bd.setUint32(24, sampleRate, Endian.little);
    bd.setUint32(28, byteRate, Endian.little);
    bd.setUint16(32, blockAlign, Endian.little);
    bd.setUint16(34, bitsPerSample, Endian.little);

    _writeAscii(bd, 36, 'data');
    bd.setUint32(40, dataSize, Endian.little);

    var offset = 44;
    for (var i = 0; i < samples.length; i++) {
      bd.setInt16(offset, samples[i], Endian.little);
      offset += 2;
    }

    return out;
  }

  Uint8List _wavHeaderPcm16({
    required int sampleRate,
    required int channels,
    required int dataSizeBytes,
  }) {
    const bitsPerSample = 16;
    final byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
    final blockAlign = channels * (bitsPerSample ~/ 8);
    final riffChunkSize = 36 + dataSizeBytes;

    final out = Uint8List(44);
    final bd = ByteData.sublistView(out);

    _writeAscii(bd, 0, 'RIFF');
    bd.setUint32(4, riffChunkSize, Endian.little);
    _writeAscii(bd, 8, 'WAVE');

    _writeAscii(bd, 12, 'fmt ');
    bd.setUint32(16, 16, Endian.little);
    bd.setUint16(20, 1, Endian.little);
    bd.setUint16(22, channels, Endian.little);
    bd.setUint32(24, sampleRate, Endian.little);
    bd.setUint32(28, byteRate, Endian.little);
    bd.setUint16(32, blockAlign, Endian.little);
    bd.setUint16(34, bitsPerSample, Endian.little);

    _writeAscii(bd, 36, 'data');
    bd.setUint32(40, dataSizeBytes, Endian.little);

    return out;
  }

  void _writeAscii(ByteData bd, int offset, String s) {
    final units = s.codeUnits;
    for (var i = 0; i < units.length; i++) {
      bd.setUint8(offset + i, units[i]);
    }
  }
}
