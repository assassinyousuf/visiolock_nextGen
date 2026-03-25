import 'dart:io';

import 'package:flutter/material.dart';

import '../models/history_entry.dart';
import '../services/history_service.dart';
import '../utils/app_colors.dart';
import '../utils/color_extensions.dart';

class HistoryScreen extends StatefulWidget {
  static const String routeName = '/history';

  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final HistoryService _history = HistoryService();

  bool _busy = true;
  List<HistoryEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    final entries = await _history.loadEntries();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _busy = false;
    });
  }

  String _formatTimestamp(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  String _fileName(String? path) {
    if (path == null || path.isEmpty) return '-';
    final parts = path.split(Platform.pathSeparator);
    return parts.isNotEmpty ? parts.last : path;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.slate400 : AppColors.slate600;

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
                      'History'.toUpperCase(),
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
              child: _busy
                  ? const Center(child: CircularProgressIndicator())
                  : (_entries.isEmpty
                      ? Center(
                          child: Text(
                            'No history yet.',
                            style: TextStyle(color: muted),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          itemCount: _entries.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final e = _entries[i];
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.slate900.withOpacity01(0.50),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: primary.withOpacity01(0.10),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.history, color: primary),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          e.title,
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : AppColors.slate900,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        _formatTimestamp(e.timestamp),
                                        style: TextStyle(
                                          color: muted,
                                          fontSize: 11,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    e.detail,
                                    style: TextStyle(color: muted, fontSize: 12),
                                  ),
                                  if (e.path != null && e.path!.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      _fileName(e.path),
                                      style: TextStyle(
                                        color: primary.withOpacity01(0.80),
                                        fontSize: 11,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        )),
            ),
          ],
        ),
      ),
    );
  }
}
