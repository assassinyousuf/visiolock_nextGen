import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/channel_state.dart';
import '../models/file_metadata.dart';
import 'encryption_selector_service.dart';
import 'universal_file_processor.dart';

/// Enhanced AI Transmission Service v2
///
/// Supports:
/// - Multiple file types (images, text, documents, binary)
/// - Multiple encryption methods
/// - Adaptive configuration based on channel conditions
/// - Fallback rule-based recommendations
class AiTransmissionServiceV2 {
  // Use 10.0.2.2 for Android Emulator, adjust for physical devices
  final String apiUrl;
  final bool useLocalApi;
  final String deviceIp;

  late final EncryptionSelectorService _encryptionSelector;
  late final UniversalFileProcessor _fileProcessor;

  static const Duration _timeout = Duration(seconds: 30);

  AiTransmissionServiceV2({
    String? customApiUrl,
    this.useLocalApi = true,
    this.deviceIp = '127.0.0.1:5000',
  })  : apiUrl = customApiUrl ??
            (useLocalApi
                ? Platform.isAndroid
                    ? 'http://10.0.2.2:5000/api'
                    : 'http://127.0.0.1:5000/api'
                : 'http://$deviceIp/api') {
    _encryptionSelector = EncryptionSelectorService();
    _fileProcessor = UniversalFileProcessor();
  }

  /// Get optimal transmission configuration for any file type
  Future<TransmissionConfig> getOptimalConfiguration({
    required FileData fileData,
    required ChannelStateEstimate channelState,
    EncryptionMethod? preferredEncryption,
  }) async {
    try {
      // Try to use online API first
      if (useLocalApi) {
        try {
          return await _getConfigurationFromApi(
            fileData: fileData,
            channelState: channelState,
            preferredEncryption: preferredEncryption,
          );
        } catch (e) {
          // Fallback to local
          return _getLocalConfiguration(
            fileData: fileData,
            channelState: channelState,
            preferredEncryption: preferredEncryption,
          );
        }
      }

      // Use local logic if API not enabled
      return _getLocalConfiguration(
        fileData: fileData,
        channelState: channelState,
        preferredEncryption: preferredEncryption,
      );
    } catch (e) {
      throw TransmissionConfigException('Failed to determine configuration: $e');
    }
  }

  /// Get configuration from remote API
  Future<TransmissionConfig> _getConfigurationFromApi({
    required FileData fileData,
    required ChannelStateEstimate channelState,
    EncryptionMethod? preferredEncryption,
  }) async {
    final request = {
      'file_type': _mapFileTypeToString(fileData.metadata.category),
      'file_size_kb': fileData.fileSizeKb,
      'snr': channelState.snrDb,
      'noise_level': channelState.noiseLevel,
      'encryption_method': preferredEncryption?.toString().split('.').last ?? 'auto',
    };

    try {
      final response = await http
          .post(
            Uri.parse('$apiUrl/predict'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(request),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return TransmissionConfig.fromJson(data, fileData.metadata);
      } else {
        throw Exception('API returned status ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('API request timed out after $_timeout');
    } catch (e) {
      rethrow;
    }
  }

  /// Get configuration using local intelligence
  TransmissionConfig _getLocalConfiguration({
    required FileData fileData,
    required ChannelStateEstimate channelState,
    EncryptionMethod? preferredEncryption,
  }) {
    // Select optimal transmission parameters based on file type and channel
    final encoding = _selectEncoding(fileData, channelState);
    final coding = _selectCoding(channelState);
    final modulation = _selectModulation(channelState);

    // Select encryption method
    final encryptionMethod = preferredEncryption ??
        _encryptionSelector
            .selectOptimalEncryption(fileData.metadata, channelState)
            .method;

    return TransmissionConfig(
      encoding: encoding,
      coding: coding,
      modulation: modulation,
      recommendedEncryption: encryptionMethod,
      fileMetadata: fileData.metadata,
      reasoning:
          'Local intelligence: Selected based on file type and channel SNR (${channelState.snrDb.toStringAsFixed(1)} dB)',
      sourceType: ConfigSourceType.local,
    );
  }

  /// Get encryption method recommendations
  Future<List<EncryptionRecommendation>> getEncryptionRecommendations({
    required FileData fileData,
    required ChannelStateEstimate channelState,
    String priority = 'balanced',
  }) async {
    try {
      if (useLocalApi) {
        try {
          final response = await http
              .post(
                Uri.parse('$apiUrl/recommend-encryption'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'file_type': _mapFileTypeToString(fileData.metadata.category),
                  'file_size_kb': fileData.fileSizeKb,
                  'snr': channelState.snrDb,
                  'noise_level': channelState.noiseLevel,
                  'priority': priority,
                }),
              )
              .timeout(_timeout);

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final recs = List<Map<String, dynamic>>.from(
              data['recommendations'] ?? [],
            );
            return recs
                .map((r) => EncryptionRecommendation.fromJson(r))
                .toList();
          }
        } catch (e) {
          // Silent fallback
        }
      }

      // Fallback to local recommendations
      return _getLocalEncryptionRecommendations(
        fileData: fileData,
        channelState: channelState,
        priority: priority,
      );
    } catch (e) {
      return _getLocalEncryptionRecommendations(
        fileData: fileData,
        channelState: channelState,
        priority: priority,
      );
    }
  }

  /// Get local encryption recommendations
  List<EncryptionRecommendation> _getLocalEncryptionRecommendations({
    required FileData fileData,
    required ChannelStateEstimate channelState,
    required String priority,
  }) {
    final available =
        _encryptionSelector.getAvailableEncryptions(fileData.metadata.category);
    final recommendations = <EncryptionRecommendation>[];

    for (final config in available) {
      double score = 0.0;

      // Priority-based scoring
      if (priority == 'security') {
        score = config.securityLevel * 0.7 + config.performanceRating * 0.3;
      } else if (priority == 'performance') {
        score = config.performanceRating * 0.7 + config.securityLevel * 0.3;
      } else {
        score = (config.securityLevel + config.performanceRating) / 2;
      }

      // Channel condition adjustment
      if (channelState.noiseLevel > 0.3) {
        score *= config.performanceRating;
      }
      if (channelState.snrDb < 10) {
        score *= 0.8;
      }

      recommendations.add(EncryptionRecommendation(
        method: config.method,
        score: score,
        reason:
            'Recommended for ${fileData.metadata.category.toString().split('.').last} files with $priority priority',
        securityLevel: config.securityLevel,
        performanceRating: config.performanceRating,
      ));
    }

    // Sort by score
    recommendations.sort((a, b) => b.score.compareTo(a.score));
    return recommendations;
  }

  /// Analyze file and get transmission parameters
  Future<FileAnalysisResult> analyzeFile(FileData fileData) async {
    try {
      if (useLocalApi) {
        try {
          final response = await http
              .post(
                Uri.parse('$apiUrl/analyze-file'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'file_name': fileData.metadata.fileName,
                  'file_size_kb': fileData.fileSizeKb,
                  'snr': 15.0, // Default SNR
                  'noise_level': 0.1, // Default noise level
                }),
              )
              .timeout(_timeout);

          if (response.statusCode == 200) {
            return FileAnalysisResult.fromJson(
              jsonDecode(response.body),
              fileData.metadata,
            );
          }
        } catch (e) {
          // Silent fallback
        }
      }

      // Fallback local analysis
      return FileAnalysisResult(
        fileName: fileData.metadata.fileName,
        fileType: _mapFileTypeToString(fileData.metadata.category),
        fileSize: fileData.metadata.fileSize,
        estimatedTransmissionTime: _estimateTransmissionTime(fileData.fileSizeKb),
        entropy: _fileProcessor.calculateEntropy(fileData.rawBytes),
        metadata: fileData.metadata,
      );
    } catch (e) {
      // Re-throw
      rethrow;
    }
  }

  // ─────────────────────────────── Helper methods

  String _mapFileTypeToString(FileCategory category) {
    switch (category) {
      case FileCategory.image:
        return 'image';
      case FileCategory.text:
        return 'text';
      case FileCategory.structured:
        return 'document';
      case FileCategory.binary:
        return 'binary';
    }
  }

  String _selectEncoding(FileData fileData, ChannelStateEstimate channel) {
    if (fileData.metadata.category == FileCategory.image) {
      return 'SAIC-ACT';
    }
    if (fileData.metadata.category == FileCategory.text) {
      return 'DEFLATE';
    }
    return 'Binary-Optimal';
  }

  String _selectCoding(ChannelStateEstimate channel) {
    if (channel.snrDb > 20) {
      return 'Turbo';
    } else if (channel.snrDb > 12) {
      return 'RS';
    } else if (channel.snrDb > 5) {
      return 'ConvCode';
    } else {
      return 'Repetition';
    }
  }

  String _selectModulation(ChannelStateEstimate channel) {
    if (channel.snrDb > 20) {
      return '64-QAM';
    } else if (channel.snrDb > 12) {
      return '16-QAM';
    } else if (channel.snrDb > 5) {
      return 'QPSK';
    } else {
      return 'BPSK';
    }
  }

  double _estimateTransmissionTime(double fileSizeKb) {
    const baseRate = 10.0; // kbps
    return fileSizeKb / baseRate;
  }

  /// Check API health
  Future<bool> checkApiHealth() async {
    try {
      final response =
          await http.get(Uri.parse('$apiUrl/health')).timeout(_timeout);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

// ─────────────────────────────── Data classes

enum ConfigSourceType { api, local }

class TransmissionConfig {
  final String encoding;
  final String coding;
  final String modulation;
  final EncryptionMethod recommendedEncryption;
  final FileMetadata fileMetadata;
  final String reasoning;
  final ConfigSourceType sourceType;
  final DateTime calculatedAt;

  TransmissionConfig({
    required this.encoding,
    required this.coding,
    required this.modulation,
    required this.recommendedEncryption,
    required this.fileMetadata,
    required this.reasoning,
    required this.sourceType,
    DateTime? calculatedAt,
  }) : calculatedAt = calculatedAt ?? DateTime.now();

  static TransmissionConfig fromJson(
    Map<String, dynamic> json,
    FileMetadata metadata,
  ) {
    return TransmissionConfig(
      encoding: json['encoding'] ?? 'default',
      coding: json['coding'] ?? 'RS',
      modulation: json['modulation'] ?? '16-QAM',
      recommendedEncryption:
          _parseEncryptionMethod(json['recommended_encryption']),
      fileMetadata: metadata,
      reasoning: json['reasoning'] ?? 'No reasoning provided',
      sourceType: ConfigSourceType.api,
    );
  }

  static EncryptionMethod _parseEncryptionMethod(String? method) {
    switch (method?.toLowerCase()) {
      case 'saic-act':
      case 'saicact':
        return EncryptionMethod.saicAct;
      case 'aes-256-gcm':
      case 'aesgcm':
        return EncryptionMethod.aesGcm;
      case 'chacha20-poly1305':
      case 'chacha20poly1305':
        return EncryptionMethod.chaCha20;
      case 'xor-crypto':
      case 'xorcrypto':
        return EncryptionMethod.xorCrypto;
      default:
        return EncryptionMethod.aesGcm;
    }
  }

  @override
  String toString() =>
      'TransmissionConfig(E: $encoding, C: $coding, M: $modulation, Enc: $recommendedEncryption)';
}

class EncryptionRecommendation {
  final EncryptionMethod method;
  final double score;
  final String reason;
  final double securityLevel;
  final double performanceRating;

  EncryptionRecommendation({
    required this.method,
    required this.score,
    required this.reason,
    required this.securityLevel,
    required this.performanceRating,
  });

  static EncryptionRecommendation fromJson(Map<String, dynamic> json) {
    return EncryptionRecommendation(
      method: _parseMethod(json['method']),
      score: (json['score'] ?? 0.0).toDouble(),
      reason: json['reason'] ?? '',
      securityLevel: (json['security_level'] ?? 0.5).toDouble(),
      performanceRating: (json['performance'] ?? 0.5).toDouble(),
    );
  }

  static EncryptionMethod _parseMethod(String? method) {
    switch (method?.toLowerCase()) {
      case 'saic-act':
        return EncryptionMethod.saicAct;
      case 'aes-256-gcm':
        return EncryptionMethod.aesGcm;
      case 'chacha20-poly1305':
        return EncryptionMethod.chaCha20;
      case 'xor-crypto':
        return EncryptionMethod.xorCrypto;
      default:
        return EncryptionMethod.aesGcm;
    }
  }
}

class FileAnalysisResult {
  final String fileName;
  final String fileType;
  final int fileSize;
  final double estimatedTransmissionTime;
  final double entropy;
  final FileMetadata metadata;

  FileAnalysisResult({
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.estimatedTransmissionTime,
    required this.entropy,
    required this.metadata,
  });

  static FileAnalysisResult fromJson(
    Map<String, dynamic> json,
    FileMetadata metadata,
  ) {
    return FileAnalysisResult(
      fileName: json['file_name'],
      fileType: json['file_type'],
      fileSize: json['file_size_kb'],
      estimatedTransmissionTime:
          (json['estimated_transmission_time'] ?? 0.0).toDouble(),
      entropy: (json['entropy'] ?? 0.0).toDouble(),
      metadata: metadata,
    );
  }
}

class TransmissionConfigException implements Exception {
  final String message;
  TransmissionConfigException(this.message);

  @override
  String toString() => 'TransmissionConfigException: $message';
}
