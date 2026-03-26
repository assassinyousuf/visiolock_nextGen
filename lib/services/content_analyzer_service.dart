import 'dart:io';
import 'dart:typed_data';

import '../models/file_metadata.dart';

/// Content-Aware Analyzer — Detects file type and selects optimal encoding strategy.
class ContentAnalyzerService {
  /// Analyzes file and returns metadata with optimal encoding strategy
  Future<FileMetadata> analyzeFile(File file) async {
    final fileName = file.path.split(Platform.pathSeparator).last;
    final fileSize = await file.length();
    final category = FileMetadata.categorizeByExtension(fileName);
    final mimeType = FileMetadata.mimeTypeFromExtension(fileName);

    return FileMetadata(
      fileName: fileName,
      fileSize: fileSize,
      category: category,
      mimeType: mimeType,
    );
  }

  /// Analyzes multiple files
  Future<List<FileMetadata>> analyzeFiles(List<File> files) async {
    final results = <FileMetadata>[];
    for (final file in files) {
      final metadata = await analyzeFile(file);
      results.add(metadata);
    }
    return results;
  }

  /// Select encoding strategy based on detection
  EncodingStrategy selectEncodingStrategy(FileMetadata metadata) {
    switch (metadata.category) {
      case FileCategory.image:
        return EncodingStrategy.saicAct;
      case FileCategory.text:
        return EncodingStrategy.compressionLight;
      case FileCategory.structured:
        return EncodingStrategy.entropyAware;
      case FileCategory.binary:
        return metadata.fileSize > 10 * 1024 * 1024
            ? EncodingStrategy.chunkedStreaming
            : EncodingStrategy.entropyAware;
    }
  }

  /// Analyze data entropy (for binary detection)
  double calculateEntropy(Uint8List data) {
    if (data.isEmpty) return 0.0;

    final frequency = <int, int>{};
    for (final byte in data) {
      frequency[byte] = (frequency[byte] ?? 0) + 1;
    }

    double entropy = 0.0;
    final len = data.length;
    for (final count in frequency.values) {
      final probability = count / len;
      entropy -= probability * (log2(probability));
    }

    return entropy;
  }

  /// Helper: log base 2
  static double log2(double x) {
    return log(x) / log(2);
  }

  static double log(double x) {
    if (x <= 0) return 0;
    // Natural log using Dart's math
    return _ln(x);
  }

  static double _ln(double x) {
    if (x <= 0) return 0;
    // Mathematical approximation of natural log
    double result = 2 * (x - 1) / (x + 1);
    double x2 = result * result;
    double sum = result;
    for (int i = 1; i < 10; i++) {
      result *= x2;
      sum += result / (2 * i + 1);
    }
    return 2 * sum;
  }

  /// Estimate entropy-based compression potential
  double estimateCompressionRatio(Uint8List data) {
    final entropy = calculateEntropy(data);
    // If entropy is high (8.0), compression potential is low (ratio ~1.0)
    // If entropy is low (2.0), compression potential is high (ratio ~0.25)
    return entropy / 8.0;
  }

  /// Determine if file should use chunked streaming
  bool shouldChunk(FileMetadata metadata) {
    return metadata.category == FileCategory.binary &&
        metadata.fileSize > 10 * 1024 * 1024;
  }

  /// Get recommended chunk size based on file metadata
  int getRecommendedChunkSize(FileMetadata metadata) {
    if (!shouldChunk(metadata)) {
      return metadata.fileSize;
    }

    // Vary chunk size based on file type
    switch (metadata.category) {
      case FileCategory.image:
        return 512 * 1024; // 512 KB for images
      case FileCategory.text:
        return 256 * 1024; // 256 KB for text
      case FileCategory.structured:
        return 1024 * 1024; // 1 MB for structured data
      case FileCategory.binary:
        return 2 * 1024 * 1024; // 2 MB for binary
    }
  }
}
