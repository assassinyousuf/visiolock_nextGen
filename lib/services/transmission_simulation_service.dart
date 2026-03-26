import 'dart:math';

import '../models/channel_state.dart';
import '../models/encoding_payload.dart';
import '../models/model_prediction.dart';
import '../models/transmission_metrics.dart';

class TransmissionSimulationService {
  TransmissionMetrics simulate({
    required EncodingPayload payload,
    required ChannelStateEstimate channel,
    required ModelPrediction prediction,
  }) {
    final snrFactor = max(1.0, channel.snrDb);
    final noisePenalty = 1.0 + channel.noiseLevel * 3.5;
    final modulationPenalty = 1.0 + prediction.modulationClass * 0.3;

    final ber = (noisePenalty * modulationPenalty / (snrFactor * 120)).clamp(0.0001, 0.25);

    final payloadKb = payload.pseudoEncryptedBytes.length / 1024.0;
    final codingMultiplier = [1.0, 1.6, 2.2][prediction.codingClass.clamp(0, 2)];
    final latencyMs = (40 + (payloadKb * 1.8 * codingMultiplier) + (channel.noiseLevel * 120)).clamp(15, 8000).toDouble();

    final successProbability = (1.0 - (ber * 2.4) - (latencyMs / 12000)).clamp(0.0, 1.0);

    return TransmissionMetrics(
      ber: ber,
      latencyMs: latencyMs,
      successProbability: successProbability,
    );
  }
}
