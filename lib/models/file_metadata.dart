enum FileCategory {
  image,
  text,
  structured, // PDF, JSON
  binary,
}

enum EncodingStrategy {
  saicAct, // SAIC-ACT for images
  compressionLight, // compression-heavy + lightweight encryption
  entropyAware, // entropy-based encoding for binary
  chunkedStreaming, // for large files/video
}

class FileMetadata {
  final String fileName;
  final int fileSize;
  final FileCategory category;
  final String mimeType;
  final DateTime createdAt;

  FileMetadata({
    required this.fileName,
    required this.fileSize,
    required this.category,
    required this.mimeType,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  static FileCategory categorizeByExtension(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;

    // Image types
    if (['png', 'jpg', 'jpeg', 'bmp', 'gif', 'webp'].contains(ext)) {
      return FileCategory.image;
    }

    // Text types
    if (['txt', 'json', 'xml', 'csv', 'md', 'dart', 'js'].contains(ext)) {
      return FileCategory.text;
    }

    // Structured types
    if (['pdf'].contains(ext)) {
      return FileCategory.structured;
    }

    // Default to binary
    return FileCategory.binary;
  }

  static String mimeTypeFromExtension(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;

    const mimeMap = {
      'png': 'image/png',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'bmp': 'image/bmp',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'txt': 'text/plain',
      'json': 'application/json',
      'xml': 'application/xml',
      'csv': 'text/csv',
      'pdf': 'application/pdf',
      'md': 'text/markdown',
    };

    return mimeMap[ext] ?? 'application/octet-stream';
  }

  @override
  String toString() =>
      'FileMetadata(name: $fileName, size: $fileSize, category: $category)';
}
