import 'dart:io';

import '../models/file_metadata.dart';
import '../models/channel_state.dart';
import 'content_analyzer_service.dart';
import 'adaptive_encoding_selector_service.dart';
import 'channel_state_estimator_service.dart';

/// Adaptive Transmission System — Orchestrates content analysis, encoding selection, and channel adaptation
///
/// Algorithm 1: Adaptive Cross-Media Transmission
///
/// Input: File F, Type T, Size S, Channel SNR γ
/// Output: Optimal Encoding Strategy E, Coding Scheme C, Modulation M
///
/// 1: γ ← EstimateChannelSNR()
/// 2: category ← ClassifyFileType(T)
/// 3: E ← SelectEncodingStrategy(category, γ)
/// 4: C ← SelectCodingScheme(γ)
/// 5: M ← SelectModulation(γ)
/// 6: return (E, C, M)
///
class AdaptiveTransmissionSystem {
  final ContentAnalyzerService _contentAnalyzer;
  final AdaptiveEncodingSelectorService _encodingSelector;
  final ChannelStateEstimatorService _channelEstimator;

  AdaptiveTransmissionSystem({
    ContentAnalyzerService? contentAnalyzer,
    AdaptiveEncodingSelectorService? encodingSelector,
    ChannelStateEstimatorService? channelEstimator,
  })  : _contentAnalyzer = contentAnalyzer ?? ContentAnalyzerService(),
        _encodingSelector =
            encodingSelector ?? AdaptiveEncodingSelectorService(),
        _channelEstimator =
            channelEstimator ?? const ChannelStateEstimatorService();

  /// Analyze and compute adaptive transmission parameters for a file
  Future<AdaptiveTransmissionPlan> computeTransmissionPlan(
    File sourceFile, {
    ChannelStateEstimate? channelEstimate,
  }) async {
    // Step 1: Analyze file content
    final fileMetadata = await _contentAnalyzer.analyzeFile(sourceFile);

    // Step 2: Estimate channel condition (if not provided)
    final channel = channelEstimate ??
        ChannelStateEstimate(
          snrDb: 15.0,
          noiseLevel: 0.3,
        );

    // Step 3: Select encoding strategy
    final encodingStrategy =
        _encodingSelector.selectStrategy(fileMetadata, channel);

    // Step 4: Select coding scheme
    final codingScheme = AdaptiveCodingScheme.forChannel(channel.condition);

    // Step 5: Select modulation parameters
    final modulationParams =
        AdaptiveModulationParameters.forChannel(channel.condition);

    // Step 6: Calculate expansion ratio
    final expansionRatio = _encodingSelector.estimateExpansionRatio(
      fileMetadata,
      encodingStrategy,
      codingScheme.repetitionFactor,
    );

    // Step 7: Calculate optimization score
    final optimizationScore = _encodingSelector.calculateOptimizationScore(
      fileMetadata,
      encodingStrategy,
      channel,
    );

    return AdaptiveTransmissionPlan(
      fileMetadata: fileMetadata,
      channelEstimate: channel,
      encodingStrategy: encodingStrategy,
      codingScheme: codingScheme,
      modulationParameters: modulationParams,
      expectedExpansionRatio: expansionRatio,
      optimizationScore: optimizationScore,
    );
  }

  /// Compute transmission plans for multiple files
  Future<List<AdaptiveTransmissionPlan>> computeTransmissionPlansForFiles(
    List<File> sourceFiles, {
    ChannelStateEstimate? channelEstimate,
  }) async {
    final plans = <AdaptiveTransmissionPlan>[];
    for (final file in sourceFiles) {
      final plan = await computeTransmissionPlan(
        file,
        channelEstimate: channelEstimate,
      );
      plans.add(plan);
    }
    return plans;
  }

  /// Analyze multiple files and return aggregated recommendations
  Future<AggregatedTransmissionPlan> analyzeMultipleFiles(
    List<File> files, {
    ChannelStateEstimate? channelEstimate,
  }) async {
    final plans = await computeTransmissionPlansForFiles(
      files,
      channelEstimate: channelEstimate,
    );

    final totalDataSize =
        plans.map((p) => p.fileMetadata.fileSize).fold<int>(0, (a, b) => a + b);
    final expectedTotalExpansion = plans
        .map((p) => p.fileMetadata.fileSize * p.expectedExpansionRatio)
        .fold<double>(0, (a, b) => a + b);

    final avgOptimizationScore =
        plans.map((p) => p.optimizationScore).reduce((a, b) => a + b) /
            plans.length;

    // Recommended channel adaptation if any file has poor conditions
    final hasHighRiskFiles =
        plans.any((p) => p.channelEstimate.isPoor);
    final recommendmentAdaptiveChannelTuning = hasHighRiskFiles;

    return AggregatedTransmissionPlan(
      plans: plans,
      totalDataSize: totalDataSize,
      expectedTotalAudioSize: expectedTotalExpansion.toInt(),
      averageOptimizationScore: avgOptimizationScore,
      recommendAdaptiveChannelTuning: recommendmentAdaptiveChannelTuning,
      channel: channelEstimate,
    );
  }

  /// Get real-time channel adaptation recommendations based on current SNR
  ChannelAdaptationRecommendation getChannelAdaptationRecommendation(
    double snrDb,
  ) {
    final estimate = ChannelStateEstimate(
      snrDb: snrDb,
      noiseLevel: 0.0, // Will be estimated properly later
    );

    return ChannelAdaptationRecommendation(
      current: estimate,
      codingScheme: AdaptiveCodingScheme.forChannel(estimate.condition),
      modulationParameters:
          AdaptiveModulationParameters.forChannel(estimate.condition),
      bitErrorRateEstimate:
          _channelEstimator.estimateBitErrorRate(snrDb),
      recommendedRepetitionFactor:
          _channelEstimator.recommendRepetitionFactor(snrDb),
    );
  }
}

/// Result of transmission plan computation
class AdaptiveTransmissionPlan {
  final FileMetadata fileMetadata;
  final ChannelStateEstimate channelEstimate;
  final EncodingStrategy encodingStrategy;
  final AdaptiveCodingScheme codingScheme;
  final AdaptiveModulationParameters modulationParameters;
  final double expectedExpansionRatio;
  final double optimizationScore;

  AdaptiveTransmissionPlan({
    required this.fileMetadata,
    required this.channelEstimate,
    required this.encodingStrategy,
    required this.codingScheme,
    required this.modulationParameters,
    required this.expectedExpansionRatio,
    required this.optimizationScore,
  });

  int get expectedAudioSizeBytes =>
      (fileMetadata.fileSize * expectedExpansionRatio).toInt();

  @override
  String toString() => '''
AdaptiveTransmissionPlan(
  file: ${fileMetadata.fileName}
  strategy: $encodingStrategy
  coding: $codingScheme
  modulation: $modulationParameters
  expansion: ${expectedExpansionRatio.toStringAsFixed(2)}x
  score: ${optimizationScore.toStringAsFixed(1)}/100
)''';
}

/// Aggregated analysis for multiple files
class AggregatedTransmissionPlan {
  final List<AdaptiveTransmissionPlan> plans;
  final int totalDataSize;
  final int expectedTotalAudioSize;
  final double averageOptimizationScore;
  final bool recommendAdaptiveChannelTuning;
  final ChannelStateEstimate? channel;

  AggregatedTransmissionPlan({
    required this.plans,
    required this.totalDataSize,
    required this.expectedTotalAudioSize,
    required this.averageOptimizationScore,
    required this.recommendAdaptiveChannelTuning,
    this.channel,
  });

  double get aggregateExpansionRatio =>
      expectedTotalAudioSize / totalDataSize;

  @override
  String toString() => '''
AggregatedTransmissionPlan(
  files: ${plans.length}
  totalOriginalSize: $totalDataSize bytes
  expectedAudioSize: $expectedTotalAudioSize bytes
  aggregateExpansion: ${aggregateExpansionRatio.toStringAsFixed(2)}x
  avgOptimization: ${averageOptimizationScore.toStringAsFixed(1)}/100
  adaptiveChannelTuningNeeded: $recommendAdaptiveChannelTuning
)''';
}

/// Channel adaptation recommendation
class ChannelAdaptationRecommendation {
  final ChannelStateEstimate current;
  final AdaptiveCodingScheme codingScheme;
  final AdaptiveModulationParameters modulationParameters;
  final double bitErrorRateEstimate;
  final int recommendedRepetitionFactor;

  ChannelAdaptationRecommendation({
    required this.current,
    required this.codingScheme,
    required this.modulationParameters,
    required this.bitErrorRateEstimate,
    required this.recommendedRepetitionFactor,
  });

  @override
  String toString() => '''
ChannelAdaptationRecommendation(
  SNR: ${current.snrDb.toStringAsFixed(2)} dB
  Condition: ${current.condition}
  Coding: $codingScheme
  Modulation: $modulationParameters
  EstimatedBER: ${bitErrorRateEstimate.toStringAsFixed(2)}
  RepetitionFactor: $recommendedRepetitionFactor
)''';
}
