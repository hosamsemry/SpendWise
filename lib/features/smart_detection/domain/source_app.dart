/// An app the user approved as a source of bank/wallet notifications.
class WatchedSourceApp {
  final String packageName;
  final String label;

  const WatchedSourceApp({required this.packageName, required this.label});

  Map<String, dynamic> toJson() => {'packageName': packageName, 'label': label};

  factory WatchedSourceApp.fromJson(Map<String, dynamic> json) {
    final pkg = (json['packageName'] as String?) ?? '';
    final label = (json['label'] as String?) ?? '';
    return WatchedSourceApp(
      packageName: pkg,
      label: label.isEmpty ? pkg : label,
    );
  }
}

/// An unwatched app that posted financial-looking notifications, offered to
/// the user as a possible bank/wallet source. Reported by the native listener.
/// Deliberately carries no message text: content from apps the user has not
/// approved is never stored.
class SuggestedSourceApp {
  final String packageName;
  final String label;
  final int count;
  final DateTime lastSeen;

  const SuggestedSourceApp({
    required this.packageName,
    required this.label,
    required this.count,
    required this.lastSeen,
  });

  factory SuggestedSourceApp.fromMap(Map<dynamic, dynamic> map) {
    final pkg = (map['packageName'] as String?) ?? '';
    final label = (map['label'] as String?) ?? '';
    return SuggestedSourceApp(
      packageName: pkg,
      label: label.isEmpty ? pkg : label,
      count: (map['count'] as num?)?.toInt() ?? 1,
      lastSeen: DateTime.fromMillisecondsSinceEpoch(
        (map['lastSeenMs'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}
