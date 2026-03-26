import 'dart:typed_data';

/// I2A3++ Multi-File Frame Format
/// 
/// Structure:
/// | Header (12 bytes) | File Index (2) | File Count (2) | File Name Length (2) |
/// | File Name (N) | File Size (4) | Reserved (4) | Data |
///
class MultiFileFrame {
  static const int headerLength = 12;
  static const int frameVersion = 1;
  static const List<int> magicBytes = [0x49, 0x32, 0x41, 0x33]; // "I2A3"

  final int frameVersion_;
  final int fileIndex;
  final int fileCount;
  final String fileName;
  final int fileSize;
  final Uint8List fileData;
  final Uint8List? metadata;

  MultiFileFrame({
    required this.fileIndex,
    required this.fileCount,
    required this.fileName,
    required this.fileSize,
    required this.fileData,
    this.metadata,
    this.frameVersion_ = frameVersion,
  });

  /// Serialize frame to bytes
  Uint8List serialize() {
    final fileNameBytes = _stringToUtf8(fileName);
    final totalSize = headerLength +
        2 +
        2 +
        2 +
        fileNameBytes.length +
        4 +
        4 +
        fileData.length +
        (metadata?.length ?? 0);

    final buffer = Uint8List(totalSize);
    var offset = 0;

    // Magic bytes
    buffer.setAll(offset, magicBytes);
    offset += 4;

    // Version
    buffer[offset] = frameVersion_;
    offset += 1;

    // Reserved
    offset += 3;

    // File index
    _writeUint16BE(buffer, offset, fileIndex);
    offset += 2;

    // File count
    _writeUint16BE(buffer, offset, fileCount);
    offset += 2;

    // File name length
    _writeUint16BE(buffer, offset, fileNameBytes.length);
    offset += 2;

    // File name
    buffer.setAll(offset, fileNameBytes);
    offset += fileNameBytes.length;

    // File size
    _writeUint32BE(buffer, offset, fileSize);
    offset += 4;

    // Metadata length (or reserved)
    _writeUint32BE(buffer, offset, metadata?.length ?? 0);
    offset += 4;

    // File data
    buffer.setAll(offset, fileData);
    offset += fileData.length;

    // Metadata
    if (metadata != null) {
      buffer.setAll(offset, metadata!);
    }

    return buffer;
  }

  /// Deserialize from bytes
  static MultiFileFrame? deserialize(Uint8List bytes) {
    if (bytes.length < headerLength + 12) return null;

    var offset = 0;

    // Check magic bytes
    if (bytes[offset] != magicBytes[0] ||
        bytes[offset + 1] != magicBytes[1] ||
        bytes[offset + 2] != magicBytes[2] ||
        bytes[offset + 3] != magicBytes[3]) {
      return null;
    }
    offset += 4;

    // Version
    final version = bytes[offset];
    offset += 1;

    if (version != frameVersion) return null;

    // Skip reserved
    offset += 3;

    // File index
    final fileIndex = _readUint16BE(bytes, offset);
    offset += 2;

    // File count
    final fileCount = _readUint16BE(bytes, offset);
    offset += 2;

    // File name length
    final fileNameLen = _readUint16BE(bytes, offset);
    offset += 2;

    if (offset + fileNameLen + 8 > bytes.length) return null;

    // File name
    final fileNameBytes = bytes.sublist(offset, offset + fileNameLen);
    offset += fileNameLen;

    final fileName = _utf8ToString(fileNameBytes);

    // File size
    final fileSize = _readUint32BE(bytes, offset);
    offset += 4;

    // Metadata length
    final metadataLen = _readUint32BE(bytes, offset);
    offset += 4;

    // File data
    final fileDataLen = bytes.length - offset - metadataLen;
    if (fileDataLen < 0) return null;

    final fileData = bytes.sublist(offset, offset + fileDataLen);
    offset += fileDataLen;

    // Metadata
    final metadata =
        metadataLen > 0 ? bytes.sublist(offset, offset + metadataLen) : null;

    return MultiFileFrame(
      fileIndex: fileIndex,
      fileCount: fileCount,
      fileName: fileName,
      fileSize: fileSize,
      fileData: fileData,
      metadata: metadata,
      frameVersion_: version,
    );
  }

  // Utility functions
  static void _writeUint16BE(Uint8List bytes, int offset, int value) {
    bytes[offset] = (value >> 8) & 0xFF;
    bytes[offset + 1] = value & 0xFF;
  }

  static void _writeUint32BE(Uint8List bytes, int offset, int value) {
    bytes[offset] = (value >> 24) & 0xFF;
    bytes[offset + 1] = (value >> 16) & 0xFF;
    bytes[offset + 2] = (value >> 8) & 0xFF;
    bytes[offset + 3] = value & 0xFF;
  }

  static int _readUint16BE(Uint8List bytes, int offset) {
    return ((bytes[offset] & 0xFF) << 8) | (bytes[offset + 1] & 0xFF);
  }

  static int _readUint32BE(Uint8List bytes, int offset) {
    return ((bytes[offset] & 0xFF) << 24) |
        ((bytes[offset + 1] & 0xFF) << 16) |
        ((bytes[offset + 2] & 0xFF) << 8) |
        (bytes[offset + 3] & 0xFF);
  }

  static List<int> _stringToUtf8(String str) {
    return str.codeUnits;
  }

  static String _utf8ToString(Uint8List bytes) {
    return String.fromCharCodes(bytes);
  }

  @override
  String toString() =>
      'MultiFileFrame(index: $fileIndex/$fileCount, file: $fileName, size: $fileSize)';
}
