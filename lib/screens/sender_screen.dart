import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'history_screen.dart';
import 'settings_screen.dart';
import '../models/audio_packet.dart';
import '../models/history_entry.dart';
import '../services/audio_encoder.dart';
import '../services/biometric_auth_service.dart';
import '../services/biometric_key_service.dart';
import '../services/combined_key_service.dart';
import '../services/encryption_service.dart';
import '../services/history_service.dart';
import '../services/image_processor.dart';
import '../services/noise_resistant_transmission_service.dart';
import '../services/passphrase_key_service.dart';
import '../services/permission_service.dart';
import '../utils/app_colors.dart';
import '../utils/color_extensions.dart';
import '../utils/ui_decorations.dart';

class SenderScreen extends StatefulWidget {
  static const String routeName = '/sender';

  const SenderScreen({super.key});

  @override
  State<SenderScreen> createState() => _SenderScreenState();
}

class _SenderScreenState extends State<SenderScreen> {
  final ImageProcessor _imageProcessor = ImageProcessor();
  final BiometricAuthService _biometricAuth = BiometricAuthService();
  final BiometricKeyService _biometricKeyService = BiometricKeyService();
  final CombinedKeyService _combinedKeyService = CombinedKeyService();
  final PassphraseKeyService _passphraseKeyService = PassphraseKeyService();
  final EncryptionService _encryptionService = EncryptionService();
  final HistoryService _history = HistoryService();
  final NoiseResistantTransmissionService _nrsts =
    NoiseResistantTransmissionService();
  final NoiseResistantTransmissionService _nrstsNoRepetition =
    NoiseResistantTransmissionService(repetitions: 1);
  final AudioEncoder _audioEncoder = AudioEncoder();

  final TextEditingController _pinController = TextEditingController();
  bool _crossDevice = false;

  bool _busy = false;

  File? _selectedImage;
  Uint8List? _encryptedBytes;
  AudioPacket? _audioPacket;
  File? _savedAudioFile;

  static const _visualizerHeights = <double>[
    16,
    32,
    48,
    24,
    64,
    40,
    80,
    56,
    96,
    72,
    48,
    32,
    16,
    40,
    64,
    24,
    80,
    48,
    32,
    16,
  ];

  Future<void> _pickImage() async {
    await PermissionService.requestImagePickerPermissions();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'bmp', 'webp'],
    );

    if (!mounted) return;

    final path = result?.files.single.path;
    if (path == null) {
      return;
    }

    setState(() {
      _selectedImage = File(path);
      _encryptedBytes = null;
      _audioPacket = null;
      _savedAudioFile = null;
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _encryptImage() async {
    final imageFile = _selectedImage;
    if (imageFile == null) {
      _showSnackBar('Select an image first.');
      return;
    }

    final pin = _pinController.text;
    if (pin.trim().isEmpty) {
      _showSnackBar('Enter a PIN first.');
      return;
    }

    setState(() => _busy = true);
    try {
      final payload = await _imageProcessor.convertImageToBinary(imageFile);

      final Uint8List key;
      if (_crossDevice) {
        key = _passphraseKeyService.deriveKey(pin);
      } else {
        final authed = await _biometricAuth.authenticate(
          reason: 'Verify your fingerprint to encrypt this image.',
        );
        if (!authed) {
          _showSnackBar('Fingerprint authentication cancelled.');
          return;
        }
        final biometricKey =
            await _biometricKeyService.getOrCreateBiometricKey();
        key = _combinedKeyService.deriveCombinedKey(
          biometricKey: biometricKey,
          pin: pin,
        );
      }

      final encrypted = _encryptionService.encryptBytes(
        dataBytes: payload.payloadBytes,
        key: key,
      );

      if (!mounted) return;
      setState(() {
        _encryptedBytes = encrypted;
        _audioPacket = null;
        _savedAudioFile = null;
      });
      _showSnackBar('Image encrypted.');
    } catch (e) {
      _showSnackBar('Encryption failed: $e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _convertToAudio() async {
    final encryptedBytes = _encryptedBytes;
    if (encryptedBytes == null) {
      _showSnackBar('Encrypt the image first.');
      return;
    }

    setState(() => _busy = true);
    try {
      AudioPacket packet;
      bool reducedRedundancy = false;

      try {
        final protectedBytes = _nrsts.protectEncryptedBytes(encryptedBytes);
        packet = await _audioEncoder.encodeBytesToAudioFile(protectedBytes);
      } on FormatException catch (e) {
        // If the FEC+repetition payload would exceed the WAV 4GB size limit,
        // retry with repetition disabled (still keeping Reed–Solomon parity).
        if (!e.message.contains('exceeds 4GB limit')) {
          rethrow;
        }

        final protectedBytes = _nrstsNoRepetition.protectEncryptedBytes(
          encryptedBytes,
        );
        packet = await _audioEncoder.encodeBytesToAudioFile(protectedBytes);
        reducedRedundancy = true;
      }

      if (!mounted) return;
      setState(() {
        _audioPacket = packet;
        _savedAudioFile = null;
      });
      _showSnackBar(
        reducedRedundancy
            ? 'Audio waveform generated (repetition reduced to fit WAV size limit).'
            : 'Audio waveform generated (NRSTS protected).',
      );
    } catch (e) {
      _showSnackBar('Audio encoding failed: $e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _saveAudio() async {
    final packet = _audioPacket;
    if (packet == null) {
      _showSnackBar('Convert to audio first.');
      return;
    }

    setState(() => _busy = true);
    try {
      await PermissionService.requestAudioSavePermissions();

      final File file;
      if (packet.wavBytes != null) {
        file = await _audioEncoder.saveAudioFile(packet.wavBytes!);
      } else if (packet.wavFilePath != null) {
        file = await _audioEncoder.saveAudioFileFromPath(packet.wavFilePath!);
      } else {
        throw StateError('No audio data available to export.');
      }

      if (!mounted) return;
      setState(() {
        _savedAudioFile = file;
        _audioPacket = AudioPacket(
          sampleRate: packet.sampleRate,
          bitDurationMs: packet.bitDurationMs,
          frequency0Hz: packet.frequency0Hz,
          frequency1Hz: packet.frequency1Hz,
          wavFilePath: file.path,
        );
      });

      try {
        await _history.addEntry(
          HistoryEntry(
            timestampMs: DateTime.now().millisecondsSinceEpoch,
            title: 'Audio Exported',
            detail: 'Encrypted payload encoded to WAV',
            path: file.path,
          ),
        );
      } catch (_) {
        // Best-effort; history should not block export.
      }
      _showSnackBar('Saved: ${file.path}');
    } catch (e) {
      _showSnackBar('Saving failed: $e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _fileName(File? file) {
    if (file == null) return '-';
    final parts = file.path.split(Platform.pathSeparator);
    return parts.isNotEmpty ? parts.last : file.path;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.slate400 : AppColors.slate600;

    final step1Done = _selectedImage != null;
    final step2Done = _encryptedBytes != null;
    final step3Done = _audioPacket != null;
    final activeStep = !step1Done ? 1 : (!step2Done ? 2 : (!step3Done ? 3 : 3));

    final canEncrypt = !_busy && _selectedImage != null;
    final canEncode = !_busy && _encryptedBytes != null;
    final canExport = !_busy && _audioPacket != null;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: primary.withOpacity01(0.10)),
                    ),
                    color: Theme.of(context).scaffoldBackgroundColor,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: Center(
                          child: Icon(Icons.shield, size: 30, color: primary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Secure Audio Sender',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.slate900,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: Center(
                          child: InkWell(
                            onTap: () => Navigator.pushNamed(
                              context,
                              SettingsScreen.routeName,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: primary.withOpacity01(0.10),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.settings, color: primary),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Column(
                      children: [
                        _ProgressStepper(
                          primary: primary,
                          activeStep: activeStep,
                          step1Done: step1Done,
                          step2Done: step2Done,
                          step3Done: step3Done,
                        ),
                        const SizedBox(height: 16),
                        AspectRatio(
                          aspectRatio: 1,
                          child: DashedBorderContainer(
                            borderColor: primary.withOpacity01(0.30),
                            backgroundColor: primary.withOpacity01(0.05),
                            borderRadius: 12,
                            padding: const EdgeInsets.all(0),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (_selectedImage != null)
                                  Opacity(
                                    opacity: 0.40,
                                    child: Image.file(
                                      _selectedImage!,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 80,
                                          height: 80,
                                          decoration: BoxDecoration(
                                            color: primary.withOpacity01(0.10),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.add_photo_alternate,
                                            size: 44,
                                            color: primary,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          _selectedImage == null
                                              ? 'No Image Selected'
                                              : 'Selected: ${_fileName(_selectedImage)}',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? Colors.white
                                                : AppColors.slate900,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _selectedImage == null
                                              ? 'Select an image to begin the secure encryption process.'
                                              : 'Ready to verify fingerprint and encrypt.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: muted,
                                            fontSize: 13,
                                            height: 1.3,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        FilledButton(
                                          onPressed: _busy ? null : _pickImage,
                                          style: FilledButton.styleFrom(
                                            backgroundColor: primary,
                                            foregroundColor:
                                                AppColors.backgroundDark,
                                            shape: const StadiumBorder(),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 28,
                                              vertical: 14,
                                            ),
                                          ),
                                          child: const Text(
                                            'Select Image',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.slate900.withOpacity01(0.50),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.slate800),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.devices,
                                color: _crossDevice ? primary : muted,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Cross-Device Mode',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : AppColors.slate900,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _crossDevice
                                          ? 'Any device with the same passphrase can decrypt'
                                          : 'Only this device (biometric + PIN)',
                                      style: TextStyle(
                                        color: muted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _crossDevice,
                                activeColor: primary,
                                onChanged: (v) => setState(() {
                                  _crossDevice = v;
                                  _pinController.clear();
                                }),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.slate900.withOpacity01(0.50),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.slate800),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (_crossDevice ? 'Passphrase' : 'PIN')
                                    .toUpperCase(),
                                style: TextStyle(
                                  color: isDark
                                      ? AppColors.slate500
                                      : AppColors.slate600,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2.0,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _pinController,
                                obscureText: true,
                                enableSuggestions: false,
                                autocorrect: false,
                                keyboardType: _crossDevice
                                    ? TextInputType.visiblePassword
                                    : TextInputType.number,
                                inputFormatters: _crossDevice
                                    ? []
                                    : [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                decoration: InputDecoration(
                                  hintText: _crossDevice
                                      ? 'Shared passphrase (same on all devices)'
                                      : 'Use the same PIN on Receiver',
                                  hintStyle: TextStyle(color: muted),
                                  filled: true,
                                  fillColor: AppColors.backgroundDark,
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: primary.withOpacity01(0.25),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: primary),
                                  ),
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 14,
                                  ),
                                ),
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.slate900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _TileButton(
                                enabled: canEncrypt,
                                primary: primary,
                                icon: _crossDevice
                                    ? Icons.lock_open
                                    : Icons.fingerprint,
                                label: _crossDevice ? 'Encrypt' : 'Fingerprint',
                                onTap: _encryptImage,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _TileButton(
                                enabled: canEncode,
                                primary: primary,
                                icon: Icons.graphic_eq,
                                label: 'Convert Audio',
                                onTap: _convertToAudio,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.slate900.withOpacity01(0.50),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.slate800),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Audio Output Visualizer'.toUpperCase(),
                                    style: TextStyle(
                                      color: isDark
                                          ? AppColors.slate500
                                          : AppColors.slate600,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2.0,
                                    ),
                                  ),
                                  Text(
                                    '00:00 / 00:12',
                                    style: TextStyle(
                                      color: primary,
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 96,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    for (final h in _visualizerHeights)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 2,
                                        ),
                                        child: Container(
                                          width: 3,
                                          height: h,
                                          decoration: BoxDecoration(
                                            color: primary.withOpacity01(0.40),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              InkWell(
                                onTap: canExport ? _saveAudio : null,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: primary.withOpacity01(0.10),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: primary.withOpacity01(0.30),
                                    ),
                                  ),
                                  child: Opacity(
                                    opacity: canExport ? 1.0 : 0.40,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.ios_share, color: primary),
                                        const SizedBox(width: 10),
                                        Text(
                                          'Export & Send Secure Audio',
                                          style: TextStyle(
                                            color: primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              if (_savedAudioFile != null) ...[
                                const SizedBox(height: 10),
                                Text(
                                  'Saved: ${_fileName(_savedAudioFile)}',
                                  style: TextStyle(
                                    color: muted,
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_busy)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x66000000),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          decoration: BoxDecoration(
            color: AppColors.backgroundDark.withOpacity01(0.80),
            border: Border(
              top: BorderSide(color: AppColors.slate800.withOpacity01(0.50)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _BottomItem(
                  icon: Icons.send,
                  label: 'Sender',
                  active: true,
                ),
              ),
              Expanded(
                child: _BottomItem(
                  icon: Icons.cached,
                  label: 'Vault',
                  active: false,
                ),
              ),
              Expanded(
                child: _BottomItem(
                  icon: Icons.history,
                  label: 'History',
                  active: false,
                  onTap: () => Navigator.pushNamed(
                    context,
                    HistoryScreen.routeName,
                  ),
                ),
              ),
              Expanded(
                child: _BottomItem(
                  icon: Icons.account_circle,
                  label: 'Profile',
                  active: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressStepper extends StatelessWidget {
  final Color primary;
  final int activeStep;
  final bool step1Done;
  final bool step2Done;
  final bool step3Done;

  const _ProgressStepper({
    required this.primary,
    required this.activeStep,
    required this.step1Done,
    required this.step2Done,
    required this.step3Done,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.center,
              child: Container(height: 2, color: primary.withOpacity01(0.20)),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Step(
                number: 1,
                label: 'Select',
                primary: primary,
                active: activeStep == 1,
                done: step1Done,
              ),
              _Step(
                number: 2,
                label: 'Encrypt',
                primary: primary,
                active: activeStep == 2,
                done: step2Done,
              ),
              _Step(
                number: 3,
                label: 'Encode',
                primary: primary,
                active: activeStep == 3,
                done: step3Done,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int number;
  final String label;
  final Color primary;
  final bool active;
  final bool done;

  const _Step({
    required this.number,
    required this.label,
    required this.primary,
    required this.active,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    final enabledColor = primary;
    final disabledBg = AppColors.slate800;
    final disabledBorder = primary.withOpacity01(0.30);

    final bg = (done || active) ? enabledColor : disabledBg;
    final textColor = (done || active)
        ? AppColors.backgroundDark
        : AppColors.slate400;
    final border = (done || active) ? Colors.transparent : disabledBorder;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(color: border, width: 2),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: enabledColor.withOpacity01(0.50),
                      blurRadius: 15,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              '$number',
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            color: (done || active) ? enabledColor : AppColors.slate500,
          ),
        ),
      ],
    );
  }
}

class _TileButton extends StatelessWidget {
  final bool enabled;
  final Color primary;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _TileButton({
    required this.enabled,
    required this.primary,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.50,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.slate800.withOpacity01(0.50),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.slate700),
          ),
          child: Column(
            children: [
              Icon(icon, color: primary),
              const SizedBox(height: 8),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: isDark(context)
                      ? AppColors.slate100
                      : AppColors.slate900,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
}

class _BottomItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _BottomItem({
    required this.icon,
    required this.label,
    required this.active,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final color = active ? primary : AppColors.slate500;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
