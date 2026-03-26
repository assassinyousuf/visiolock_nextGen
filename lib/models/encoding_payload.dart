class EncodingPayload {
  final List<int> pseudoEncryptedBytes;
  final int compressedSize;
  final int segmentCount;

  const EncodingPayload({
    required this.pseudoEncryptedBytes,
    required this.compressedSize,
    required this.segmentCount,
  });
}
