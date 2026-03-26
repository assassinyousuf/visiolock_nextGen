import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ml/api_ml_service.dart';
import '../ml/composite_ml_service.dart';
import '../ml/mlp_service.dart';
import '../ml/ml_service.dart';
import '../services/encoding_simulation_service.dart';
import '../services/file_analysis_service.dart';
import '../services/transmission_simulation_service.dart';
import '../services/history_service.dart';
import '../services/multi_file_framing_service.dart';
import 'visiolog_state.dart';
import 'visiolock_controller.dart';

final fileAnalysisServiceProvider = Provider<FileAnalysisService>(
  (ref) => FileAnalysisService(),
);

final historyServiceProvider = Provider<HistoryService>(
  (ref) => HistoryService(),
);

final multiFileFramingServiceProvider = Provider<MultiFileFramingService>(
  (ref) => MultiFileFramingService(),
);

final mlServiceProvider = Provider<MLService>((ref) {
  return CompositeMlService(
    primary: MlpService(),
    fallback: ApiMlService(),
  );
});

final encodingSimulationServiceProvider = Provider<EncodingSimulationService>(
  (ref) => EncodingSimulationService(),
);

final transmissionSimulationServiceProvider = Provider<TransmissionSimulationService>(
  (ref) => TransmissionSimulationService(),
);

final visiolockControllerProvider =
    StateNotifierProvider<VisiolockController, VisiolockState>((ref) {
  return VisiolockController(
    fileAnalysisService: ref.read(fileAnalysisServiceProvider),
    mlService: ref.read(mlServiceProvider),
    encodingService: ref.read(encodingSimulationServiceProvider),
    transmissionService: ref.read(transmissionSimulationServiceProvider),
    historyService: ref.read(historyServiceProvider),
    framingService: ref.read(multiFileFramingServiceProvider),
  );
});
