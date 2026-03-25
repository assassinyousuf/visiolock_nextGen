import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

class ImagePayload {
  static const String magic = 'I2A3';
  static const int headerSizeBytes = 44;

  final String extension;
  final Uint8List imageBytes;
  final Uint8List payloadBytes;

  const ImagePayload({
    required this.extension,
    required this.imageBytes,
    required this.payloadBytes,
  });
}

class ImageProcessor {
  Future<ImagePayload> convertImageToBinary(File imageFile) async {
    final imageBytes = await imageFile.readAsBytes();
    if (imageBytes.isEmpty) {
      throw const FormatException('Selected image file is empty.');
    }

    final digestBytes = Uint8List.fromList(sha256.convert(imageBytes).bytes);

    final extension = _fileExtension(imageFile.path);
    final extensionBytes = Uint8List.fromList(extension.codeUnits);

    final header = ByteData(ImagePayload.headerSizeBytes);
    _writeAscii(header, 0, ImagePayload.magic);
    header.setUint32(4, extensionBytes.length, Endian.little);
    header.setUint32(8, imageBytes.length, Endian.little);
    header.buffer.asUint8List().setAll(12, digestBytes);

    final payloadBytes = Uint8List(
      ImagePayload.headerSizeBytes + extensionBytes.length + imageBytes.length,
    );
    payloadBytes.setAll(0, header.buffer.asUint8List());
    payloadBytes.setAll(ImagePayload.headerSizeBytes, extensionBytes);
    payloadBytes.setAll(
      ImagePayload.headerSizeBytes + extensionBytes.length,
      imageBytes,
    );

    return ImagePayload(
      extension: extension,
      imageBytes: imageBytes,
      payloadBytes: payloadBytes,
    );
  }

  String _fileExtension(String path) {
    final fileName = path.split(Platform.pathSeparator).last;
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) {
      return 'img';
    }

    final ext = fileName.substring(dot + 1).toLowerCase();
    if (ext.length > 10) {
      return 'img';
    }

    final safe = ext.replaceAll(RegExp(r'[^a-z0-9]'), '');
    return safe.isEmpty ? 'img' : safe;
  }

  void _writeAscii(ByteData bd, int offset, String s) {
    final units = s.codeUnits;
    for (var i = 0; i < units.length; i++) {
      bd.setUint8(offset + i, units[i]);
    }
  }
}
