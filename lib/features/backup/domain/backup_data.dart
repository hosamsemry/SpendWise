import 'dart:convert';

class BackupException implements Exception {
  final String message;
  const BackupException(this.message);

  @override
  String toString() => message;
}

class InvalidBackupFormatException extends BackupException {
  const InvalidBackupFormatException([super.message = 'Invalid or corrupt backup file format.']);
}

class IncompatibleBackupException extends BackupException {
  const IncompatibleBackupException([super.message = 'Incompatible backup file version or application.']);
}

/// Metadata header describing the backup archive.
class BackupMetadata {
  final int version;
  final int schemaVersion;
  final String appName;
  final DateTime createdAt;
  final String? deviceInfo;

  const BackupMetadata({
    required this.version,
    required this.schemaVersion,
    required this.appName,
    required this.createdAt,
    this.deviceInfo,
  });

  Map<String, dynamic> toJson() => {
    'version': version,
    'schemaVersion': schemaVersion,
    'appName': appName,
    'createdAt': createdAt.toIso8601String(),
    if (deviceInfo != null) 'deviceInfo': deviceInfo,
  };

  factory BackupMetadata.fromJson(Map<String, dynamic> json) {
    final version = json['version'] as int?;
    final schemaVersion = json['schemaVersion'] as int?;
    final appName = json['appName'] as String?;
    final createdAtStr = json['createdAt'] as String?;

    if (version == null || schemaVersion == null || appName == null || createdAtStr == null) {
      throw const InvalidBackupFormatException('Backup metadata missing required fields.');
    }

    if (appName != 'SpendWise' && appName != 'money_tracker') {
      throw IncompatibleBackupException('Backup is for app "$appName", expected SpendWise.');
    }

    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(createdAtStr);
    } catch (_) {
      throw const InvalidBackupFormatException('Invalid timestamp in backup metadata.');
    }

    return BackupMetadata(
      version: version,
      schemaVersion: schemaVersion,
      appName: appName,
      createdAt: parsedDate,
      deviceInfo: json['deviceInfo'] as String?,
    );
  }
}

/// Complete backup container payload holding all serialized tables.
class BackupData {
  final BackupMetadata metadata;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> budgetCycles;
  final List<Map<String, dynamic>> categoryBudgets;
  final List<Map<String, dynamic>> transactions;
  final List<Map<String, dynamic>> transactionPresets;
  final List<Map<String, dynamic>> appSettings;
  final List<Map<String, dynamic>> notificationEvents;

  const BackupData({
    required this.metadata,
    required this.categories,
    required this.budgetCycles,
    required this.categoryBudgets,
    required this.transactions,
    required this.transactionPresets,
    required this.appSettings,
    this.notificationEvents = const [],
  });

  int get transactionCount => transactions.length;
  int get categoryCount => categories.length;
  int get budgetCycleCount => budgetCycles.length;
  int get presetCount => transactionPresets.length;

  Map<String, dynamic> toJson() => {
    'metadata': metadata.toJson(),
    'data': {
      'categories': categories,
      'budgetCycles': budgetCycles,
      'categoryBudgets': categoryBudgets,
      'transactions': transactions,
      'transactionPresets': transactionPresets,
      'appSettings': appSettings,
      'notificationEvents': notificationEvents,
    },
  };

  factory BackupData.fromJson(Map<String, dynamic> json) {
    final metaJson = json['metadata'];
    if (metaJson == null || metaJson is! Map<String, dynamic>) {
      throw const InvalidBackupFormatException('Missing backup metadata.');
    }
    final metadata = BackupMetadata.fromJson(metaJson);

    final dataJson = json['data'];
    if (dataJson == null || dataJson is! Map<String, dynamic>) {
      throw const InvalidBackupFormatException('Missing backup data payload.');
    }

    List<Map<String, dynamic>> parseList(String key) {
      final list = dataJson[key];
      if (list == null) return [];
      if (list is! List) {
        throw InvalidBackupFormatException('Invalid data type for key: $key');
      }
      return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    }

    return BackupData(
      metadata: metadata,
      categories: parseList('categories'),
      budgetCycles: parseList('budgetCycles'),
      categoryBudgets: parseList('categoryBudgets'),
      transactions: parseList('transactions'),
      transactionPresets: parseList('transactionPresets'),
      appSettings: parseList('appSettings'),
      notificationEvents: parseList('notificationEvents'),
    );
  }

  factory BackupData.fromJsonString(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map<String, dynamic>) {
        throw const InvalidBackupFormatException('Backup root must be a JSON object.');
      }
      return BackupData.fromJson(decoded);
    } on FormatException catch (e) {
      throw InvalidBackupFormatException('Corrupt JSON string: ${e.message}');
    }
  }

  String toFormattedJsonString() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }
}
