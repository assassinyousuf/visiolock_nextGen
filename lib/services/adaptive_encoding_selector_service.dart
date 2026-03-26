
import '../models/file_metadata.dart';
import '../models/channel_state.dart';

/// Adaptive Encoding Selector — Selects optimal encoding based on content and channel
class AdaptiveEncodingSelectorService {
  /// Select encoding strategy based on file metadata and channel condition
  EncodingStrategy selectStrategy(
    FileMetadata metadata,
    ChannelStateEstimate channelState,
  ) {
    // Channel condition influences strategy selection for challenging conditions
    if (channelState.isPoor) {
      // For poor channels, prefer more robust encoding
      if (metadata.category == FileCategory.image) {
        return EncodingStrategy.saicAct; // SAIC-ACT is robust
      } else if (metadata.category == FileCategory.text) {
        return EncodingStrategy.compressionLight;
      }
    }

    // Primary selection by file category
    switch (metadata.category) {
      case FileCategory.image:
        return EncodingStrategy.saicAct;
      case FileCategory.text:
        return EncodingStrategy.compressionLight;
      case FileCategory.structured:
        return EncodingStrategy.entropyAware;
      case FileCategory.binary:
        if (metadata.fileSize > 10 * 1024 * 1024) {
          return EncodingStrategy.chunkedStreaming;
        } else {
          return EncodingStrategy.entropyAware;
        }
    }
  }

  /// Configure encoding parameters based on strategy
  Map<String, dynamic> configureEncodingParameters(
    EncodingStrategy strategy,
    ChannelStateEstimate channelState,
  ) {
    final baseConfig = _getBaseConfig(strategy);

    // Adjust based on channel condition
    if (channelState.isPoor) {
      baseConfig['redundancyLevel'] = 'high';
      baseConfig['checksumInterval'] = 1024; // More frequent checksums
    } else if (channelState.isMedium) {
      baseConfig['redundancyLevel'] = 'medium';
      baseConfig['checksumInterval'] = 2048;
    } else {
      baseConfig['redundancyLevel'] = 'low';
      baseConfig['checksumInterval'] = 4096;
    }

    return baseConfig;
  }

  // Private helper to get base configuration for each strategy
  Map<String, dynamic> _getBaseConfig(EncodingStrategy strategy) {
    switch (strategy) {
      case EncodingStrategy.saicAct:
        return {
          'name': 'SAIC-ACT',
          'description': 'Spectrogram Adaptive Image Cipher for Acoustic Transmission',
          'compressionLevel': 0,
          'encryptionRounds': 3,
          'permutationLayers': 1,
        };
      case EncodingStrategy.compressionLight:
        return {
          'name': 'Compression-Light',
          'description': 'Compression-heavy + lightweight encryption',
          'compressionLevel': 5,
          'encryptionRounds': 2,
          'useZlib': true,
        };
      case EncodingStrategy.entropyAware:
        return {
          'name': 'Entropy-Aware',
          'description': 'Entropy-based encoding for binary data',
          'entropyLimit': 7.5,
          'adaptiveBlockSize': true,
          'encryptionRounds': 2,
        };
      case EncodingStrategy.chunkedStreaming:
        return {
          'name': 'Chunked-Streaming',
          'description': 'Chunked processing for large files/video',
          'chunkSize': 512 * 1024,
          'streamingHeader': true,
          'checksumPerChunk': true,
        };
    }
  }

  /// Estimate data expansion ratio for the selected strategy
  double estimateExpansionRatio(
    FileMetadata metadata,
    EncodingStrategy strategy,
    int repetitionFactor,
  ) {
    // Base expansion from encoding
    double baseExpansion = _getBaseExpansion(strategy);

    // Add FEC overhead (typically 20-30% for RS(255,239))
    const double fecOverhead = 1.25;

    // Add repetition overhead
    final totalExpansion = baseExpansion * fecOverhead * repetitionFactor;

    return totalExpansion;
  }

  double _getBaseExpansion(EncodingStrategy strategy) {
    switch (strategy) {
      case EncodingStrategy.saicAct:
        // SAIC-ACT: 8 bits -> 1 symbol in audio (FSK modulation)
        // Roughly 12x expansion (depends on symbol rate)
        return 12.0;
      case EncodingStrategy.compressionLight:
        // Compression reduces size, but encryption adds overhead
        return 5.0;
      case EncodingStrategy.entropyAware:
        // Binary data: 8 bits -> 1 symbol
        return 12.0;
      case EncodingStrategy.chunkedStreaming:
        // Similar to binary with streaming overhead
        return 12.5;
    }
  }

  /// Optimize strategy based on available bandwidth and time constraints
  EncodingStrategy optimizeForConstraints({
    required FileMetadata metadata,
    required ChannelStateEstimate channelState,
    required double maxAudioDurationSeconds,
    required double bitRate,
  }) {
    final baseStrategy = selectStrategy(metadata, channelState);
    final expansion = estimateExpansionRatio(
      metadata,
      baseStrategy,
      channelState.isMedium ? 2 : (channelState.isPoor ? 3 : 1),
    );

    final estimatedAudioDuration =
        (metadata.fileSize * expansion) / (bitRate * 8);

    if (estimatedAudioDuration > maxAudioDurationSeconds) {
      // Need more aggressive compression
      if (metadata.category == FileCategory.binary ||
          metadata.category == FileCategory.structured) {
        return EncodingStrategy.compressionLight;
      }
    }

    return baseStrategy;
  }

  /// Calculate overall optimization score (0-100)
  double calculateOptimizationScore(
    FileMetadata metadata,
    EncodingStrategy strategy,
    ChannelStateEstimate channelState,
  ) {
    double score = 50.0;

    // Strategy appropriateness for content type
    final strategyMatch = _getStrategyAppropriatenessScore(
      metadata.category,
      strategy,
    );
    score += strategyMatch * 0.3;

    // Channel compatibility
    final channelCompat = _getChannelCompatibilityScore(
      strategy,
      channelState.condition,
    );
    score += channelCompat * 0.3;

    // Efficiency (considering expansion)
    final expansion =
        estimateExpansionRatio(metadata, strategy, channelState.isPoor ? 3 : 1);
    final efficiencyScore = (1.0 / expansion) * 100;
    score += (efficiencyScore / 100) * 0.4;

    return score.clamp(0.0, 100.0);
  }

  double _getStrategyAppropriatenessScore(
    FileCategory category,
    EncodingStrategy strategy,
  ) {
    switch (category) {
      case FileCategory.image:
        return strategy == EncodingStrategy.saicAct ? 50.0 : -20.0;
      case FileCategory.text:
        return strategy == EncodingStrategy.compressionLight ? 50.0 : 10.0;
      case FileCategory.structured:
        return strategy == EncodingStrategy.entropyAware ? 40.0 : 20.0;
      case FileCategory.binary:
        return (strategy == EncodingStrategy.entropyAware ||
                strategy == EncodingStrategy.chunkedStreaming)
            ? 40.0
            : 10.0;
    }
  }

  double _getChannelCompatibilityScore(
    EncodingStrategy strategy,
    ChannelCondition condition,
  ) {
    // SAIC-ACT is always robust
    if (strategy == EncodingStrategy.saicAct) {
      return 35.0;
    }

    // For poor channels, prefer robust strategies
    if (condition == ChannelCondition.poor) {
      return strategy == EncodingStrategy.saicAct ? 40.0 : 20.0;
    }

    // For good channels, all strategies work well
    return 30.0;
  }
}
