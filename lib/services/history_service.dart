import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/history_entry.dart';

class HistoryService {
  static const String _fileName = 'history.json';
  static const int _maxEntries = 200;

  Future<List<HistoryEntry>> loadEntries() async {
    final file = await _historyFile();
    if (!await file.exists()) {
      return <HistoryEntry>[];
    }

    try {
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return <HistoryEntry>[];
      }

      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <HistoryEntry>[];
      }

      return decoded
          .whereType<Map>()
          .map((m) => HistoryEntry.fromJson(m.cast<String, dynamic>()))
          .toList(growable: false);
    } catch (_) {
      return <HistoryEntry>[];
    }
  }

  Future<void> addEntry(HistoryEntry entry) async {
    final entries = await loadEntries();
    final updated = <HistoryEntry>[entry, ...entries];

    final trimmed = updated.length > _maxEntries
        ? updated.sublist(0, _maxEntries)
        : updated;

    await _writeEntries(trimmed);
  }

  Future<void> clear() async {
    final file = await _historyFile();
    if (await file.exists()) {
      await file.writeAsString('[]', flush: true);
    }
  }

  Future<File> _historyFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}${Platform.pathSeparator}$_fileName');
  }

  Future<void> _writeEntries(List<HistoryEntry> entries) async {
    final file = await _historyFile();
    final encoded = jsonEncode(entries.map((e) => e.toJson()).toList());
    await file.writeAsString(encoded, flush: true);
  }
}
