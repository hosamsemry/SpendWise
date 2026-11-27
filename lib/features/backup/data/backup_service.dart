import 'dart:io';
import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/security/security_service.dart';
import 'package:money_tracker/features/backup/data/backup_crypto.dart';
import 'package:money_tracker/features/backup/data/safety_snapshot_store.dart';
import 'package:money_tracker/features/backup/domain/backup_data.dart';
import 'package:money_tracker/core/files/export_file_store.dart';
import 'package:share_plus/share_plus.dart';

/// When this device last exported a backup (ISO-8601). Device-local: kept as
/// is when restoring, since an old file's value would be misleading.
const String lastBackupAtKey = 'last_backup_at';

/// Thrown when an encrypted backup is parsed without a password.
class BackupPasswordRequiredException extends BackupException {
  const BackupPasswordRequiredException([
    super.message = 'This backup is password protected.',
  ]);
}

class BackupService {
  final AppDatabase db;
  final BackupCrypto crypto;
  final ExportFileStore exportFiles;
  final SafetySnapshotStore safetySnapshots;

  BackupService(
    this.db, {
    this.crypto = const BackupCrypto(),
    ExportFileStore? exportFiles,
    SafetySnapshotStore? safetySnapshots,
  }) : exportFiles = exportFiles ?? ExportFileStore(),
       safetySnapshots = safetySnapshots ?? SafetySnapshotStore();

  /// Queries all tables from the database and packages them into a [BackupData] snapshot.
  Future<BackupData> createBackupData() async {
    final categories = await db.select(db.categoriesTable).get();
    final budgetCycles = await db.select(db.budgetCyclesTable).get();
    final categoryBudgets = await db.select(db.categoryBudgetsTable).get();
    final transactions = await db.select(db.transactionsTable).get();
    final presets = await db.select(db.transactionPresetsTable).get();
    final appSettings = await db.select(db.appSettingsTable).get();
    final notifications = await db.select(db.notificationEventsTable).get();
    final bills = await db.select(db.recurringBillsTable).get();
    final billOccurrences = await db.select(db.billOccurrencesTable).get();
    final savingsGoals = await db.select(db.savingsGoalsTable).get();
    final savingsMovements = await db.select(db.savingsMovementsTable).get();

    final metadata = BackupMetadata(
      version: 1,
      schemaVersion: db.schemaVersion,
      appName: 'Paydial',
      createdAt: DateTime.now(),
      deviceInfo: Platform.operatingSystem,
    );

    return BackupData(
      metadata: metadata,
      categories: categories.map((c) => {
        'id': c.id,
        'name': c.name,
        'type': c.type,
        'icon': c.icon,
        'color': c.color,
        'defaultBudgetMinor': c.defaultBudgetMinor,
        'isActive': c.isActive,
        'createdAt': c.createdAt,
        'updatedAt': c.updatedAt,
      }).toList(),
      budgetCycles: budgetCycles.map((bc) => {
        'id': bc.id,
        'startDate': bc.startDate,
        'endDate': bc.endDate,
        'createdAt': bc.createdAt,
      }).toList(),
      categoryBudgets: categoryBudgets.map((cb) => {
        'id': cb.id,
        'cycleId': cb.cycleId,
        'categoryId': cb.categoryId,
        'budgetAmountMinor': cb.budgetAmountMinor,
        'createdAt': cb.createdAt,
        'updatedAt': cb.updatedAt,
      }).toList(),
      transactions: transactions.map((t) => {
        'id': t.id,
        'categoryId': t.categoryId,
        'categoryName': t.categoryName,
        'amountMinor': t.amountMinor,
        'transactionDate': t.transactionDate,
        'note': t.note,
        'type': t.type,
        'createdAt': t.createdAt,
        'updatedAt': t.updatedAt,
      }).toList(),
      transactionPresets: presets.map((p) => {
        'id': p.id,
        'title': p.title,
        'type': p.type,
        'categoryId': p.categoryId,
        'categoryName': p.categoryName,
        'amountMinor': p.amountMinor,
        'note': p.note,
        'displayOrder': p.displayOrder,
        'createdAt': p.createdAt,
      }).toList(),
      appSettings: appSettings.map((s) => {
        'key': s.key,
        'value': s.value,
      }).toList(),
      notificationEvents: notifications.map((n) => {
        'id': n.id,
        'cycleId': n.cycleId,
        'categoryId': n.categoryId,
        'eventType': n.eventType,
        'createdAt': n.createdAt,
      }).toList(),
      recurringBills: bills.map((b) => {
        'id': b.id,
        'title': b.title,
        'type': b.type,
        'categoryId': b.categoryId,
        'categoryName': b.categoryName,
        'amountMinor': b.amountMinor,
        'isVariable': b.isVariable,
        'frequency': b.frequency,
        'anchorDate': b.anchorDate,
        'remindDaysBefore': b.remindDaysBefore,
        'isActive': b.isActive,
        'note': b.note,
        'createdAt': b.createdAt,
        'updatedAt': b.updatedAt,
      }).toList(),
      billOccurrences: billOccurrences.map((o) => {
        'id': o.id,
        'billId': o.billId,
        'dueDate': o.dueDate,
        'status': o.status,
        'transactionId': o.transactionId,
        'createdAt': o.createdAt,
      }).toList(),
      savingsGoals: savingsGoals.map((g) => {
        'id': g.id,
        'name': g.name,
        'icon': g.icon,
        'targetMinor': g.targetMinor,
        'targetDate': g.targetDate,
        'monthlyPlanMinor': g.monthlyPlanMinor,
        'priority': g.priority,
        'achievedAt': g.achievedAt,
        'createdAt': g.createdAt,
        'updatedAt': g.updatedAt,
      }).toList(),
      savingsMovements: savingsMovements.map((m) => {
        'id': m.id,
        'goalId': m.goalId,
        'amountMinor': m.amountMinor,
        'kind': m.kind,
        'groupId': m.groupId,
        'cycleId': m.cycleId,
        'createdAt': m.createdAt,
      }).toList(),
    );
  }

  /// Serialized file content for [backup]: encrypted with [password] when
  /// given, otherwise plain (readable) JSON.
  Future<String> encodeBackup(BackupData backup, {String? password}) async {
    final json = backup.toFormattedJsonString();
    if (password == null) return json;
    return crypto.encrypt(json, password);
  }

  /// Whether a file's [content] needs a password to open.
  bool isEncryptedBackup(String content) => BackupCrypto.isEncrypted(content);

  /// Parses plain or encrypted backup file [content].
  /// Throws [BackupPasswordRequiredException] if it is encrypted and no
  /// [password] is given, and [WrongBackupPasswordException] if it is wrong.
  Future<BackupData> parseBackupContent(String content, {String? password}) async {
    if (!BackupCrypto.isEncrypted(content)) return parseBackupString(content);
    if (password == null) throw const BackupPasswordRequiredException();
    return parseBackupString(await crypto.decrypt(content, password));
  }

  /// Writes [BackupData] to disk and invokes the native share sheet.
  /// With a [password] the file is AES-256-GCM encrypted.
  Future<File> exportBackupFile({BackupData? data, String? password}) async {
    final backup = data ?? await createBackupData();
    final jsonContent = await encodeBackup(backup, password: password);

    final dateStr = DateFormat('yyyyMMdd_HHmmss', 'en_US').format(backup.metadata.createdAt);
    final file = await exportFiles.fileFor('Paydial_Backup_$dateStr.json');
    await file.writeAsString(jsonContent);

    final isArabic = Intl.defaultLocale?.startsWith('ar') == true;
    final formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(backup.metadata.createdAt);
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: isArabic ? 'نسخة احتياطية لـ Paydial $dateStr' : 'Paydial Backup $dateStr',
        text: isArabic
            ? 'نسخة احتياطية محلية لـ Paydial أنشئت في $formattedDate'
            : 'Paydial local backup created on $formattedDate',
      ),
    );

    // Only count it as a backup if the user actually sent the file somewhere.
    if (result.status != ShareResultStatus.dismissed) {
      await markBackedUp(at: backup.metadata.createdAt);
    }
    return file;
  }

  /// When this device last exported a backup, or `null` if never.
  /// The data from before the most recent restore, if it can still be put
  /// back with [undoLastRestore].
  Future<SafetySnapshot?> latestSafetySnapshot() => safetySnapshots.latest();

  /// Puts back the data from before the last restore exactly as it was
  /// (including the PIN), then discards that snapshot so a second undo goes
  /// one restore further back.
  Future<BackupData> undoLastRestore() async {
    final snapshot = await safetySnapshots.latest();
    if (snapshot == null) {
      throw const BackupException('There is no restore to undo.');
    }
    final data = parseBackupString(await snapshot.file.readAsString());
    await restoreFromBackup(
      data,
      keepCurrentPin: false,
      takeSafetySnapshot: false,
    );
    await safetySnapshots.delete(snapshot);
    return data;
  }

  Future<DateTime?> lastBackupAt() async {
    final entry = await (db.select(db.appSettingsTable)
          ..where((tbl) => tbl.key.equals(lastBackupAtKey)))
        .getSingleOrNull();
    return entry == null ? null : DateTime.tryParse(entry.value);
  }

  Future<void> markBackedUp({DateTime? at}) async {
    await db.into(db.appSettingsTable).insertOnConflictUpdate(
          AppSettingsTableCompanion.insert(
            key: lastBackupAtKey,
            value: (at ?? DateTime.now()).toIso8601String(),
          ),
        );
  }

  /// Parses and validates a backup JSON string.
  BackupData parseBackupString(String jsonContent) {
    return BackupData.fromJsonString(jsonContent);
  }

  /// Reads a file and parses it as a [BackupData] payload.
  Future<BackupData> parseBackupFile(File file) async {
    if (!await file.exists()) {
      throw const InvalidBackupFormatException('Backup file does not exist.');
    }
    final content = await file.readAsString();
    return parseBackupString(content);
  }

  /// Atomically restores all database tables from [backup].
  ///
  /// If [keepCurrentPin] is true, currently configured device PIN credentials
  /// will be preserved rather than overwritten by the backup file.
  ///
  /// Unless [takeSafetySnapshot] is false (the user can opt out in the
  /// restore dialog), the current data is first saved as a safety snapshot so
  /// the restore can be undone ([undoLastRestore]). If that snapshot cannot
  /// be written, nothing is restored.
  Future<void> restoreFromBackup(
    BackupData backup, {
    bool keepCurrentPin = true,
    bool takeSafetySnapshot = true,
  }) async {
    if (takeSafetySnapshot) {
      await safetySnapshots.save(await encodeBackup(await createBackupData()));
    }
    await db.transaction(() async {
      // 1. Capture current PIN settings if preservation is requested, plus onboarding fallback settings
      List<AppSettingEntry> currentPinSettings = [];
      if (keepCurrentPin) {
        final pinSettings = await (db.select(db.appSettingsTable)
              ..where((tbl) => tbl.key.isIn(pinCredentialSettingKeys)))
            .get();
        currentPinSettings = pinSettings;
      }
      final fallbackOnboardingSettings = await (db.select(db.appSettingsTable)
            ..where((tbl) => tbl.key.isIn(['app_language', 'budget_cycle_start_day'])))
          .get();
      final deviceLastBackup = await (db.select(db.appSettingsTable)
            ..where((tbl) => tbl.key.equals(lastBackupAtKey)))
          .getSingleOrNull();

      // 2. Clear all tables in reverse foreign key dependency order
      await db.delete(db.savingsMovementsTable).go();
      await db.delete(db.savingsGoalsTable).go();
      await db.delete(db.billOccurrencesTable).go();
      await db.delete(db.recurringBillsTable).go();
      await db.delete(db.notificationEventsTable).go();
      await db.delete(db.transactionsTable).go();
      await db.delete(db.categoryBudgetsTable).go();
      await db.delete(db.transactionPresetsTable).go();
      await db.delete(db.budgetCyclesTable).go();
      await db.delete(db.categoriesTable).go();
      await db.delete(db.appSettingsTable).go();

      final restoredCategoryIds = <String>{};
      final restoredCycleIds = <String>{};

      // 3. Insert categories
      for (final row in backup.categories) {
        final nowIso = DateTime.now().toIso8601String();
        final id = row['id'] as String;
        final name = row['name'] as String;
        final defaultBudgetMinor = row['defaultBudgetMinor'] as int? ?? 0;
        final isActive = row['isActive'] as bool? ?? true;
        final type = row['type'] as String? ?? 'expense';
        await db.into(db.categoriesTable).insert(
          CategoriesTableCompanion.insert(
            id: id,
            name: name,
            color: Value(row['color'] as String?),
            icon: Value(row['icon'] as String?),
            defaultBudgetMinor: Value(defaultBudgetMinor),
            isActive: Value(isActive),
            type: Value(type),
            createdAt: row['createdAt'] as String? ?? nowIso,
            updatedAt: row['updatedAt'] as String? ?? nowIso,
          ),
        );
        restoredCategoryIds.add(id);
      }

      // 4. Insert budget cycles
      for (final row in backup.budgetCycles) {
        final nowIso = DateTime.now().toIso8601String();
        final id = row['id'] as String;
        await db.into(db.budgetCyclesTable).insert(
          BudgetCyclesTableCompanion.insert(
            id: id,
            startDate: row['startDate'] as String,
            endDate: row['endDate'] as String,
            createdAt: row['createdAt'] as String? ?? nowIso,
          ),
        );
        restoredCycleIds.add(id);
      }

      // 5. Insert category budgets
      for (final row in backup.categoryBudgets) {
        final cycleId = row['cycleId'] as String;
        final categoryId = row['categoryId'] as String;
        if (!restoredCycleIds.contains(cycleId) ||
            !restoredCategoryIds.contains(categoryId)) {
          continue;
        }
        final nowIso = DateTime.now().toIso8601String();
        // Restore exactly what was saved: a 0 budget is a deliberate choice
        // and past cycles are frozen snapshots, so never substitute defaults.
        final budgetMinor = row['budgetAmountMinor'] as int? ?? 0;
        await db.into(db.categoryBudgetsTable).insert(
          CategoryBudgetsTableCompanion.insert(
            id: row['id'] as String,
            cycleId: cycleId,
            categoryId: categoryId,
            budgetAmountMinor: budgetMinor,
            createdAt: row['createdAt'] as String? ?? nowIso,
            updatedAt: row['updatedAt'] as String? ?? nowIso,
          ),
        );
      }

      // 6. Insert transactions
      final restoredTransactionIds = <String>{};
      for (final row in backup.transactions) {
        final nowIso = DateTime.now().toIso8601String();
        final rawCatId = row['categoryId'] as String?;
        final validCatId =
            (rawCatId != null && restoredCategoryIds.contains(rawCatId))
                ? rawCatId
                : null;
        await db.into(db.transactionsTable).insert(
          TransactionsTableCompanion.insert(
            id: row['id'] as String,
            type: row['type'] as String? ?? 'expense',
            amountMinor: row['amountMinor'] as int? ?? 0,
            categoryId: Value(validCatId),
            categoryName: Value(row['categoryName'] as String?),
            transactionDate: row['transactionDate'] as String,
            note: Value(row['note'] as String?),
            createdAt: row['createdAt'] as String? ?? nowIso,
            updatedAt: row['updatedAt'] as String? ?? nowIso,
          ),
        );
        restoredTransactionIds.add(row['id'] as String);
      }

      // 7. Insert presets
      for (final row in backup.transactionPresets) {
        final nowIso = DateTime.now().toIso8601String();
        final rawCatId = row['categoryId'] as String?;
        final validCatId =
            (rawCatId != null && restoredCategoryIds.contains(rawCatId))
                ? rawCatId
                : null;
        await db.into(db.transactionPresetsTable).insert(
          TransactionPresetsTableCompanion.insert(
            id: row['id'] as String,
            title: row['title'] as String,
            type: row['type'] as String? ?? 'expense',
            categoryId: Value(validCatId),
            categoryName: Value(row['categoryName'] as String?),
            amountMinor: row['amountMinor'] as int? ?? 0,
            note: Value(row['note'] as String?),
            displayOrder: Value(row['displayOrder'] as int? ?? 0),
            createdAt: row['createdAt'] as String? ?? nowIso,
          ),
        );
      }

      // 8. Insert notification events
      for (final row in backup.notificationEvents) {
        final cycleId = row['cycleId'] as String;
        final categoryId = row['categoryId'] as String;
        if (!restoredCycleIds.contains(cycleId) ||
            !restoredCategoryIds.contains(categoryId)) {
          continue;
        }
        final nowIso = DateTime.now().toIso8601String();
        await db.into(db.notificationEventsTable).insert(
          NotificationEventsTableCompanion.insert(
            id: row['id'] as String,
            cycleId: cycleId,
            categoryId: categoryId,
            eventType: row['eventType'] as String,
            createdAt: row['createdAt'] as String? ?? nowIso,
          ),
        );
      }

      // 9. Insert recurring bills and their paid / skipped due dates
      final restoredBillIds = <String>{};
      for (final row in backup.recurringBills) {
        final nowIso = DateTime.now().toIso8601String();
        final rawCatId = row['categoryId'] as String?;
        final validCatId =
            (rawCatId != null && restoredCategoryIds.contains(rawCatId))
                ? rawCatId
                : null;
        final id = row['id'] as String;
        await db.into(db.recurringBillsTable).insert(
          RecurringBillsTableCompanion.insert(
            id: id,
            title: row['title'] as String,
            type: row['type'] as String? ?? 'expense',
            categoryId: Value(validCatId),
            categoryName: Value(row['categoryName'] as String?),
            amountMinor: row['amountMinor'] as int,
            isVariable: Value(row['isVariable'] as bool? ?? false),
            frequency: row['frequency'] as String? ?? 'monthly',
            anchorDate: row['anchorDate'] as String,
            remindDaysBefore: Value(row['remindDaysBefore'] as int?),
            isActive: Value(row['isActive'] as bool? ?? true),
            note: Value(row['note'] as String?),
            createdAt: row['createdAt'] as String? ?? nowIso,
            updatedAt: row['updatedAt'] as String? ?? nowIso,
          ),
        );
        restoredBillIds.add(id);
      }
      for (final row in backup.billOccurrences) {
        final billId = row['billId'] as String;
        final txId = row['transactionId'] as String?;
        if (!restoredBillIds.contains(billId)) continue;
        // A payment whose transaction is gone is no longer paid.
        if (txId != null && !restoredTransactionIds.contains(txId)) continue;
        await db.into(db.billOccurrencesTable).insert(
          BillOccurrencesTableCompanion.insert(
            id: row['id'] as String,
            billId: billId,
            dueDate: row['dueDate'] as String,
            status: row['status'] as String? ?? 'paid',
            transactionId: Value(txId),
            createdAt: row['createdAt'] as String? ?? DateTime.now().toIso8601String(),
          ),
        );
      }

      // 10. Insert savings goals and the vault history. A movement whose goal
      // is missing counts as Unassigned, which keeps the vault total intact.
      final restoredGoalIds = <String>{};
      for (final row in backup.savingsGoals) {
        final nowIso = DateTime.now().toIso8601String();
        final id = row['id'] as String;
        await db.into(db.savingsGoalsTable).insert(
          SavingsGoalsTableCompanion.insert(
            id: id,
            name: row['name'] as String,
            icon: Value(row['icon'] as String?),
            targetMinor: row['targetMinor'] as int,
            targetDate: Value(row['targetDate'] as String?),
            monthlyPlanMinor: Value(row['monthlyPlanMinor'] as int?),
            priority: Value(row['priority'] as int? ?? 0),
            achievedAt: Value(row['achievedAt'] as String?),
            createdAt: row['createdAt'] as String? ?? nowIso,
            updatedAt: row['updatedAt'] as String? ?? nowIso,
          ),
        );
        restoredGoalIds.add(id);
      }
      for (final row in backup.savingsMovements) {
        final rawGoalId = row['goalId'] as String?;
        await db.into(db.savingsMovementsTable).insert(
          SavingsMovementsTableCompanion.insert(
            id: row['id'] as String,
            goalId: Value(rawGoalId != null && restoredGoalIds.contains(rawGoalId) ? rawGoalId : null),
            amountMinor: row['amountMinor'] as int,
            kind: row['kind'] as String? ?? 'deposit',
            groupId: row['groupId'] as String? ?? (row['id'] as String),
            cycleId: Value(row['cycleId'] as String?),
            createdAt: row['createdAt'] as String? ?? DateTime.now().toIso8601String(),
          ),
        );
      }

      // 11. Insert app settings
      final restoredSettingKeys = <String>{};
      for (final row in backup.appSettings) {
        final key = row['key'] as String;
        final value = row['value'] as String;

        // Skip PIN settings if preservation was requested
        if (keepCurrentPin && pinCredentialSettingKeys.contains(key)) {
          continue;
        }
        if (key == lastBackupAtKey) continue; // device-local, restored below

        await db.into(db.appSettingsTable).insert(
          AppSettingsTableCompanion.insert(
            key: key,
            value: value,
          ),
        );
        restoredSettingKeys.add(key);
      }

      // Restore preserved PIN settings if any
      if (keepCurrentPin && currentPinSettings.isNotEmpty) {
        for (final pinSetting in currentPinSettings) {
          await db.into(db.appSettingsTable).insertOnConflictUpdate(
            AppSettingsTableCompanion.insert(
              key: pinSetting.key,
              value: pinSetting.value,
            ),
          );
        }
      }

      if (deviceLastBackup != null) {
        await db.into(db.appSettingsTable).insertOnConflictUpdate(
          AppSettingsTableCompanion.insert(
            key: lastBackupAtKey,
            value: deviceLastBackup.value,
          ),
        );
      }

      // Backups from before schema 6 keep the vault as one number in settings.
      await migrateLegacyVaultBalance(db);

      // Restore onboarding fallback settings only if missing from backup
      for (final fallback in fallbackOnboardingSettings) {
        if (!restoredSettingKeys.contains(fallback.key)) {
          await db.into(db.appSettingsTable).insertOnConflictUpdate(
            AppSettingsTableCompanion.insert(
              key: fallback.key,
              value: fallback.value,
            ),
          );
        }
      }
    });
  }
}
