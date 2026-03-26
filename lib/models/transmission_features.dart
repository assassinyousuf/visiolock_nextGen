import 'file_metadata.dart';

class TransmissionFeatures {
  final FileMetadata fileMetadata;
  final double snr;
  final double noiseLevel;

  const TransmissionFeatures({
    required this.fileMetadata,
    required this.snr,
    required this.noiseLevel,
  });

  Map<String, dynamic> toJson() {
    return {
      'file_type': fileMetadata.category.name,
      'file_size': fileMetadata.fileSize,
      'snr': snr,
      'noise_level': noiseLevel,
    };
  }
}
