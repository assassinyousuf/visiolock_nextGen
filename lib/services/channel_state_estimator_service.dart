import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import '../models/channel_state.dart';

/// Channel State Estimator — Estimates SNR and channel condition
class ChannelStateEstimatorService {
  const ChannelStateEstimatorService();

  /// Estimate channel SNR from WAV file (assuming silence = noise)
  Future<ChannelStateEstimate> estimateFromAudioFile(File audioFile) async {
    try {
      final bytes = await audioFile.readAsBytes();
      final snr = _estimateSnrFromWav(bytes);
      final noiseLevel = _estimateNoiseLevel(bytes);

      return ChannelStateEstimate(
        snrDb: snr,
        noiseLevel: noiseLevel,
      );
    } catch (e) {
      // Default to medium condition on error
      return ChannelStateEstimate(
        snrDb: 15.0,
        noiseLevel: 0.3,
      );
    }
  }

  /// Estimate channel SNR from PCM audio samples
  ChannelStateEstimate estimateFromPcmSamples(
    Uint8List pcmBytes, {
    int sampleRate = 8000,
  }) {
    final snr = _calculateSnrFromPcm(pcmBytes);
    final noiseLevel = _estimateNoiseFromPcm(pcmBytes);

    return ChannelStateEstimate(
      snrDb: snr,
      noiseLevel: noiseLevel,
    );
  }

  /// Simple SNR estimation from microphone samples (silence detection)
  /// Assumes first 10% of audio is silence
  double _calculateSnrFromPcm(Uint8List pcmBytes) {
    if (pcmBytes.length < 40) return 15.0; // Default if too short

    // Calculate noise from first part (assumed silence)
    final silenceEnd = pcmBytes.length ~/ 10;
    double noisePower = 0.0;
    for (int i = 0; i < silenceEnd; i += 2) {
      final sample = _readInt16LE(pcmBytes, i);
      noisePower += sample * sample;
    }
    noisePower /= (silenceEnd / 2);

    // Calculate signal power from rest
    double signalPower = 0.0;
    for (int i = silenceEnd; i < pcmBytes.length; i += 2) {
      final sample = _readInt16LE(pcmBytes, i);
      signalPower += sample * sample;
    }
    signalPower /= ((pcmBytes.length - silenceEnd) / 2);

    if (noisePower <= 0) noisePower = 1.0;

    final snr = 10 * (math.log(signalPower / noisePower) / math.ln10);
    return snr.clamp(-20.0, 40.0);
  }

  /// Estimate SNR from WAV file
  double _estimateSnrFromWav(Uint8List wavBytes) {
    // Try to find data chunk
    int dataOffset = -1;
    int dataSize = 0;

    const dataChunkId = [0x64, 0x61, 0x74, 0x61]; // "data"

    for (int i = 8; i < wavBytes.length - 8; i++) {
      if (wavBytes[i] == dataChunkId[0] &&
          wavBytes[i + 1] == dataChunkId[1] &&
          wavBytes[i + 2] == dataChunkId[2] &&
          wavBytes[i + 3] == dataChunkId[3]) {
        dataOffset = i + 8;
        dataSize = _readInt32LE(wavBytes, i + 4);
        break;
      }
    }

    if (dataOffset < 0 || dataSize <= 0) {
      return 15.0; // Default
    }

    final endOffset = (dataOffset + dataSize).clamp(0, wavBytes.length);
    final audioBytes =
        wavBytes.sublist(dataOffset, endOffset.clamp(0, wavBytes.length));

    return _calculateSnrFromPcm(audioBytes);
  }

  /// Estimate noise level (0-1 normalized)
  double _estimateNoiseLevel(Uint8List pcmBytes) {
    if (pcmBytes.length < 40) return 0.2;

    // Calculate RMS from first part (silence)
    final silenceEnd = pcmBytes.length ~/ 10;
    double totalPower = 0.0;
    int sampleCount = 0;

    for (int i = 0; i < silenceEnd; i += 2) {
      if (i + 1 < pcmBytes.length) {
        final sample = _readInt16LE(pcmBytes, i);
        totalPower += sample * sample;
        sampleCount++;
      }
    }

    if (sampleCount == 0) return 0.2;

    final rmsPower = totalPower / sampleCount;
    final rms = math.sqrt(rmsPower);
    const maxInt16 = 32767.0;

    return (rms / maxInt16).clamp(0.0, 1.0);
  }

  /// Estimate noise from PCM
  double _estimateNoiseFromPcm(Uint8List pcmBytes) {
    return _estimateNoiseLevel(pcmBytes);
  }

  /// Read 16-bit signed integer (little-endian)
  int _readInt16LE(Uint8List bytes, int offset) {
    if (offset + 1 >= bytes.length) return 0;
    int value = bytes[offset] | (bytes[offset + 1] << 8);
    if (value >= 0x8000) {
      value -= 0x10000;
    }
    return value;
  }

  /// Read 32-bit signed integer (little-endian)
  int _readInt32LE(Uint8List bytes, int offset) {
    if (offset + 3 >= bytes.length) return 0;
    return bytes[offset] |
        (bytes[offset + 1] << 8) |
        (bytes[offset + 2] << 16) |
        (bytes[offset + 3] << 24);
  }

  /// Estimate bit error rate based on SNR
  /// Uses Shannon formula approximation
  double estimateBitErrorRate(double snrDb) {
    // Simple approximation: BER ≈ Q(sqrt(2*SNR))
    // where Q is the complementary error function
    final snrLinear = math.pow(10, snrDb / 10).toDouble();
    final erfc = _approximateErfc(math.sqrt(2 * snrLinear));
    return erfc / 2;
  }

  /// Approximate complementary error function
  double _approximateErfc(double x) {
    if (x > 5.0) return 0.0;
    // Abramowitz and Stegun approximation
    const double a1 = 0.254829592;
    const double a2 = -0.284496736;
    const double a3 = 1.421413741;
    const double a4 = -1.453152027;
    const double a5 = 1.061405429;
    const double p = 0.3275911;

    final sign = x < 0 ? -1 : 1;
    final absX = x.abs();

    final t = 1.0 / (1.0 + p * absX);
    final y = 1.0 -
        ((((a5 * t + a4) * t + a3) * t + a2) * t + a1) * t * math.exp(-x * x);

    return sign * y;
  }

  /// Recommend repetition factor based on SNR
  int recommendRepetitionFactor(double snrDb) {
    if (snrDb > 20.0) return 1;
    if (snrDb > 10.0) return 2;
    return 3;
  }

  /// Get channel condition historical analysis (placeholder for future)
  Future<ChannelStateEstimate> estimateAverageCondition(
    List<ChannelStateEstimate> measurements,
  ) async {
    if (measurements.isEmpty) {
      return ChannelStateEstimate(snrDb: 15.0, noiseLevel: 0.3);
    }

    final avgSnr = measurements.map((m) => m.snrDb).reduce((a, b) => a + b) /
        measurements.length;
    final avgNoise =
        measurements.map((m) => m.noiseLevel).reduce((a, b) => a + b) /
            measurements.length;

    return ChannelStateEstimate(
      snrDb: avgSnr,
      noiseLevel: avgNoise,
    );
  }
}
