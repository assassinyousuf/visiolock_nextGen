import 'dart:io';
import 'dart:typed_data';

import '../models/multi_file_frame.dart';

/// Multi-File Framing Service — Manages I2A3++ frame format for multi-file support
class MultiFileFramingService {
  /// Create frames from a list of files
  Future<List<MultiFileFrame>> createFramesFromFiles(
    List<File> files,
  ) async {
    final frames = <MultiFileFrame>[];
    final fileCount = files.length;

    for (int i = 0; i < files.length; i++) {
      final fileData = await files[i].readAsBytes();
      final fileName = files[i].path.split(Platform.pathSeparator).last;

      final frame = MultiFileFrame(
        fileIndex: i,
        fileCount: fileCount,
        fileName: fileName,
        fileSize: fileData.length,
        fileData: fileData,
        metadata: _createMetadata(fileName, fileData.length),
      );

      frames.add(frame);
    }

    return frames;
  }

  /// Combine multiple frames back into files
  Future<List<File>> reconstructFilesFromFrames(
    List<MultiFileFrame> frames,
    String outputDirectory,
  ) async {
    final reconstructed = <File>[];

    for (final frame in frames) {
      final filePath = '$outputDirectory${Platform.pathSeparator}${frame.fileName}';
      final file = File(filePath);

      // Create parent directory if needed
      await file.parent.create(recursive: true);

      // Write file data
      await file.writeAsBytes(frame.fileData);
      reconstructed.add(file);
    }

    return reconstructed;
  }

  /// Serialize all frames into a single byte stream (with frame markers)
  Uint8List serializeFrames(List<MultiFileFrame> frames) {
    final builder = BytesBuilder();

    for (final frame in frames) {
      final frameBytes = frame.serialize();

      // Write frame length (big-endian 32-bit)
      final lengthBytes = Uint8List(4);
      lengthBytes[0] = (frameBytes.length >> 24) & 0xFF;
      lengthBytes[1] = (frameBytes.length >> 16) & 0xFF;
      lengthBytes[2] = (frameBytes.length >> 8) & 0xFF;
      lengthBytes[3] = frameBytes.length & 0xFF;

      builder.add(lengthBytes);
      builder.add(frameBytes);
    }

    return builder.toBytes();
  }

  /// Deserialize frames from a byte stream
  List<MultiFileFrame> deserializeFrames(Uint8List data) {
    final frames = <MultiFileFrame>[];
    int offset = 0;

    while (offset + 4 <= data.length) {
      // Read frame length
      final length = ((data[offset] & 0xFF) << 24) |
          ((data[offset + 1] & 0xFF) << 16) |
          ((data[offset + 2] & 0xFF) << 8) |
          (data[offset + 3] & 0xFF);

      offset += 4;

      if (offset + length > data.length) {
        break;
      }

      // Extract and deserialize frame
      final frameData = data.sublist(offset, offset + length);
      final frame = MultiFileFrame.deserialize(frameData);

      if (frame != null) {
        frames.add(frame);
      }

      offset += length;
    }

    return frames;
  }

  /// Create metadata about the frame (file info, timestamps, etc.)
  Uint8List _createMetadata(String fileName, int fileSize) {
    final builder = BytesBuilder();

    // Timestamp (8 bytes, milliseconds since epoch)
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    builder.add([
      (timestamp >> 56) & 0xFF,
      (timestamp >> 48) & 0xFF,
      (timestamp >> 40) & 0xFF,
      (timestamp >> 32) & 0xFF,
      (timestamp >> 24) & 0xFF,
      (timestamp >> 16) & 0xFF,
      (timestamp >> 8) & 0xFF,
      timestamp & 0xFF,
    ]);

    // CRC32-like checksum of filename
    final fileNameBytes = fileName.codeUnits;
    int checksum = 0;
    for (final byte in fileNameBytes) {
      checksum = ((checksum << 1) ^ byte) & 0xFFFFFFFF;
    }
    builder.add([
      (checksum >> 24) & 0xFF,
      (checksum >> 16) & 0xFF,
      (checksum >> 8) & 0xFF,
      checksum & 0xFF,
    ]);

    return builder.toBytes();
  }

  /// Calculate total size of all frames when serialized
  int calculateSerializedSize(List<MultiFileFrame> frames) {
    int total = 0;
    for (final frame in frames) {
      total += 4; // Frame length prefix
      total += frame.serialize().length;
    }
    return total;
  }

  /// Validate frames have matching counts
  bool validateFrameSequence(List<MultiFileFrame> frames) {
    if (frames.isEmpty) return false;

    final expectedCount = frames.first.fileCount;
    if (frames.length != expectedCount) return false;

    // Check indices are sequential
    for (int i = 0; i < frames.length; i++) {
      if (frames[i].fileIndex != i) return false;
    }

    return true;
  }

  /// Merge multiple frame lists into one (useful for batch operations)
  List<MultiFileFrame> mergeFrames(
    List<List<MultiFileFrame>> frameLists,
  ) {
    final merged = <MultiFileFrame>[];
    int globalIndex = 0;

    for (final frames in frameLists) {
      for (final frame in frames) {
        merged.add(MultiFileFrame(
          fileIndex: globalIndex,
          fileCount: frameLists.fold<int>(
            0,
            (prev, list) => prev + list.length,
          ),
          fileName: frame.fileName,
          fileSize: frame.fileSize,
          fileData: frame.fileData,
          metadata: frame.metadata,
        ));
        globalIndex++;
      }
    }

    return merged;
  }

  /// Get summary of frames
  FrameSetSummary summarizeFrames(List<MultiFileFrame> frames) {
    int totalSize = 0;
    int serializeSize = 0;
    final fileNames = <String>[];

    for (final frame in frames) {
      totalSize += frame.fileSize;
      serializeSize += frame.serialize().length;
      fileNames.add(frame.fileName);
    }

    return FrameSetSummary(
      fileCount: frames.length,
      totalDataSize: totalSize,
      totalSerializedSize: serializeSize,
      fileNames: fileNames,
      expansionRatio: serializeSize / totalSize,
    );
  }
}

/// Summary information about a set of frames
class FrameSetSummary {
  final int fileCount;
  final int totalDataSize;
  final int totalSerializedSize;
  final List<String> fileNames;
  final double expansionRatio;

  FrameSetSummary({
    required this.fileCount,
    required this.totalDataSize,
    required this.totalSerializedSize,
    required this.fileNames,
    required this.expansionRatio,
  });

  @override
  String toString() => '''
FrameSetSummary(
  files: $fileCount
  originalSize: $totalDataSize bytes
  serializedSize: $totalSerializedSize bytes
  expansion: ${expansionRatio.toStringAsFixed(2)}x
  files: $fileNames
)''';
}
