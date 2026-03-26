import '../models/model_prediction.dart';
import '../models/transmission_features.dart';
import 'ml_service.dart';

class CompositeMlService implements MLService {
  final MLService primary;
  final MLService fallback;

  CompositeMlService({
    required this.primary,
    required this.fallback,
  });

  @override
  Future<ModelPrediction> predict(TransmissionFeatures features) async {
    try {
      return await primary.predict(features);
    } catch (_) {
      return fallback.predict(features);
    }
  }
}
