import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/channel_state.dart';
import '../models/file_metadata.dart';
import '../models/transmission_features.dart';
import '../models/history_entry.dart';
import '../services/encoding_simulation_service.dart';
import '../services/file_analysis_service.dart';
import '../services/transmission_simulation_service.dart';
import '../services/history_service.dart';
import '../services/multi_file_framing_service.dart';
import 'visiolog_state.dart';
import '../ml/ml_service.dart';

class VisiolockController extends StateNotifier<VisiolockState> {
  static const Set<String> _supportedExtensions = {
    'png', 'jpg', 'jpeg', 'bmp', 'gif', 'webp',
    'txt', 'md', 'json', 'xml', 'csv',
    'pdf',
    'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
    'zip', 'bin', 'exe', 'dat',
  };

  final FileAnalysisService _fileAnalysisService;
  final MLService _mlService;
  final EncodingSimulationService _encodingService;
  final TransmissionSimulationService _transmissionService;
  final HistoryService _historyService;
  final MultiFileFramingService _framingService;

  VisiolockController({
    required FileAnalysisService fileAnalysisService,
    required MLService mlService,
    required EncodingSimulationService encodingService,
    required TransmissionSimulationService transmissionService,
    required HistoryService historyService,
    required MultiFileFramingService framingService,
  })  : _fileAnalysisService = fileAnalysisService,
        _mlService = mlService,
        _encodingService = encodingService,
        _transmissionService = transmissionService,
        _historyService = historyService,
        _framingService = framingService,
        super(VisiolockState.initial);

  Future<void> selectFiles() async {
    try {
      state = state.copyWith(isBusy: true, clearError: true);

      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) {
        state = state.copyWith(isBusy: false);
        return;
      }

      final List<String> newPaths = [];
      final List<FileMetadata> newMetadata = [];

      for (var file in result.files) {
        if (file.path == null) continue;

        final path = file.path!;
        final extension = path.split('.').last.toLowerCase();

        if (!_supportedExtensions.contains(extension)) {
          // In a real app we might show a warning, but skipping for now
          continue;
        }

        newPaths.add(path);
        newMetadata.add(await _fileAnalysisService.analyzeFile(File(path)));
      }

      if (newMetadata.isEmpty) {
         state = state.copyWith(
          isBusy: false,
          error: 'No valid supported files selected.',
        );
        return;
      }

      // Append new files to existing ones
      final updatedPaths = [...state.selectedFilePaths, ...newPaths];
      final updatedMetadata = [...state.selectedFiles, ...newMetadata];

      state = state.copyWith(
        selectedFilePaths: updatedPaths,
        selectedFiles: updatedMetadata,
        prediction: null, // Clear old results
        payload: null,
        metrics: null,
        isBusy: false,
      );
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: 'File selection failed: $e',
      );
    }
  }

  void removeFile(int index) {
    if (index < 0 || index >= state.selectedFiles.length) return;

    final newPaths = List<String>.from(state.selectedFilePaths)..removeAt(index);
    final newFiles = List<FileMetadata>.from(state.selectedFiles)..removeAt(index);
    
    // Also remove from state to trigger rebuild
    state = state.copyWith(
      selectedFilePaths: newPaths,
      selectedFiles: newFiles,
      prediction: null,
      payload: null,
      metrics: null,
    );
  }

  void clearFiles() {
    state = state.copyWith(
      selectedFilePaths: [],
      selectedFiles: [],
      prediction: null,
      payload: null,
      metrics: null,
    );
  }

  void updateChannel({required double snr, required double noiseLevel}) {
    state = state.copyWith(
      channelState: ChannelStateEstimate(
        snrDb: snr,
        noiseLevel: noiseLevel,
      ),
      prediction: null,
      payload: null,
      metrics: null,
      clearError: true,
    );
  }

  Future<void> runPrediction() async {
    final files = state.selectedFiles;
    final channel = state.channelState;

    if (files.isEmpty) {
      state = state.copyWith(error: 'Please select at least one file.');
      return;
    }

    if (channel == null) {
      state = state.copyWith(error: 'Please configure channel conditions first.');
      return;
    }

    try {
      state = state.copyWith(isBusy: true, clearError: true);

      // Using the first file for the demo prediction visualization
      final prediction = await _mlService.predict(
        TransmissionFeatures(
          fileMetadata: files.first,
          snr: channel.snrDb,
          noiseLevel: channel.noiseLevel,
        ),
      );

      state = state.copyWith(prediction: prediction, isBusy: false);
    } catch (e) {
      state = state.copyWith(isBusy: false, error: 'Prediction failed: $e');
    }
  }

  Future<void> runTransmissionSimulation() async {
    final paths = state.selectedFilePaths;
    final channel = state.channelState;
    final prediction = state.prediction;
    final files = state.selectedFiles;

    if (paths.isEmpty || channel == null || prediction == null) {
      state = state.copyWith(
        error: 'Missing data. Complete file, channel, and prediction steps first.',
      );
      return;
    }

    try {
      state = state.copyWith(isBusy: true, clearError: true);

      // 1. Pack all selected files using I2A3 Multi-File Framing
      final fileObjects = paths.map((p) => File(p)).toList();
      final frames = await _framingService.createFramesFromFiles(fileObjects);
      final packedBytes = _framingService.serializeFrames(frames);
      final totalBytes = packedBytes.toList(); // Convert to growable list if needed

      final payload = _encodingService.encode(
        sourceBytes: totalBytes,
        prediction: prediction,
      );

      final metrics = _transmissionService.simulate(
        payload: payload,
        channel: channel,
        prediction: prediction,
      );

      // Save to history
      if (metrics.isSuccess) {
          final count = files.length;
          final title = count == 1 
              ? files.first.fileName 
              : '${files.first.fileName} +${count - 1} others';
          
          await _historyService.addEntry(HistoryEntry(
            timestampMs: DateTime.now().millisecondsSinceEpoch,
            title: title,
            detail: 'Batch: $count files | Strat: ${prediction.encodingLabel} | PER: ${(metrics.ber * 100).toStringAsFixed(1)}%',
            path: paths.first, // Storing primary path
          ));
      }

      state = state.copyWith(
        payload: payload,
        metrics: metrics,
        isBusy: false,
      );
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: 'Simulation failed: $e',
      );
    }
  }
}
