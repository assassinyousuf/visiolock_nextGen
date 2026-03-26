// Updated sender_screen.dart - Before & After Examples

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:typed_data';

import 'services/multi_file_transmission_handler.dart';
import 'services/universal_file_processor.dart';
import 'services/encryption_selector_service.dart';
import 'services/multi_encryption_implementations.dart';
import 'models/channel_state.dart';
import 'services/passphrase_key_service.dart';
import 'services/biometric_auth_service.dart';

class SenderScreen extends StatefulWidget {
  const SenderScreen({super.key});

  @override
  State<SenderScreen> createState() => _SenderScreenState();
}

class _SenderScreenState extends State<SenderScreen> {
  // ============================================================================
  // BEFORE: Old code with image-only support
  // ============================================================================
  // late ImageProcessor _imageProcessor = ImageProcessor();
  // late File _selectedImage;
  // late LegacyEncryptionService _encryptionService;

  // ============================================================================
  // AFTER: New code with multi-file support
  // ============================================================================
  late MultiFileTransmissionHandler _handler;
  late EncryptionSelectorService _encryptionSelector;
  late AiTransmissionServiceV2 _aiService;

  // State variables
  Uint8List? _encryptedBytes;
  String _encryptionMethodName = 'Auto-select';
  bool _busy = false;
  double _encryptProgress = 0.0;
  final TextEditingController _pinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    
    // Initialize handlers
    _handler = MultiFileTransmissionHandler();
    _encryptionSelector = EncryptionSelectorService();
    _aiService = AiTransmissionServiceV2();

    // Listen to progress updates
    _handler.onProgressUpdate = (progress) {
      if (mounted) {
        setState(() => _encryptProgress = progress);
      }
    };

    _handler.onStatusUpdate = (status) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(status)),
        );
      }
    };
  }

  // ============================================================================
  // BEFORE: Image-only file picker
  // ============================================================================
  /*
  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'bmp'],
    );
    
    if (result?.files.isEmpty ?? true) return;
    
    setState(() {
      _selectedImage = File(result!.files.first.path!);
    });
  }
  */

  // ============================================================================
  // AFTER: Multi-file picker
  // ============================================================================
  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      
      if (result?.files.isEmpty ?? true) {
        return;
      }

      final file = File(result!.files.first.path!);

      // Load file using universal processor
      setState(() => _busy = true);
      
      await _handler.selectAndLoadFile(file);

      // Show file info
      _showInfo(
        'File loaded\n'
        'Type: ${_handler.fileTypeName}\n'
        'Size: ${_handler.selectedFile?.sizeString}',
      );

      setState(() => _busy = false);

    } catch (e) {
      _showError('File selection failed: $e');
      setState(() => _busy = false);
    }
  }

  // ============================================================================
  // BEFORE: Single encryption method
  // ============================================================================
  /*
  Future<void> _performEncryption(Uint8List key) async {
    final imageBytes = await _selectedImage.readAsBytes();
    
    final encrypted = _encryptionService.encryptBytes(
      dataBytes: imageBytes,
      key: key,
    );
    
    setState(() {
      _encryptedBytes = encrypted;
    });
  }
  */

  // ============================================================================
  // AFTER: Intelligent encryption with method selection
  // ============================================================================
  Future<void> _performEncryption(Uint8List key) async {
    try {
      setState(() => _busy = true);

      final fileData = _handler.selectedFile;
      if (fileData == null) {
        _showError('No file selected');
        setState(() => _busy = false);
        return;
      }

      // Get channel state for intelligent selection
      final channelState = ChannelStateEstimate(
        snrDb: 15.0, // Example: 15 dB SNR
        noiseLevel: 0.1,
      );

      // Option 1: Use AI service v2 for smart selection
      final config = await _aiService.getOptimalConfiguration(
        fileData: fileData,
        channelState: channelState,
      );

      // Option 2: Use selector service for scoring
      final selectedMethod = _encryptionSelector.selectOptimalEncryption(
        fileData.metadata,
        channelState,
      );

      // Get encryption recommendations ranked by suitability
      final recommendations = await _aiService.getEncryptionRecommendations(
        fileData: fileData,
        sortBy: 'security', // or 'performance' or 'balanced'
      );

      // Display top recommendation
      if (recommendations.isNotEmpty) {
        final topRecommendation = recommendations.first;
        _showInfo(
          'Recommended encryption:\n'
          '${topRecommendation.methodName}\n'
          'Reason: ${topRecommendation.reason}',
        );
        setState(() => _encryptionMethodName = topRecommendation.methodName);
      }

      // Encrypt with selected method
      final encrypted = await _handler.encryptFile(encryptionKey: key);

      setState(() {
        _encryptedBytes = encrypted;
        _busy = false;
      });

      _showInfo(
        'Encrypted with $_encryptionMethodName\n'
        'Original: ${fileData.sizeString}\n'
        'Encrypted: ${(encrypted.length / 1024).toStringAsFixed(1)} KB',
      );

    } catch (e) {
      _showError('Encryption failed: $e');
      setState(() => _busy = false);
    }
  }

  // ============================================================================
  // NEW: Show available encryption methods for current file
  // ============================================================================
  Future<void> _showEncryptionOptions() async {
    try {
      final fileData = _handler.selectedFile;
      if (fileData == null) {
        _showError('No file selected');
        return;
      }

      final available = _handler.getAvailableEncryptions();

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Encryption Method'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: available.length,
              itemBuilder: (context, index) {
                final method = available[index];
                return ListTile(
                  title: Text(method.description),
                  subtitle: Text(
                    'Security: ${method.securityLevel}, '
                    'Speed: ${method.performanceLevel}',
                  ),
                  onTap: () {
                    setState(() => _encryptionMethodName = method.description);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ),
      );

    } catch (e) {
      _showError('Error loading options: $e');
    }
  }

  // ============================================================================
  // BEFORE: Audio encoding with image bytes only
  // ============================================================================
  /*
  Future<void> _encodeToAudio() async {
    if (_encryptedBytes?.isEmpty ?? true) {
      _showError('Encrypt the image first');
      return;
    }

    final packet = await _audioEncoder.encodeBytesToAudioFile(_encryptedBytes!);
    setState(() => _audioPacket = packet);
  }
  */

  // ============================================================================
  // AFTER: Audio encoding works with any file type
  // ============================================================================
  Future<void> _encodeToAudio() async {
    if (_encryptedBytes?.isEmpty ?? true) {
      _showError('Encrypt the file first');
      return;
    }

    try {
      setState(() => _busy = true);

      // Protection and audio encoding (unchanged)
      // This works with any encrypted file type
      final audioPacket = await _nrsts.protectAndEncodeToAudio(_encryptedBytes!);

      setState(() {
        // _audioPacket = audioPacket;
        _busy = false;
      });

      _showInfo(
        'Audio encoded\n'
        'Samples: ${audioPacket.audioData.length}\n'
        'Duration: ${(audioPacket.audioData.length / 44100).toStringAsFixed(2)}s',
      );

    } catch (e) {
      _showError('Audio encoding failed: $e');
      setState(() => _busy = false);
    }
  }

  // ============================================================================
  // Helper: Key derivation (unchanged, works with any file)
  // ============================================================================
  Future<Uint8List> _deriveKey(String pin, bool biometric) async {
    if (biometric) {
      // Biometric + PIN combination
      final biometricKey = Uint8List(32); // Get from secure storage
      final passphraseKey = _derivePassphraseKey(pin);
      
      // XOR combine
      return Uint8List.fromList(
        List.generate(32, (i) => biometricKey[i] ^ passphraseKey[i]),
      );
    } else {
      return _derivePassphraseKey(pin);
    }
  }

  Uint8List _derivePassphraseKey(String passphrase) {
    // PBKDF2 or similar (unchanged)
    return Uint8List(32);
  }

  // ============================================================================
  // Main encryption workflow (before encryption button)
  // ============================================================================
  Future<void> _onEncryptPressed() async {
    final pin = _pinController.text.trim();
    if (pin.isEmpty) {
      _showError('Enter PIN first');
      return;
    }

    if (_handler.selectedFile == null) {
      _showError('Select a file first');
      return;
    }

    try {
      // Derive encryption key
      final key = await _deriveKey(pin, false);

      // Perform encryption
      await _performEncryption(key);

      // Success - can now encode to audio
      _showInfo('Your ${_handler.fileTypeName} is ready for audio encoding');

    } catch (e) {
      _showError('Encryption process failed: $e');
    }
  }

  // ============================================================================
  // UI: File info card (replaces image preview)
  // ============================================================================
  Widget _buildFileInfoCard() {
    final fileData = _handler.selectedFile;

    if (fileData == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(Icons.file_copy, size: 64, color: Colors.grey),
              const SizedBox(height: 8),
              const Text('No file selected', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_getFileTypeIcon(fileData.metadata.category), size: 48),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileData.metadata.fileName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Type: ${_handler.fileTypeName}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        'Size: ${fileData.sizeString}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_encryptedBytes != null) ...[
              const Divider(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Encryption',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _encryptionMethodName,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Encrypted Size',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${(_encryptedBytes!.length / 1024).toStringAsFixed(1)} KB',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getFileTypeIcon(FileCategory category) {
    switch (category) {
      case FileCategory.image:
        return Icons.image;
      case FileCategory.text:
        return Icons.description;
      case FileCategory.structured:
        return Icons.picture_as_pdf;
      case FileCategory.binary:
        return Icons.library_books;
    }
  }

  // ============================================================================
  // Simple dialogs
  // ============================================================================
  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _handler.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Encrypted File'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // PIN input
            TextField(
              controller: _pinController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Enter PIN',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 24),

            // File selection
            Text(
              'Select File',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _busy ? null : _pickFile,
              label: const Text('Pick File'),
              icon: const Icon(Icons.folder_open),
            ),
            const SizedBox(height: 16),

            // File info
            _buildFileInfoCard(),
            const SizedBox(height: 16),

            // Show encryption options
            if (_handler.selectedFile != null)
              ElevatedButton(
                onPressed: _showEncryptionOptions,
                child: const Text('View Encryption Options'),
              ),
            const SizedBox(height: 16),

            // Encryption button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _onEncryptPressed,
                icon: _busy ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ) : const Icon(Icons.lock),
                label: Text(
                  _busy ? 'Encrypting... ${(_encryptProgress * 100).toStringAsFixed(0)}%' : 'Encrypt File',
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Audio encoding button
            if (_encryptedBytes != null)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _encodeToAudio,
                  icon: const Icon(Icons.audio_file),
                  label: const Text('Encode to Audio'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
