import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/model_prediction.dart';
import '../models/transmission_features.dart';
import 'ml_service.dart';

class ApiMlService implements MLService {
  final String endpoint;

  ApiMlService({
    this.endpoint = 'http://127.0.0.1:5000/api/predict',
  });

  @override
  Future<ModelPrediction> predict(TransmissionFeatures features) async {
    try {
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(features.toJson()),
      );

      if (response.statusCode != 200) {
        throw MLInferenceException(
          'API inference failed with status ${response.statusCode}',
        );
      }

      final Map<String, dynamic> json =
          jsonDecode(response.body) as Map<String, dynamic>;

      return ModelPrediction(
        encodingClass: (json['encoding'] as num?)?.toInt() ??
            (json['encoding_class'] as num?)?.toInt() ??
            0,
        codingClass: (json['coding'] as num?)?.toInt() ??
            (json['coding_class'] as num?)?.toInt() ??
            0,
        modulationClass: (json['modulation'] as num?)?.toInt() ??
            (json['modulation_class'] as num?)?.toInt() ??
            0,
      );
    } catch (e) {
      if (e is MLInferenceException) {
        rethrow;
      }
      throw MLInferenceException('API request failed: $e');
    }
  }
}
