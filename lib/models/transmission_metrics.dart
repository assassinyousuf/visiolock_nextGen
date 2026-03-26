class TransmissionMetrics {
  final double ber;
  final double latencyMs;
  final double successProbability;

  const TransmissionMetrics({
    required this.ber,
    required this.latencyMs,
    required this.successProbability,
  });

  bool get isSuccess => successProbability >= 0.85 && ber <= 0.02;
}
