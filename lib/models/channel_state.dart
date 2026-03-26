enum ChannelCondition {
  good,
  medium,
  poor,
}

class ChannelStateEstimate {
  final double snrDb;
  final ChannelCondition condition;
  final double noiseLevel;
  final DateTime estimatedAt;

  ChannelStateEstimate({
    required this.snrDb,
    required this.noiseLevel,
    DateTime? estimatedAt,
  })  : condition = _categorizeSnr(snrDb),
        estimatedAt = estimatedAt ?? DateTime.now();

  static ChannelCondition _categorizeSnr(double snr) {
    if (snr > 20.0) {
      return ChannelCondition.good;
    } else if (snr >= 10.0) {
      return ChannelCondition.medium;
    } else {
      return ChannelCondition.poor;
    }
  }

  bool get isGood => condition == ChannelCondition.good;
  bool get isMedium => condition == ChannelCondition.medium;
  bool get isPoor => condition == ChannelCondition.poor;

  @override
  String toString() =>
      'ChannelStateEstimate(SNR: ${snrDb.toStringAsFixed(2)} dB, Condition: $condition, Noise: ${noiseLevel.toStringAsFixed(2)})';
}

class AdaptiveModulationParameters {
  final int symbolDurationMs;
  final double frequencyGapHz;
  final String modulationType;

  const AdaptiveModulationParameters({
    required this.symbolDurationMs,
    required this.frequencyGapHz,
    required this.modulationType,
  });

  factory AdaptiveModulationParameters.forChannel(ChannelCondition condition) {
    switch (condition) {
      case ChannelCondition.good:
        return const AdaptiveModulationParameters(
          symbolDurationMs: 1,
          frequencyGapHz: 500.0,
          modulationType: 'FSK-Narrow',
        );
      case ChannelCondition.medium:
        return const AdaptiveModulationParameters(
          symbolDurationMs: 2,
          frequencyGapHz: 1000.0,
          modulationType: 'FSK-Medium',
        );
      case ChannelCondition.poor:
        return const AdaptiveModulationParameters(
          symbolDurationMs: 4,
          frequencyGapHz: 2000.0,
          modulationType: 'FSK-Wide',
        );
    }
  }

  @override
  String toString() =>
      'ModulationParams(duration: ${symbolDurationMs}ms, gap: ${frequencyGapHz}Hz, type: $modulationType)';
}

class AdaptiveCodingScheme {
  final String scheme;
  final int repetitionFactor;
  final String description;

  const AdaptiveCodingScheme({
    required this.scheme,
    required this.repetitionFactor,
    required this.description,
  });

  factory AdaptiveCodingScheme.forChannel(ChannelCondition condition) {
    switch (condition) {
      case ChannelCondition.good:
        return const AdaptiveCodingScheme(
          scheme: 'RS(255,239)',
          repetitionFactor: 1,
          description: 'Reed-Solomon only (no repetition)',
        );
      case ChannelCondition.medium:
        return const AdaptiveCodingScheme(
          scheme: 'RS(255,239)+Rep2',
          repetitionFactor: 2,
          description: 'Reed-Solomon with 2x repetition',
        );
      case ChannelCondition.poor:
        return const AdaptiveCodingScheme(
          scheme: 'RS(255,239)+Rep3',
          repetitionFactor: 3,
          description: 'Reed-Solomon with 3x repetition',
        );
    }
  }

  @override
  String toString() =>
      'CodingScheme($scheme, rep: $repetitionFactor, $description)';
}
