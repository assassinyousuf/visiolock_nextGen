import 'package:flutter/material.dart';

import 'history_screen.dart';
import 'receiver_screen.dart';
import 'settings_screen.dart';
import 'sender_screen.dart';
import 'visiolock_sender_screen.dart';
import '../utils/app_colors.dart';
import '../utils/color_extensions.dart';
import '../utils/ui_decorations.dart';

class HomeScreen extends StatelessWidget {
  static const String routeName = '/';

  const HomeScreen({super.key});

  static const _waveHeights = <double>[32, 56, 80, 48, 64, 24, 72];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = cs.primary;
    final onBg = isDark ? Colors.white : AppColors.slate900;
    final muted = isDark ? AppColors.slate400 : AppColors.slate600;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: BinaryPatternBackground(
                dotColor: primary.withOpacity01(0.10),
                opacity: 0.20,
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 256,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        primary.withOpacity01(0.05),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Column(
              children: [
                _HeaderBar(
                  title: 'DataSymphony',
                  onSettingsPressed: () => Navigator.pushNamed(
                    context,
                    SettingsScreen.routeName,
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            children: [
                              const SizedBox(height: 24),
                              Text(
                                'Secure AudioBridge',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: onBg,
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'DEVICE-BOUND ENCRYPTION',
                                style: TextStyle(
                                  color: primary.withOpacity01(0.70),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 2.4,
                                ),
                              ),
                              const SizedBox(height: 24),
                              AspectRatio(
                                aspectRatio: 16 / 9,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: primary.withOpacity01(0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: primary.withOpacity01(0.20),
                                    ),
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            for (var i = 0; i < _waveHeights.length; i++)
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                                child: Container(
                                                  width: 8,
                                                  height: _waveHeights[i],
                                                  decoration: BoxDecoration(
                                                    color: primary.withOpacity01(
                                                      [0.40, 0.60, 1.0, 0.80, 0.50, 0.30, 0.70][i],
                                                    ),
                                                    borderRadius: BorderRadius.circular(999),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'SYSTEM STANDING BY...',
                                          style: TextStyle(
                                            color: primary.withOpacity01(0.50),
                                            fontSize: 10,
                                            fontFamily: 'monospace',
                                            letterSpacing: 3.0,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              _ActionButton(
                                filled: true,
                                icon: Icons.description_outlined,
                                label: 'Secure File',
                                onTap: () => Navigator.pushNamed(
                                  context,
                                  VisiolockSenderScreen.routeName,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _ActionButton(
                                filled: false,
                                icon: Icons.image_outlined,
                                label: 'Legacy Image Transfer',
                                onTap: () => Navigator.pushNamed(
                                  context,
                                  SenderScreen.routeName,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _ActionButton(
                                filled: false,
                                icon: Icons.settings_input_antenna,
                                label: 'Receive & Decode',
                                onTap: () => Navigator.pushNamed(
                                  context,
                                  ReceiverScreen.routeName,
                                ),
                              ),
                              const SizedBox(height: 28),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: primary.withOpacity01(0.10)),
                          ),
                          color: isDark
                              ? AppColors.backgroundDark.withOpacity01(0.50)
                              : AppColors.backgroundLight,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: primary,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Device Secure: ',
                                  style: TextStyle(
                                    color: muted,
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                Text(
                                  'YES',
                                  style: TextStyle(
                                    color: primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Last Session: -',
                              style: TextStyle(
                                color: muted,
                                fontSize: 11,
                                fontFamily: 'monospace',
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNavBar(
        items: [
          const _BottomNavItem(label: 'Home', icon: Icons.home, active: true),
          const _BottomNavItem(label: 'Vault', icon: Icons.lock, active: false),
          _BottomNavItem(
            label: 'History',
            icon: Icons.history,
            active: false,
            onTap: () => Navigator.pushNamed(context, HistoryScreen.routeName),
          ),
        ],
      ),
    );
  }
}

class _HeaderBar extends StatelessWidget {
  final String title;
  final VoidCallback? onSettingsPressed;

  const _HeaderBar({
    required this.title,
    required this.onSettingsPressed,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(color: primary.withOpacity01(0.10)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Icon(
                Icons.shield,
                size: 30,
                color: primary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              title.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.slate900,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 3.2,
              ),
            ),
          ),
          SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: InkWell(
                onTap: onSettingsPressed,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: primary.withOpacity01(0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.settings,
                    color: primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final bool filled;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.filled,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final bg = Theme.of(context).scaffoldBackgroundColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: filled ? primary : primary.withOpacity01(0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: filled ? Colors.transparent : primary.withOpacity01(0.30),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 32,
              color: filled ? bg : primary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: filled ? bg : primary,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: filled ? bg : primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  final List<_BottomNavItem> items;

  const _BottomNavBar({required this.items});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(color: primary.withOpacity01(0.10)),
          ),
        ),
        child: Row(
          children: [
            for (final item in items)
              Expanded(
                child: InkWell(
                  onTap: item.onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.icon,
                        color: item.active
                            ? primary
                            : (isDark ? AppColors.slate500 : AppColors.slate600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                          color: item.active
                              ? primary
                              : (isDark
                                    ? AppColors.slate500
                                    : AppColors.slate600),
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

class _BottomNavItem {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback? onTap;

  const _BottomNavItem({
    required this.label,
    required this.icon,
    required this.active,
    this.onTap,
  });
}
