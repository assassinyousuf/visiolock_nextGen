import '../models/channel_state.dart';
import '../models/encoding_payload.dart';
import '../models/file_metadata.dart';
import '../models/model_prediction.dart';
import '../models/transmission_metrics.dart';

class VisiolockState {
  final List<String> selectedFilePaths;
  final List<FileMetadata> selectedFiles;
  final ChannelStateEstimate? channelState;
  final ModelPrediction? prediction;
  final EncodingPayload? payload;
  final TransmissionMetrics? metrics;
  final bool isBusy;
  final String? error;

  const VisiolockState({
    this.selectedFilePaths = const [],
    this.selectedFiles = const [],
    this.channelState,
    this.prediction,
    this.payload,
    this.metrics,
    this.isBusy = false,
    this.error,
  });

  VisiolockState copyWith({
    List<String>? selectedFilePaths,
    List<FileMetadata>? selectedFiles,
    ChannelStateEstimate? channelState,
    ModelPrediction? prediction,
    EncodingPayload? payload,
    TransmissionMetrics? metrics,
    bool? isBusy,
    String? error,
    bool clearError = false,
  }) {
    return VisiolockState(
      selectedFilePaths: selectedFilePaths ?? this.selectedFilePaths,
      selectedFiles: selectedFiles ?? this.selectedFiles,
      channelState: channelState ?? this.channelState,
      prediction: prediction ?? this.prediction,
      payload: payload ?? this.payload,
      metrics: metrics ?? this.metrics,
      isBusy: isBusy ?? this.isBusy,
      error: clearError ? null : error ?? this.error,
    );
  }

  static const initial = VisiolockState();
}
