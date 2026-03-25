import 'package:flutter/material.dart';

import '../utils/app_colors.dart';
import '../utils/color_extensions.dart';

class SettingsScreen extends StatelessWidget {
  static const String routeName = '/settings';

  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.slate400 : AppColors.slate600;

    Widget section({required String title, required Widget child}) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.slate900.withOpacity01(0.50),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primary.withOpacity01(0.10)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: TextStyle(
                color: primary.withOpacity01(0.70),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 10),
            DefaultTextStyle(
              style: TextStyle(color: muted, fontSize: 13, height: 1.3),
              child: child,
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Settings'.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3.0,
                        color: isDark ? Colors.white : AppColors.slate900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  children: [
                    section(
                      title: 'Security',
                      child: const Text(
                        'Two key modes are available:\n\n'
                        '• Device-only (default): fingerprint + PIN required. The key ties to this device — only this phone can decrypt.\n\n'
                        '• Cross-device: toggle "Cross-Device Mode" on both Sender and Receiver, then share a strong passphrase. Any device with the same passphrase can decrypt — no biometric needed.',
                      ),
                    ),
                    const SizedBox(height: 16),
                    section(
                      title: 'Lossless',
                      child: const Text(
                        'For zero quality loss, the Sender transmits the original image file bytes and the Receiver verifies integrity with SHA-256.\n\nImportant: share the generated .wav as a file/document (do not send as a voice note or re-record it), otherwise audio transcoding can corrupt data.',
                      ),
                    ),
                    const SizedBox(height: 16),
                    section(
                      title: 'Storage',
                      child: const Text(
                        'Audio exports: /storage/emulated/0/EncryptAudio\nDecoded images: /storage/emulated/0/DecodedImage',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
