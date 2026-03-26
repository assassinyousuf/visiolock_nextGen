import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/channel_state.dart';
import '../models/file_metadata.dart';
import '../services/encryption_selector_service.dart';
import '../services/universal_file_processor.dart';
import '../services/ai_transmission_service_v2.dart';
import '../services/multi_encryption_implementations.dart';

/// Multi-File Transmission Handler — Orchestrates file selection, encryption, and transmission
///
/// Features:
/// - Support for multiple file types (images, text, documents, binary)
/// - Intelligent encryption method selection
/// - Adaptive transmission parameters based on channel conditions
/// - Progress tracking and error handling
class MultiFileTransmissionHandler {
  final UniversalFileProcessor _fileProcessor = UniversalFileProcessor();
  final EncryptionSelectorService _encryptionSelector = EncryptionSelectorService();
  final AiTransmissionServiceV2 _aiService = AiTransmissionServiceV2();

  // State
  FileData? _selectedFile;
  TransmissionConfig? _currentConfig;
  EncryptionMethod? _selectedEncryption;
  Uint8List? _encryptedData;
  double _progress = 0.0;

  // Callbacks
  Function(String)? onStatusUpdate;
  Function(double)? onProgressUpdate;

  /// Load any file and prepare for transmission
  Future<void> selectAndLoadFile(File file) async {
    try {
      _updateStatus('Loading file...');
      _selectedFile = await _fileProcessor.loadFile(file);
      _updateStatus('File loaded: ${_selectedFile!.metadata.fileName}');
    } catch (e) {
      _updateStatus('Error loading file: $e');
      rethrow;
    }
  }

  /// Get transmission configuration for current file
  Future<void> configureTransmission({
    ChannelStateEstimate? channelState,
    EncryptionMethod? preferredEncryption,
  }) async {
    final fileData = _selectedFile;
    if (fileData == null) {
      throw Exception('No file selected');
    }

    try {
      _updateStatus('Analyzing file and channel conditions...');

      // Use provided channel state or default
      final channel = channelState ?? ChannelStateEstimate(snrDb: 15.0, noiseLevel: 0.1);

      // Get optimal configuration from AI service
      _currentConfig = await _aiService.getOptimalConfiguration(
        fileData: fileData,
        channelState: channel,
        preferredEncryption: preferredEncryption,
      );

      _selectedEncryption ??= _currentConfig!.recommendedEncryption;

      _updateStatus(
        'Configuration ready: ${_currentConfig!.encoding}/${_currentConfig!.coding}/${_currentConfig!.modulation}',
      );
    } catch (e) {
      _updateStatus('Configuration error: $e');
      rethrow;
    }
  }

  /// Get available encryption options for current file
  Future<List<EncryptionRecommendation>> getEncryptionOptions({
    ChannelStateEstimate? channelState,
  }) async {
    final fileData = _selectedFile;
    if (fileData == null) {
      throw Exception('No file selected');
    }

    final channel = channelState ?? ChannelStateEstimate(snrDb: 15.0, noiseLevel: 0.1);

    return await _aiService.getEncryptionRecommendations(
      fileData: fileData,
      channelState: channel,
      priority: 'balanced',
    );
  }

  /// Encrypt file with selected method
  Future<Uint8List> encryptFile({
    required Uint8List encryptionKey,
    EncryptionMethod? encryptionMethod,
  }) async {
    final fileData = _selectedFile;
    if (fileData == null) {
      throw Exception('No file selected');
    }

    try {
      _updateStatus('Encrypting ${fileData.metadata.fileName}...');

      // Use selected encryption method or recommended one
      final method = encryptionMethod ?? _selectedEncryption ?? EncryptionMethod.aesGcm;
      final methodName = _getEncryptionMethodName(method);

      // Create encryption implementation
      final encryptor = EncryptionFactory.create(methodName);

      // Encrypt in chunks for large files
      Uint8List encrypted;
      if (_fileProcessor.shouldChunk(fileData.metadata)) {
        encrypted = await _encryptLargeFileInChunks(
          encryptor,
          fileData.rawBytes,
          encryptionKey,
        );
      } else {
        encrypted = encryptor.encrypt(fileData.rawBytes, encryptionKey);
      }

      _encryptedData = encrypted;
      _updateStatus(
        'Encrypted successfully (${_fileProcessor.getChunkSize(fileData.metadata)} bytes)',
      );

      return encrypted;
    } catch (e) {
      _updateStatus('Encryption failed: $e');
      rethrow;
    }
  }

  /// Encrypt large file in chunks
  Future<Uint8List> _encryptLargeFileInChunks(
    EncryptionImplementation encryptor,
    Uint8List data,
    Uint8List key,
  ) async {
    final buffer = <int>[];
    final chunkSize = 1024 * 1024; // 1 MB chunks

    for (int i = 0; i < data.length; i += chunkSize) {
      final endIdx = (i + chunkSize).clamp(0, data.length);
      final chunk = data.sublist(i, endIdx);

      final encrypted = encryptor.encrypt(chunk, key);
      buffer.addAll(encrypted);

      _updateProgress(i / data.length);
      _updateStatus(
        'Encrypting... ${((i / data.length) * 100).toStringAsFixed(0)}%',
      );
    }

    _updateProgress(1.0);
    return Uint8List.fromList(buffer);
  }

  /// Get comprehensive file analysis
  Future<FileAnalysisResult> analyzeFile() async {
    final fileData = _selectedFile;
    if (fileData == null) {
      throw Exception('No file selected');
    }

    try {
      _updateStatus('Analyzing file characteristics...');
      return await _aiService.analyzeFile(fileData);
    } catch (e) {
      _updateStatus('Analysis error: $e');
      rethrow;
    }
  }

  /// Get all available encryptions for current file type
  List<EncryptionConfig> getAvailableEncryptions() {
    final fileData = _selectedFile;
    if (fileData == null) return [];
    return _encryptionSelector.getAvailableEncryptions(fileData.metadata.category);
  }

  /// Update encryption method selection
  void setEncryptionMethod(EncryptionMethod method) {
    if (getAvailableEncryptions().any((e) => e.method == method)) {
      _selectedEncryption = method;
      _updateStatus('Encryption method set to: ${_getEncryptionMethodName(method)}');
    } else {
      _updateStatus('Encryption method not suitable for this file type');
    }
  }

  // ────────────────────────────── Getters

  FileData? get selectedFile => _selectedFile;
  TransmissionConfig? get currentConfig => _currentConfig;
  EncryptionMethod? get selectedEncryption => _selectedEncryption;
  Uint8List? get encryptedData => _encryptedData;
  double get progress => _progress;

  String get fileTypeName =>
      _selectedFile?.metadata.category.toString().split('.').last ?? 'unknown';

  String get selectedEncryptionName =>
      _selectedEncryption != null ? _getEncryptionMethodName(_selectedEncryption!) : 'None';

  bool get isConfigured => _currentConfig != null;
  bool get isEncrypted => _encryptedData != null;

  // ────────────────────────────── Helper methods

  String _getEncryptionMethodName(EncryptionMethod method) {
    switch (method) {
      case EncryptionMethod.saicAct:
        return 'SAIC-ACT';
      case EncryptionMethod.aesGcm:
        return 'AES-256-GCM';
      case EncryptionMethod.chaCha20:
        return 'ChaCha20-Poly1305';
      case EncryptionMethod.xorCrypto:
        return 'XOR-Crypto';
      case EncryptionMethod.hybridMode:
        return 'Hybrid Mode';
    }
  }

  void _updateStatus(String message) {
    onStatusUpdate?.call(message);
  }

  void _updateProgress(double value) {
    _progress = value.clamp(0.0, 1.0);
    onProgressUpdate?.call(_progress);
  }

  /// Clean up resources
  void dispose() {
    _encryptedData = null;
    _selectedFile = null;
    _currentConfig = null;
  }
}

/// UI Widget: File Type Selector
class FileTypeSelector extends StatelessWidget {
  final Function(FileCategory) onSelected;

  const FileTypeSelector({required this.onSelected, super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        FileTypeBadge(
          category: FileCategory.image,
          onSelected: onSelected,
        ),
        FileTypeBadge(
          category: FileCategory.text,
          onSelected: onSelected,
        ),
        FileTypeBadge(
          category: FileCategory.structured,
          onSelected: onSelected,
        ),
        FileTypeBadge(
          category: FileCategory.binary,
          onSelected: onSelected,
        ),
      ],
    );
  }
}

class FileTypeBadge extends StatelessWidget {
  final FileCategory category;
  final Function(FileCategory) onSelected;

  const FileTypeBadge({
    required this.category,
    required this.onSelected,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final label = category.toString().split('.').last.toUpperCase();
    return ActionChip(
      label: Text(label),
      onPressed: () => onSelected(category),
      avatar: Icon(_getIcon()),
    );
  }

  IconData _getIcon() {
    switch (category) {
      case FileCategory.image:
        return Icons.image;
      case FileCategory.text:
        return Icons.text_fields;
      case FileCategory.structured:
        return Icons.description;
      case FileCategory.binary:
        return Icons.memory;
    }
  }
}

/// UI Widget: Encryption Method Selector
class EncryptionMethodSelector extends StatelessWidget {
  final List<EncryptionConfig> availableMethods;
  final EncryptionMethod? selectedMethod;
  final Function(EncryptionMethod) onSelected;

  const EncryptionMethodSelector({
    required this.availableMethods,
    required this.selectedMethod,
    required this.onSelected,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: availableMethods.length,
      itemBuilder: (context, index) {
        final config = availableMethods[index];
        final isSelected = selectedMethod == config.method;

        return Card(
          child: ListTile(
            leading: Checkbox(
              value: isSelected,
              onChanged: (_) => onSelected(config.method),
            ),
            title: Text(config.description),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Security: ${(config.securityLevel * 100).toStringAsFixed(0)}%'),
                Text('Speed: ${(config.performanceRating * 100).toStringAsFixed(0)}%'),
              ],
            ),
            trailing: Icon(
              config.requiresAuthentication ? Icons.security : Icons.shield_outlined,
            ),
          ),
        );
      },
    );
  }
}

/// Helper: Get supported file extensions for file picker
Map<FileCategory, List<String>> getFilePickerExtensions() {
  return {
    FileCategory.image: ['png', 'jpg', 'jpeg', 'bmp', 'gif', 'webp'],
    FileCategory.text: ['txt', 'json', 'xml', 'csv', 'md', 'dart', 'js'],
    FileCategory.structured: ['pdf'],
    FileCategory.binary: ['bin', 'exe', 'dll', 'so', 'zip', 'tar', 'gz'],
  };
}

/// Helper: Get all supported extensions
List<String> getAllSupportedExtensions() {
  final extensions = <String>[];
  getFilePickerExtensions().forEach((_, exts) => extensions.addAll(exts));
  return extensions;
}
