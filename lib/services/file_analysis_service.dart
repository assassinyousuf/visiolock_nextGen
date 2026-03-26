import 'dart:io';

import '../models/file_metadata.dart';

class FileAnalysisService {
  Future<FileMetadata> analyzeFile(File file) async {
    final stat = await file.stat();
    final fileName = file.path.split(Platform.pathSeparator).last;

    if (stat.type != FileSystemEntityType.file) {
      throw const FileSystemException('The selected entity is not a valid file');
    }

    if (stat.size <= 0) {
      throw const FileSystemException('Selected file is empty');
    }

    return FileMetadata(
      fileName: fileName,
      fileSize: stat.size,
      category: FileMetadata.categorizeByExtension(fileName),
      mimeType: FileMetadata.mimeTypeFromExtension(fileName),
    );
  }
}
