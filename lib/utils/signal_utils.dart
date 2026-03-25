import 'dart:math' as math;
import 'dart:typed_data';

class SignalUtils {
  static double goertzelPowerInt16({
    required Int16List samples,
    required int start,
    required int length,
    required int sampleRate,
    required double targetFrequencyHz,
  }) {
    if (length <= 0) {
      throw ArgumentError('length must be > 0');
    }
    if (start < 0 || start + length > samples.length) {
      throw RangeError('Invalid start/length for samples.');
    }

    final k = (0.5 + (length * targetFrequencyHz / sampleRate)).floor();
    final w = (2.0 * math.pi * k) / length;
    final cosine = math.cos(w);
    final coefficient = 2.0 * cosine;

    double q0 = 0.0;
    double q1 = 0.0;
    double q2 = 0.0;

    for (var i = 0; i < length; i++) {
      final sample = samples[start + i] / 32768.0;
      q0 = coefficient * q1 - q2 + sample;
      q2 = q1;
      q1 = q0;
    }

    return q1 * q1 + q2 * q2 - coefficient * q1 * q2;
  }
}
