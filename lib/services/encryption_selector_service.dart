import '../models/file_metadata.dart';
import '../models/channel_state.dart';

/// Enumeration of available encryption methods
enum EncryptionMethod {
  saicAct, // Spectrogram Adaptive Image Cipher for Acoustic Transmission
  aesGcm, // AES-256-GCM - standard authenticated encryption
  chaCha20, // ChaCha20-Poly1305 - modern stream cipher
  xorCrypto, // Lightweight XOR-based encryption
  hybridMode, // Combines multiple methods for enhanced security
}

/// Configuration for encryption selection
class EncryptionConfig {
  final EncryptionMethod method;
  final int keySize; // in bytes
  final String description;
  final List<FileCategory> supportedCategories;
  final double securityLevel; // 0.0 to 1.0
  final double performanceRating; // 0.0 to 1.0 (higher = faster)
  final bool supportsStreaming;
  final bool requiresAuthentication;

  EncryptionConfig({
    required this.method,
    required this.keySize,
    required this.description,
    required this.supportedCategories,
    required this.securityLevel,
    required this.performanceRating,
    required this.supportsStreaming,
    required this.requiresAuthentication,
  });
}

/// Encryption Selector Service — Intelligently selects optimal encryption based on context
class EncryptionSelectorService {
  static final Map<EncryptionMethod, EncryptionConfig> _configs = {
    EncryptionMethod.saicAct: EncryptionConfig(
      method: EncryptionMethod.saicAct,
      keySize: 32,
      description: 'SAIC-ACT - Spectrogram Adaptive Image Cipher',
      supportedCategories: [
        FileCategory.image,
        FileCategory.binary,
      ],
      securityLevel: 0.95,
      performanceRating: 0.85,
      supportsStreaming: false,
      requiresAuthentication: false,
    ),
    EncryptionMethod.aesGcm: EncryptionConfig(
      method: EncryptionMethod.aesGcm,
      keySize: 32,
      description: 'AES-256-GCM - Authenticated Encryption with Associated Data',
      supportedCategories: [
        FileCategory.image,
        FileCategory.text,
        FileCategory.structured,
        FileCategory.binary,
      ],
      securityLevel: 1.0,
      performanceRating: 0.9,
      supportsStreaming: true,
      requiresAuthentication: true,
    ),
    EncryptionMethod.chaCha20: EncryptionConfig(
      method: EncryptionMethod.chaCha20,
      keySize: 32,
      description: 'ChaCha20-Poly1305 - Modern Stream Cipher with Authentication',
      supportedCategories: [
        FileCategory.image,
        FileCategory.text,
        FileCategory.structured,
        FileCategory.binary,
      ],
      securityLevel: 0.98,
      performanceRating: 0.95,
      supportsStreaming: true,
      requiresAuthentication: true,
    ),
    EncryptionMethod.xorCrypto: EncryptionConfig(
      method: EncryptionMethod.xorCrypto,
      keySize: 32,
      description: 'Lightweight XOR-based Encryption',
      supportedCategories: [
        FileCategory.text,
        FileCategory.binary,
      ],
      securityLevel: 0.4,
      performanceRating: 1.0,
      supportsStreaming: true,
      requiresAuthentication: false,
    ),
    EncryptionMethod.hybridMode: EncryptionConfig(
      method: EncryptionMethod.hybridMode,
      keySize: 64,
      description: 'Hybrid Mode - Combines multiple encryption methods',
      supportedCategories: [
        FileCategory.image,
        FileCategory.text,
        FileCategory.structured,
        FileCategory.binary,
      ],
      securityLevel: 1.0,
      performanceRating: 0.75,
      supportsStreaming: false,
      requiresAuthentication: true,
    ),
  };

  /// Get available encryption methods for a specific file category
  List<EncryptionConfig> getAvailableEncryptions(FileCategory category) {
    return _configs.values
        .where((config) => config.supportedCategories.contains(category))
        .toList();
  }

  /// Select optimal encryption method based on file type and channel conditions
  EncryptionConfig selectOptimalEncryption(
    FileMetadata fileMetadata,
    ChannelStateEstimate channelState,
  ) {
    final available = getAvailableEncryptions(fileMetadata.category);

    if (available.isEmpty) {
      return _configs[EncryptionMethod.aesGcm]!;
    }

    // Scoring criteria based on file type and channel conditions
    double score(EncryptionConfig config) {
      double baseScore = 0.0;

      // For image files: prefer SAIC-ACT for acoustic optimization
      if (fileMetadata.category == FileCategory.image) {
        if (config.method == EncryptionMethod.saicAct) {
          baseScore += 0.4; // Strong preference for SAIC-ACT on images
        }
      }

      // Streaming support bonus for large files
      if (fileMetadata.fileSize > 5 * 1024 * 1024 && config.supportsStreaming) {
        baseScore += 0.3;
      }

      // Security level weight (40% of score)
      baseScore += config.securityLevel * 0.4;

      // Performance rating weight (30% of score)
      baseScore += config.performanceRating * 0.3;

      // Channel quality consideration
      if (channelState.snrDb > 20.0) {
        // Good channel: can afford slower but more secure method
        baseScore += config.securityLevel * 0.2;
      } else if (channelState.snrDb < 10.0) {
        // Poor channel: prefer faster method
        baseScore += config.performanceRating * 0.2;
      }

      return baseScore;
    }

    return available.reduce((current, next) {
      return score(current) > score(next) ? current : next;
    });
  }

  /// Get config for specific encryption method
  EncryptionConfig? getConfig(EncryptionMethod method) {
    return _configs[method];
  }

  /// Check if encryption method supports a file category
  bool supportsCategory(EncryptionMethod method, FileCategory category) {
    final config = _configs[method];
    return config != null && config.supportedCategories.contains(category);
  }

  /// Get all available encryption methods
  List<EncryptionConfig> getAllEncryptions() {
    return _configs.values.toList();
  }

  /// Get human-readable description for method
  String getDescription(EncryptionMethod method) {
    return _configs[method]?.description ?? 'Unknown encryption method';
  }

  /// Evaluate encryption suitability (0.0 = unsuitable, 1.0 = perfect)
  double evaluateSuitability(
    EncryptionMethod method,
    FileMetadata fileMetadata,
    ChannelStateEstimate channelState,
  ) {
    final config = _configs[method];
    if (config == null) return 0.0;

    if (!config.supportedCategories.contains(fileMetadata.category)) {
      return 0.1; // Penalize unsupported categories
    }

    double score = 0.0;

    // Category match
    if (fileMetadata.category == FileCategory.image &&
        method == EncryptionMethod.saicAct) {
      score += 0.3;
    }

    // Streaming capability
    if (fileMetadata.fileSize > 5 * 1024 * 1024) {
      score += config.supportsStreaming ? 0.25 : 0.0;
    }

    // Security level
    score += config.securityLevel * 0.25;

    // Performance
    score += config.performanceRating * 0.2;

    return score.clamp(0.0, 1.0);
  }
}
