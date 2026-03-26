import '../models/transmission_features.dart';
import '../models/model_prediction.dart';

abstract class MLService {
  Future<ModelPrediction> predict(TransmissionFeatures features);
}

class MLInferenceException implements Exception {
  final String message;

  MLInferenceException(this.message);

  @override
  String toString() => 'MLInferenceException: $message';
}
