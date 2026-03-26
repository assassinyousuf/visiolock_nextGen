class ModelPrediction {
  final int encodingClass;
  final int codingClass;
  final int modulationClass;

  const ModelPrediction({
    required this.encodingClass,
    required this.codingClass,
    required this.modulationClass,
  });

  String get encodingLabel {
    switch (encodingClass) {
      case 0:
        return 'SAIC-ACT';
      case 1:
        return 'Light encoding';
      case 2:
        return 'Entropy-based';
      default:
        return 'Unknown';
    }
  }

  String get codingLabel {
    switch (codingClass) {
      case 0:
        return 'RS only';
      case 1:
        return 'RS + repetition (2x)';
      case 2:
        return 'RS + repetition (3x)';
      default:
        return 'Unknown';
    }
  }

  String get modulationLabel {
    switch (modulationClass) {
      case 0:
        return 'Fast';
      case 1:
        return 'Medium';
      case 2:
        return 'Robust';
      default:
        return 'Unknown';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'encoding_class': encodingClass,
      'coding_class': codingClass,
      'modulation_class': modulationClass,
    };
  }

  factory ModelPrediction.fromJson(Map<String, dynamic> json) {
    return ModelPrediction(
      encodingClass: (json['encoding_class'] as num?)?.toInt() ?? 0,
      codingClass: (json['coding_class'] as num?)?.toInt() ?? 0,
      modulationClass: (json['modulation_class'] as num?)?.toInt() ?? 0,
    );
  }
}
