class HistoryEntry {
  final int timestampMs;
  final String title;
  final String detail;
  final String? path;

  const HistoryEntry({
    required this.timestampMs,
    required this.title,
    required this.detail,
    this.path,
  });

  DateTime get timestamp => DateTime.fromMillisecondsSinceEpoch(timestampMs);

  Map<String, dynamic> toJson() => {
        'timestampMs': timestampMs,
        'title': title,
        'detail': detail,
        'path': path,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      timestampMs: (json['timestampMs'] as num?)?.toInt() ?? 0,
      title: (json['title'] as String?) ?? 'Event',
      detail: (json['detail'] as String?) ?? '',
      path: json['path'] as String?,
    );
  }
}
