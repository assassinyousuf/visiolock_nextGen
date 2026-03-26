import 'dart:io';
import 'dart:typed_data';
import '../models/file_metadata.dart';
import 'content_analyzer_service.dart';

/// Universal File Processor — Handles all file types with adaptive processing
///
/// Supports:
/// - Images: PNG, JPG, JPEG, BMP, GIF, WebP
/// - Text: TXT, JSON, XML, CSV, MD, Dart, JavaScript
/// - Documents: PDF
/// - Binary: Any other file type
class UniversalFileProcessor {
  final ContentAnalyzerService _analyzer = ContentAnalyzerService();

  /// Load and process any file type
  Future<FileData> loadFile(File file) async {
    if (!await file.exists()) {
      throw FileSystemException('File not found', file.path);
    }

    final metadata = await _analyzer.analyzeFile(file);
    final bytes = await file.readAsBytes();

    return FileData(
      metadata: metadata,
      rawBytes: bytes,
      file: file,
    );
  }

  /// Load multiple files of any type
  Future<List<FileData>> loadFiles(List<File> files) async {
    final results = <FileData>[];
    for (final file in files) {
      try {
        final data = await loadFile(file);
        results.add(data);
      } catch (e) {
        rethrow;
      }
    }
    return results;
  }

  /// Get recommended chunk size for streaming large files
  int getChunkSize(FileMetadata metadata) {
    return _analyzer.getRecommendedChunkSize(metadata);
  }

  /// Check if file should be processed in chunks
  bool shouldChunk(FileMetadata metadata) {
    return _analyzer.shouldChunk(metadata);
  }

  /// Extract metadata preview (first N bytes) for analysis
  Uint8List getPreview(Uint8List fileBytes, {int previewSize = 8192}) {
    final size = fileBytes.length < previewSize ? fileBytes.length : previewSize;
    return fileBytes.sublist(0, size);
  }

  /// Calculate file entropy for optimization purposes
  double calculateEntropy(Uint8List fileBytes) {
    return _analyzer.calculateEntropy(fileBytes);
  }

  /// Estimate compression ratio based on file entropy
  double estimateCompressionRatio(Uint8List fileBytes) {
    return _analyzer.estimateCompressionRatio(fileBytes);
  }

  /// Stream file in chunks (for large files)
  Stream<Uint8List> streamFile(
    File file, {
    int chunkSize = 65536, // 64 KB default
  }) async* {
    final inputStream = file.openRead();
    final buffer = <int>[];

    await for (final chunk in inputStream) {
      buffer.addAll(chunk);

      while (buffer.length >= chunkSize) {
        yield Uint8List.fromList(buffer.take(chunkSize).toList());
        buffer.removeRange(0, chunkSize);
      }
    }

    // Yield remaining bytes
    if (buffer.isNotEmpty) {
      yield Uint8List.fromList(buffer);
    }
  }

  /// Validate file integrity (basic check)
  bool validateFileIntegrity(FileData fileData) {
    if (fileData.rawBytes.isEmpty) return false;

    // Check minimum file size based on category
    switch (fileData.metadata.category) {
      case FileCategory.image:
        return fileData.rawBytes.length >= 100; // At least 100 bytes for image
      case FileCategory.text:
        return fileData.rawBytes.isNotEmpty; // Even empty text is valid
      case FileCategory.structured:
        return fileData.rawBytes.length >= 100; // PDF has structure
      case FileCategory.binary:
        return fileData.rawBytes.isNotEmpty; // Any size for binary
    }
  }

  /// Get file type-specific metadata
  Map<String, dynamic> getTypeSpecificMetadata(FileData fileData) {
    final metadata = {
      'fileName': fileData.metadata.fileName,
      'fileSize': fileData.metadata.fileSize,
      'category': fileData.metadata.category.toString(),
      'mimeType': fileData.metadata.mimeType,
      'timestamp': fileData.metadata.createdAt.toIso8601String(),
      'entropy': calculateEntropy(fileData.rawBytes),
    };

    // Add category-specific info
    switch (fileData.metadata.category) {
      case FileCategory.image:
        metadata.addAll({
          'type': 'image',
          'supportsCompression': true,
          'preferredEncryption': 'SAIC-ACT',
        });
        break;
      case FileCategory.text:
        metadata.addAll({
          'type': 'text',
          'supportsCompression': true,
          'preferredEncryption': 'AES-GCM',
          'isCompressible': true,
        });
        break;
      case FileCategory.structured:
        metadata.addAll({
          'type': 'document',
          'supportsCompression': true,
          'preferredEncryption': 'AES-GCM',
          'hasStructure': true,
        });
        break;
      case FileCategory.binary:
        metadata.addAll({
          'type': 'binary',
          'supportsCompression': false,
          'preferredEncryption': 'ChaCha20',
        });
        break;
    }

    return metadata;
  }

  /// Convert bytes to different encodings if needed
  String getDisplayName(FileMetadata metadata) {
    final sizeStr = _formatFileSize(metadata.fileSize);
    return '${metadata.fileName} ($sizeStr)';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// Container for loaded file data and metadata
class FileData {
  final FileMetadata metadata;
  final Uint8List rawBytes;
  final File file;
  final DateTime loadedAt;

  FileData({
    required this.metadata,
    required this.rawBytes,
    required this.file,
    DateTime? loadedAt,
  }) : loadedAt = loadedAt ?? DateTime.now();

  /// File size in KB (for AI model input)
  double get fileSizeKb => metadata.fileSize / 1024.0;

  /// Check if file is empty
  bool get isEmpty => rawBytes.isEmpty;

  /// Get human-readable size string
  String get sizeString {
    final bytes = metadata.fileSize;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  String toString() =>
      'FileData(name: ${metadata.fileName}, size: $sizeString, category: ${metadata.category})';
}
