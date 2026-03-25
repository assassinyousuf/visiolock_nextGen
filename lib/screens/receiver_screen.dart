import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'history_screen.dart';
import 'settings_screen.dart';
import '../models/history_entry.dart';
import '../services/audio_decoder.dart';
import '../services/biometric_auth_service.dart';
import '../services/biometric_key_service.dart';
import '../services/combined_key_service.dart';
import '../services/encryption_service.dart';
import '../services/history_service.dart';
import '../services/image_reconstructor.dart';
import '../services/noise_resistant_transmission_service.dart';
import '../services/passphrase_key_service.dart';
import '../services/permission_service.dart';
import '../utils/app_colors.dart';
import '../utils/color_extensions.dart';
import '../utils/ui_decorations.dart';

class ReceiverScreen extends StatefulWidget {
  static const String routeName = '/receiver';

  const ReceiverScreen({super.key});

  @override
  State<ReceiverScreen> createState() => _ReceiverScreenState();
}

class _ReceiverScreenState extends State<ReceiverScreen> {
  final AudioDecoder _audioDecoder = AudioDecoder();
  final BiometricAuthService _biometricAuth = BiometricAuthService();
  final BiometricKeyService _biometricKeyService = BiometricKeyService();
  final CombinedKeyService _combinedKeyService = CombinedKeyService();
  final PassphraseKeyService _passphraseKeyService = PassphraseKeyService();
  final EncryptionService _encryptionService = EncryptionService();
  final ImageReconstructor _imageReconstructor = ImageReconstructor();
  final HistoryService _history = HistoryService();
  final NoiseResistantTransmissionService _nrsts =
      NoiseResistantTransmissionService();

  final TextEditingController _pinController = TextEditingController();
  bool _crossDevice = false;

  bool _busy = false;

  File? _audioFile;
  bool _signalDecoded = false;
  bool _payloadDecrypted = false;
  Uint8List? _pngBytes;
  String? _decodedExtension;
  String? _payloadMagic;
  bool _integrityVerified = false;

  static const _spectrumHeights = <double>[
    60,
    40,
    85,
    25,
    95,
    55,
    75,
    35,
    65,
    45,
    90,
    20,
    50,
    80,
    30,
    70,
  ];

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _importAudio() async {
    await PermissionService.requestAudioPickerPermissions();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['wav'],
    );

    if (!mounted) return;

    final path = result?.files.single.path;
    if (path == null) {
      return;
    }

    setState(() {
      _audioFile = File(path);
      _signalDecoded = false;
      _payloadDecrypted = false;
      _pngBytes = null;
      _decodedExtension = null;
      _payloadMagic = null;
      _integrityVerified = false;
    });

    await _processSelectedAudio();
  }

  Future<void> _processSelectedAudio() async {
    final file = _audioFile;
    if (file == null) {
      return;
    }

    final pin = _pinController.text;
    if (pin.trim().isEmpty) {
      _showSnackBar('Enter a PIN first.');
      return;
    }

    setState(() => _busy = true);
    try {
      final Uint8List key;
      if (_crossDevice) {
        key = _passphraseKeyService.deriveKey(pin);
      } else {
        final authed = await _biometricAuth.authenticate(
          reason: 'Verify your fingerprint to decrypt this audio.',
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

      const legacyBitDurationMs = 20;
      const legacyF0 = 500.0;
      const legacyF1 = 1200.0;

      final attempts = <({int? durationMs, double? f0, double? f1, String tag})>[
        (durationMs: null, f0: null, f1: null, tag: ''),
        (durationMs: null, f0: legacyF0, f1: legacyF1, tag: 'legacy frequencies'),
        (durationMs: legacyBitDurationMs, f0: null, f1: null, tag: 'legacy timing'),
        (
          durationMs: legacyBitDurationMs,
          f0: legacyF0,
          f1: legacyF1,
          tag: 'legacy timing + frequencies',
        ),
      ];

      Object? lastError;
      for (final a in attempts) {
        try {
          final rawBytes = await _audioDecoder.decodeAudioToBytes(
            file,
            bitDurationMsOverride: a.durationMs,
            frequency0HzOverride: a.f0,
            frequency1HzOverride: a.f1,
          );
          final recoveredEncryptedBytes = _nrsts.recoverEncryptedBytes(rawBytes);
          final decryptedBytes = _encryptionService.decryptBytes(
            encryptedBytes: recoveredEncryptedBytes,
            key: key,
          );
          final decodedImage =
              _imageReconstructor.reconstructImageFromPayloadBytes(decryptedBytes);

          if (!mounted) return;
          setState(() {
            _signalDecoded = true;
            _payloadDecrypted = true;
            _pngBytes = decodedImage.bytes;
            _decodedExtension = decodedImage.extension;
            _payloadMagic = decodedImage.payloadMagic;
            _integrityVerified = decodedImage.integrityVerified;
          });

          final suffix = a.tag.isEmpty ? '' : ', ${a.tag}';
          if (decodedImage.integrityVerified) {
            _showSnackBar(
              'Image reconstructed (lossless verified$suffix, ${decodedImage.bytes.length} bytes).',
            );
          } else if (decodedImage.payloadMagic == 'I2A2') {
            _showSnackBar(
              'Image reconstructed (lossless, unverified$suffix, ${decodedImage.bytes.length} bytes).',
            );
          } else {
            _showSnackBar(
              'Decoded legacy audio (I2A1$suffix, ${decodedImage.bytes.length} bytes). Re-encode with updated Sender for full quality.',
            );
          }
          return;
        } catch (e) {
          lastError = e;
        }
      }

      throw lastError ?? const FormatException('Receiver failed to decode.');
    } catch (e) {
      _showSnackBar('Receiver failed: $e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _saveDecodedImage() async {
    final png = _pngBytes;
    if (png == null) {
      return;
    }

    setState(() => _busy = true);
    try {
      await PermissionService.requestDecodedImageSavePermissions();

      Directory dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/DecodedImage');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      final ext = (_decodedExtension ?? 'png').replaceAll('.', '');
      final name = 'decoded_image_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final file = File('${dir.path}${Platform.pathSeparator}$name');
      await file.writeAsBytes(png, flush: true);

      try {
        final detail = _integrityVerified
            ? 'Lossless verified (I2A3)'
            : (_payloadMagic == 'I2A2'
                ? 'Lossless unverified (I2A2)'
                : 'Legacy reconstruction (I2A1)');
        await _history.addEntry(
          HistoryEntry(
            timestampMs: DateTime.now().millisecondsSinceEpoch,
            title: 'Image Saved',
            detail: detail,
            path: file.path,
          ),
        );
      } catch (_) {
        // Best-effort; history should not block saving.
      }

      if (!mounted) return;
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

    final step1Done = _audioFile != null;
    final step2Done = _signalDecoded;
    final step3Done = _payloadDecrypted;

    final canSave = !_busy && _pngBytes != null;

    final progress = _pngBytes != null
      ? 1.0
      : (_payloadDecrypted
          ? 0.80
          : (_signalDecoded ? 0.64 : (_audioFile != null ? 0.32 : 0.0)));
    final percent = (progress * 100).round();

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
                      IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        icon: Icon(Icons.arrow_back, color: primary),
                      ),
                      Expanded(
                        child: Text(
                          'Receiver: Secure Decode',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.slate900,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.shield, color: primary),
                          const SizedBox(width: 6),
                          Text(
                            'ENCRYPTED CHANNEL',
                            style: TextStyle(
                              color: primary.withOpacity01(0.60),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Column(
                      children: [
                        _ReceiverStepper(
                          primary: primary,
                          step1Done: step1Done,
                          step2Done: step2Done,
                          step3Done: step3Done,
                        ),
                        const SizedBox(height: 16),
                        DashedBorderContainer(
                          borderColor: primary.withOpacity01(0.30),
                          backgroundColor: primary.withOpacity01(0.05),
                          borderRadius: 12,
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: primary.withOpacity01(0.10),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.upload_file,
                                  size: 36,
                                  color: primary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Signal Source',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.slate900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Selected: ${_fileName(_audioFile)}',
                                style: TextStyle(color: muted, fontSize: 13),
                              ),
                              const SizedBox(height: 14),
                              FilledButton(
                                onPressed: _busy ? null : _importAudio,
                                style: FilledButton.styleFrom(
                                  backgroundColor: primary,
                                  foregroundColor: AppColors.backgroundDark,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 22,
                                    vertical: 12,
                                  ),
                                ),
                                child: const Text(
                                  'Change Source',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
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
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) {
                                  if (_busy) return;
                                  _processSelectedAudio();
                                },
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
                                      : 'Enter the same PIN used on Sender',
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
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.slate900.withOpacity01(0.50),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: primary.withOpacity01(0.10),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Frequency Spectrum Analysis'
                                          .toUpperCase(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: primary.withOpacity01(0.70),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 2.0,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '44.1kHz | 16-bit',
                                    maxLines: 1,
                                    overflow: TextOverflow.fade,
                                    softWrap: false,
                                    style: TextStyle(
                                      color: primary.withOpacity01(0.50),
                                      fontSize: 10,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 96,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    for (final h in _spectrumHeights)
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 2,
                                          ),
                                          child: Container(
                                            height: h,
                                            decoration: BoxDecoration(
                                              color: primary.withOpacity01(
                                                0.40,
                                              ),
                                              borderRadius:
                                                  const BorderRadius.vertical(
                                                    top: Radius.circular(2),
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Reconstructed Image Preview'.toUpperCase(),
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.slate400
                                  : AppColors.slate600,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        AspectRatio(
                          aspectRatio: 1,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: primary.withOpacity01(0.20),
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        primary.withOpacity01(0.10),
                                        AppColors.backgroundDark,
                                        primary.withOpacity01(0.05),
                                      ],
                                    ),
                                  ),
                                ),
                                if (_pngBytes != null)
                                  Image.memory(_pngBytes!, fit: BoxFit.contain),
                                if (_pngBytes == null)
                                  Container(
                                    color: AppColors.backgroundDark
                                        .withOpacity01(0.80),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.leak_add,
                                            size: 64,
                                            color: primary.withOpacity01(0.40),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            _busy
                                                ? 'Processing Data Packets...'
                                                : 'Awaiting Signal...',
                                            style: TextStyle(
                                              color: primary.withOpacity01(
                                                0.60,
                                              ),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          AppColors.backgroundDark
                                              .withOpacity01(0.90),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'Progress'.toUpperCase(),
                                                style: TextStyle(
                                                  color: primary.withOpacity01(
                                                    0.70,
                                                  ),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 2.0,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                                child: SizedBox(
                                                  height: 6,
                                                  child:
                                                      LinearProgressIndicator(
                                                        value: progress,
                                                        backgroundColor:
                                                            AppColors.slate800,
                                                        color: primary,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          '$percent%',
                                          style: TextStyle(
                                            color: primary,
                                            fontSize: 22,
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.bold,
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
                        InkWell(
                          onTap: canSave ? _saveDecodedImage : null,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: primary.withOpacity01(0.20),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: primary.withOpacity01(0.30),
                              ),
                            ),
                            child: Opacity(
                              opacity: canSave ? 1.0 : 0.50,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.download, color: primary),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Save Decoded Image',
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
                        const SizedBox(height: 10),
                        Text(
                          'Encryption Key: Biometric Secret + PIN (SHA-256) (XOR)'
                              .toUpperCase(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: muted,
                            fontSize: 10,
                            letterSpacing: 0.5,
                            fontStyle: FontStyle.italic,
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
          height: 64,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(top: BorderSide(color: primary.withOpacity01(0.10))),
          ),
          child: Row(
            children: [
              Expanded(
                child: _BottomItem(
                  icon: Icons.radio,
                  label: 'Receiver',
                  active: true,
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
                  icon: Icons.settings,
                  label: 'Settings',
                  active: false,
                  onTap: () => Navigator.pushNamed(
                    context,
                    SettingsScreen.routeName,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiverStepper extends StatelessWidget {
  final Color primary;
  final bool step1Done;
  final bool step2Done;
  final bool step3Done;

  const _ReceiverStepper({
    required this.primary,
    required this.step1Done,
    required this.step2Done,
    required this.step3Done,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.slate400 : AppColors.slate600;

    return Column(
      children: [
        _StepRow(
          primary: primary,
          active: !step1Done,
          done: step1Done,
          icon: step1Done ? Icons.check_circle : Icons.upload_file,
          title: 'Step 1: Import Audio',
          subtitle: step1Done
              ? 'Audio source verified and loaded'
              : 'Select a WAV signal source',
          connectorColor: step1Done ? primary : primary.withOpacity01(0.20),
          subtitleColor: muted,
        ),
        _StepRow(
          primary: primary,
          active: step1Done && !step2Done,
          done: step2Done,
          icon: Icons.analytics,
          title: 'Step 2: Decode Signal',
          subtitle: step2Done
              ? 'Binary payload extracted'
              : 'Extracting image data from frequency waves',
          connectorColor: step2Done
              ? primary
              : (isDark ? AppColors.slate800 : AppColors.slate700),
          subtitleColor: muted,
        ),
        _StepRow(
          primary: primary,
          active: step2Done && !step3Done,
          done: step3Done,
          icon: Icons.lock_open,
          title: 'Step 3: Decrypt Image',
          subtitle: step3Done
              ? 'Decryption complete'
              : 'Awaiting full signal extraction',
          connectorColor: Colors.transparent,
          showConnector: false,
          subtitleColor: muted,
          dimWhenInactive: !step2Done,
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  final Color primary;
  final bool active;
  final bool done;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color connectorColor;
  final bool showConnector;
  final Color subtitleColor;
  final bool dimWhenInactive;

  const _StepRow({
    required this.primary,
    required this.active,
    required this.done,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.connectorColor,
    required this.subtitleColor,
    this.showConnector = true,
    this.dimWhenInactive = false,
  });

  @override
  Widget build(BuildContext context) {
    final isInactive = dimWhenInactive && !active && !done;

    final circleBg = done
        ? primary.withOpacity01(0.20)
        : (active ? primary : Colors.transparent);

    final circleBorder = done
        ? Colors.transparent
        : (active
              ? Colors.transparent
              : (Theme.of(context).brightness == Brightness.dark
                    ? AppColors.slate800
                    : AppColors.slate700));

    final iconColor = active
        ? AppColors.backgroundDark
        : (done ? primary : AppColors.slate500);

    return Opacity(
      opacity: isInactive ? 0.65 : 1.0,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: circleBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: circleBorder, width: 1),
                  ),
                  child: Center(child: Icon(icon, size: 18, color: iconColor)),
                ),
                if (showConnector)
                  Container(width: 2, height: 32, color: connectorColor),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: active
                          ? primary
                          : (done
                                ? (Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : AppColors.slate900)
                                : subtitleColor),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: subtitleColor),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
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
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
