import 'dart:typed_data';

class BinaryConverter {
  static Uint8List bytesToBits(Uint8List bytes) {
    final bits = Uint8List(bytes.length * 8);
    var bitIndex = 0;

    for (final byte in bytes) {
      for (var i = 7; i >= 0; i--) {
        bits[bitIndex++] = (byte >> i) & 1;
      }
    }

    return bits;
  }

  static Uint8List bitsToBytes(List<int> bits) {
    if (bits.isEmpty) {
      return Uint8List(0);
    }
    if (bits.length % 8 != 0) {
      throw ArgumentError('Bit length must be a multiple of 8.');
    }

    final out = Uint8List(bits.length ~/ 8);
    var bitIndex = 0;

    for (var byteIndex = 0; byteIndex < out.length; byteIndex++) {
      var value = 0;
      for (var i = 0; i < 8; i++) {
        final bit = bits[bitIndex++];
        if (bit != 0 && bit != 1) {
          throw ArgumentError('Bits must be 0 or 1.');
        }
        value = (value << 1) | bit;
      }
      out[byteIndex] = value;
    }

    return out;
  }

  static Uint8List uint32le(int value) {
    final bd = ByteData(4)..setUint32(0, value, Endian.little);
    return bd.buffer.asUint8List();
  }

  static int readUint32le(Uint8List bytes, int offset) {
    if (offset < 0 || offset + 4 > bytes.length) {
      throw RangeError('Offset out of range for uint32.');
    }
    final bd = ByteData.sublistView(bytes, offset, offset + 4);
    return bd.getUint32(0, Endian.little);
  }
}
