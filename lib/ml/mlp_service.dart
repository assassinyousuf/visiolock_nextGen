import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';

import '../models/file_metadata.dart';
import '../models/model_prediction.dart';
import '../models/transmission_features.dart';
import 'ml_service.dart';

class MlpService implements MLService {
  static const String _modelPath = 'assets/models/model_weights.json';
  
  Map<String, dynamic>? _modelData;

  // Configuration from training (StandardScaler)
  static const double _meanFileSize = 2533.88231;
  static const double _scaleFileSize = 1438.610208737434;
  static const double _meanSnr = 17.71378;
  static const double _scaleSnr = 7.01945993019406;
  static const double _meanNoise = 0.25602600000000003;
  static const double _scaleNoise = 0.13864918796732997;

  // File type mapping
  // 'binary': 0, 'image': 1, 'pdf': 2, 'text': 3
  
  // Target classes from training
  static const List<String> _targetClasses = [
    'AES-128+Convolutional+64-QAM',
    'None+Convolutional+64-QAM',
    'None+Hamming+64-QAM',
    'None+None+64-QAM',
    'None+RS+64-QAM',
  ];

  Future<void> _ensureModelLoaded() async {
    if (_modelData != null) return;

    try {
      final jsonString = await rootBundle.loadString(_modelPath);
      _modelData = json.decode(jsonString);
    } catch (e) {
      throw MLInferenceException('Failed to load MLP configuration: $e');
    }
  }

  @override
  Future<ModelPrediction> predict(TransmissionFeatures features) async {
    await _ensureModelLoaded();

    // 1. Preprocess Input
    final inputVector = _preprocess(features);

    // 2. Forward Pass
    final outputLogits = _forwardPass(inputVector);

    // 3. Softmax & Argmax
    final classIndex = _argmax(_softmax(outputLogits));

    // 4. Decode Label
    final configString = _targetClasses[classIndex];
    return _parseConfig(configString);
  }

  List<double> _preprocess(TransmissionFeatures features) {
    // Encode file type
    double fileTypeIndex;
    switch (features.fileMetadata.category) {
      case FileCategory.binary:
        fileTypeIndex = 0.0;
        break;
      case FileCategory.image:
        fileTypeIndex = 1.0;
        break;
      case FileCategory.structured:
        fileTypeIndex = 2.0; // PDF
        break;
      case FileCategory.text:
        fileTypeIndex = 3.0; // Text
        break;
    }

    // Scale numerical features: (x - mean) / scale
    final scaledFileSize = (features.fileMetadata.fileSize / 1024.0 - _meanFileSize) / _scaleFileSize;
    final scaledSnr = (features.snr - _meanSnr) / _scaleSnr;
    final scaledNoise = (features.noiseLevel - _meanNoise) / _scaleNoise;

    return [fileTypeIndex, scaledFileSize, scaledSnr, scaledNoise];
  }

  List<double> _forwardPass(List<double> input) {
    final weights = _modelData!['weights'] as List;
    final biases = _modelData!['biases'] as List;
    
    var currentLayer = input;

    // Iterate through layers
    for (int i = 0; i < weights.length; i++) {
        final layerWeights = (weights[i] as List).map((row) => (row as List).map((e) => (e as num).toDouble()).toList()).toList();
        final layerBiases = (biases[i] as List).map((e) => (e as num).toDouble()).toList();
        
        // Matrix multiplication: currentLayer (1 x N) * Weights (N x M) + Biases (1 x M)
        // Note: Scikit-learn weights are (n_features, n_neurons)
        // This is convenient: result[j] = sum(input[k] * W[k][j]) + b[j]
        
        // Output size of this layer
        final outputSize = layerBiases.length;
        final nextLayer = List<double>.filled(outputSize, 0.0);

        for (int j = 0; j < outputSize; j++) {
            double sum = 0.0;
            for (int k = 0; k < currentLayer.length; k++) {
                sum += currentLayer[k] * layerWeights[k][j];
            }
            sum += layerBiases[j];
            
            // Activation
            if (i < weights.length - 1) { // Hidden layers: ReLU
                nextLayer[j] = max(0.0, sum);
            } else { // Output layer: No activation here, Softmax is applied after
                nextLayer[j] = sum;
            }
        }
        currentLayer = nextLayer;
    }
    
    return currentLayer;
  }

  List<double> _softmax(List<double> logits) {
    final maxLogit = logits.reduce(max);
    final expLogits = logits.map((e) => exp(e - maxLogit)).toList();
    final sumExp = expLogits.reduce((a, b) => a + b);
    return expLogits.map((e) => e / sumExp).toList();
  }

  int _argmax(List<double> probabilities) {
    int maxIndex = 0;
    double maxValue = probabilities[0];
    for (int i = 1; i < probabilities.length; i++) {
      if (probabilities[i] > maxValue) {
        maxValue = probabilities[i];
        maxIndex = i;
      }
    }
    return maxIndex;
  }

  ModelPrediction _parseConfig(String config) {
    // Format: "Encoding+Coding+Modulation"
    // e.g. "AES-128+RS+16-QAM"
    final parts = config.split('+');
    
    // Mapping model output strings to ModelPrediction integers
    
    // Encoding
    // 0: SAIC-ACT (AES-based)
    // 1: Light (ChaCha20 or None)
    // 2: Entropy (Other)
    int encodingClass = 1; // Default Light
    if (parts[0].contains('AES')) {
      encodingClass = 0;
    } else if (parts[0].contains('ChaCha')) {
      encodingClass = 1;
    } else if (parts[0] == 'None') {
      encodingClass = 2;
    }

    // Coding
    // 0: RS only
    // 1: RS + repetition (Hamming approximation)
    // 2: RS + repetition (Convolutional approximation)
    int codingClass = 0; // RS only
    if (parts[1] == 'RS') {
      codingClass = 0;
    } else if (parts[1] == 'Hamming') {
      codingClass = 1;
    } else if (parts[1] == 'Convolutional') {
      codingClass = 2;
    } else if (parts[1] == 'None') {
      codingClass = 0;
    }

    // Modulation
    // 0: Fast (64-QAM)
    // 1: Medium (16-QAM)
    // 2: Robust (QPSK/FSK)
    int modulationClass = 2; // Robust
    if (parts[2] == '64-QAM') {
      modulationClass = 0;
    } else if (parts[2] == '16-QAM') {
      modulationClass = 1;
    } else if (parts[2] == 'QPSK') {
      modulationClass = 2;
    } else if (parts[2] == 'FSK') {
      modulationClass = 2;
    }

    return ModelPrediction(
      encodingClass: encodingClass,
      codingClass: codingClass,
      modulationClass: modulationClass,
    );
  }
}
