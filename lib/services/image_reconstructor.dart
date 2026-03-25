import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;

import '../utils/binary_converter.dart';

class DecodedImageFile {
  final Uint8List bytes;
  final String extension;
  final String payloadMagic;
  final bool integrityVerified;

  const DecodedImageFile({
    required this.bytes,
    required this.extension,
    required this.payloadMagic,
    required this.integrityVerified,
  });
}

class ImageReconstructor {
  static const String _magicLegacyRgb = 'I2A1';
  static const int _legacyHeaderSizeBytes = 20;

  static const String _magicFileBytesNoHash = 'I2A2';
  static const int _fileHeaderSizeBytesNoHash = 12;

  static const String _magicFileBytesWithHash = 'I2A3';
  static const int _fileHeaderSizeBytesWithHash = 44;

  DecodedImageFile reconstructImageFromBinaryBits(List<int> binaryBits) {
    final payloadBytes = BinaryConverter.bitsToBytes(binaryBits);
    return reconstructImageFromPayloadBytes(payloadBytes);
  }

  DecodedImageFile reconstructImageFromPayloadBytes(Uint8List payloadBytes) {
    if (payloadBytes.length < 4) {
      throw const FormatException('Payload too short to contain header.');
    }

    final magic = String.fromCharCodes(payloadBytes.sublist(0, 4));
    if (magic == _magicFileBytesWithHash) {
      return _parseFileBytesPayloadWithHash(payloadBytes);
    }
    if (magic == _magicFileBytesNoHash) {
      return _parseFileBytesPayloadNoHash(payloadBytes);
    }
    if (magic == _magicLegacyRgb) {
      final pngBytes = _reconstructLegacyPng(payloadBytes);
      return DecodedImageFile(
        bytes: pngBytes,
        extension: 'png',
        payloadMagic: _magicLegacyRgb,
        integrityVerified: false,
      );
    }

    throw FormatException('Unsupported payload header magic: $magic');
  }

  DecodedImageFile _parseFileBytesPayloadNoHash(Uint8List payloadBytes) {
    if (payloadBytes.length < _fileHeaderSizeBytesNoHash) {
      throw const FormatException('Payload too short to contain file header.');
    }

    final extLen = BinaryConverter.readUint32le(payloadBytes, 4);
    final fileLen = BinaryConverter.readUint32le(payloadBytes, 8);

    if (extLen < 1 || extLen > 10) {
      throw FormatException('Invalid extension length: $extLen');
    }
    if (fileLen <= 0) {
      throw FormatException('Invalid file length: $fileLen');
    }

    final extOffset = _fileHeaderSizeBytesNoHash;
    final fileOffset = extOffset + extLen;
    final end = fileOffset + fileLen;
    if (end > payloadBytes.length) {
      throw const FormatException('Payload is truncated (file bytes missing).');
    }

    final ext = String.fromCharCodes(payloadBytes.sublist(extOffset, fileOffset))
        .toLowerCase();
    final safeExt = ext.replaceAll(RegExp(r'[^a-z0-9]'), '');
    final outExt = safeExt.isEmpty ? 'img' : safeExt;

    final bytes = Uint8List.fromList(payloadBytes.sublist(fileOffset, end));
    return DecodedImageFile(
      bytes: bytes,
      extension: outExt,
      payloadMagic: _magicFileBytesNoHash,
      integrityVerified: false,
    );
  }

  DecodedImageFile _parseFileBytesPayloadWithHash(Uint8List payloadBytes) {
    if (payloadBytes.length < _fileHeaderSizeBytesWithHash) {
      throw const FormatException(
        'Payload too short to contain file header + integrity hash.',
      );
    }

    final extLen = BinaryConverter.readUint32le(payloadBytes, 4);
    final fileLen = BinaryConverter.readUint32le(payloadBytes, 8);

    if (extLen < 1 || extLen > 10) {
      throw FormatException('Invalid extension length: $extLen');
    }
    if (fileLen <= 0) {
      throw FormatException('Invalid file length: $fileLen');
    }

    final expectedHash = Uint8List.fromList(payloadBytes.sublist(12, 44));
    if (expectedHash.length != 32) {
      throw const FormatException('Invalid SHA-256 hash length in header.');
    }

    final extOffset = _fileHeaderSizeBytesWithHash;
    final fileOffset = extOffset + extLen;
    final end = fileOffset + fileLen;
    if (end > payloadBytes.length) {
      throw const FormatException('Payload is truncated (file bytes missing).');
    }

    final ext = String.fromCharCodes(payloadBytes.sublist(extOffset, fileOffset))
        .toLowerCase();
    final safeExt = ext.replaceAll(RegExp(r'[^a-z0-9]'), '');
    final outExt = safeExt.isEmpty ? 'img' : safeExt;

    final bytes = Uint8List.fromList(payloadBytes.sublist(fileOffset, end));
    final actualHash = Uint8List.fromList(sha256.convert(bytes).bytes);
    if (!_bytesEqual(expectedHash, actualHash)) {
      throw const FormatException(
        'Integrity check failed (SHA-256 mismatch). The audio file was corrupted or transcoded; resend the original WAV as a file.',
      );
    }

    return DecodedImageFile(
      bytes: bytes,
      extension: outExt,
      payloadMagic: _magicFileBytesWithHash,
      integrityVerified: true,
    );
  }

  bool _bytesEqual(Uint8List a, Uint8List b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Uint8List _reconstructLegacyPng(Uint8List payloadBytes) {
    if (payloadBytes.length < _legacyHeaderSizeBytes) {
      throw const FormatException('Payload too short to contain legacy header.');
    }

    final magic = String.fromCharCodes(payloadBytes.sublist(0, 4));
    if (magic != _magicLegacyRgb) {
      throw const FormatException('Invalid payload magic/header.');
    }

    final width = BinaryConverter.readUint32le(payloadBytes, 4);
    final height = BinaryConverter.readUint32le(payloadBytes, 8);
    final channels = BinaryConverter.readUint32le(payloadBytes, 12);
    final dataLen = BinaryConverter.readUint32le(payloadBytes, 16);

    if (width <= 0 || height <= 0) {
      throw FormatException('Invalid image dimensions: ${width}x$height');
    }
    if (channels != 3 && channels != 4) {
      throw FormatException(
        'Unsupported channel count: $channels (expected 3 or 4)',
      );
    }

    final expectedLen = width * height * channels;
    if (dataLen != expectedLen) {
      throw FormatException(
        'Invalid payload length: expected $expectedLen bytes, got $dataLen',
      );
    }

    final pixelOffset = _legacyHeaderSizeBytes;
    final end = pixelOffset + dataLen;
    if (end > payloadBytes.length) {
      throw const FormatException(
        'Payload is truncated (not enough pixel bytes).',
      );
    }

    final order = channels == 4 ? img.ChannelOrder.rgba : img.ChannelOrder.rgb;

    final image = img.Image.fromBytes(
      width: width,
      height: height,
      bytes: payloadBytes.buffer,
      bytesOffset: pixelOffset,
      numChannels: channels,
      order: order,
    );

    final pngBytes = img.encodePng(image);
    return Uint8List.fromList(pngBytes);
  }
}
