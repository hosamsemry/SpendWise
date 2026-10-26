import 'dart:io';
import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/features/backup/domain/backup_data.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

class BackupService {
  final AppDatabase db;
  static const Uuid _uuid = Uuid();

  BackupService(this.db);

  /// Queries all tables from the database and packages them into a [BackupData] snapshot.
  Future<BackupData> createBackupData() async {
    final categories = await db.select(db.categoriesTable).get();
    final budgetCycles = await db.select(db.budgetCyclesTable).get();
    final categoryBudgets = await db.select(db.categoryBudgetsTable).get();
    final transactions = await db.select(db.transactionsTable).get();
    final presets = await db.select(db.transactionPresetsTable).get();
    final appSettings = await db.select(db.appSettingsTable).get();
    final notifications = await db.select(db.notificationEventsTable).get();

    final metadata = BackupMetadata(
      version: 1,
      schemaVersion: db.schemaVersion,
      appName: 'SpendWise',
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
    );
  }

  /// Writes [BackupData] to disk and invokes the native share sheet.
  Future<File> exportBackupFile({BackupData? data}) async {
    final backup = data ?? await createBackupData();
    final jsonContent = backup.toFormattedJsonString();

    final dir = await getApplicationDocumentsDirectory();
    final dateStr = DateFormat('yyyyMMdd_HHmmss', 'en_US').format(backup.metadata.createdAt);
    final fileName = 'SpendWise_Backup_$dateStr.json';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(jsonContent);

    final isArabic = Intl.defaultLocale?.startsWith('ar') == true;
    final formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(backup.metadata.createdAt);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: isArabic ? 'نسخة احتياطية لـ SpendWise $dateStr' : 'SpendWise Backup $dateStr',
        text: isArabic
            ? 'نسخة احتياطية محلية لـ SpendWise أنشئت في $formattedDate'
            : 'SpendWise local backup created on $formattedDate',
      ),
    );

    return file;
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
  Future<void> restoreFromBackup(BackupData backup, {bool keepCurrentPin = true}) async {
    await db.transaction(() async {
      // 1. Capture current PIN settings if preservation is requested, plus onboarding fallback settings
      List<AppSettingEntry> currentPinSettings = [];
      if (keepCurrentPin) {
        final pinSettings = await (db.select(db.appSettingsTable)
              ..where((tbl) => tbl.key.isIn(['pin_enabled', 'pin_hash'])))
            .get();
        currentPinSettings = pinSettings;
      }
      final fallbackOnboardingSettings = await (db.select(db.appSettingsTable)
            ..where((tbl) => tbl.key.isIn(['app_language', 'budget_cycle_start_day'])))
          .get();

      // 2. Clear all tables in reverse foreign key dependency order
      await db.delete(db.notificationEventsTable).go();
      await db.delete(db.transactionsTable).go();
      await db.delete(db.categoryBudgetsTable).go();
      await db.delete(db.transactionPresetsTable).go();
      await db.delete(db.budgetCyclesTable).go();
      await db.delete(db.categoriesTable).go();
      await db.delete(db.appSettingsTable).go();

      final restoredCategoryIds = <String>{};
      final restoredCycleIds = <String>{};
      final categoryDefaultBudgets = <String, int>{};
      final activeExpenseCategoryIds = <String>{};
      final savingsCategoryIds = <String>{};

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
        categoryDefaultBudgets[id] = defaultBudgetMinor;
        if (type == 'expense' && isActive) {
          activeExpenseCategoryIds.add(id);
        }
        final lowerName = name.trim().toLowerCase();
        if (lowerName == 'savings' || lowerName == 'مدخرات') {
          savingsCategoryIds.add(id);
        }
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
      final insertedBudgetKeys = <String>{};
      for (final row in backup.categoryBudgets) {
        final cycleId = row['cycleId'] as String;
        final categoryId = row['categoryId'] as String;
        if (!restoredCycleIds.contains(cycleId) ||
            !restoredCategoryIds.contains(categoryId)) {
          continue;
        }
        final nowIso = DateTime.now().toIso8601String();
        var budgetMinor = row['budgetAmountMinor'] as int? ?? 0;
        if (budgetMinor == 0 &&
            !savingsCategoryIds.contains(categoryId) &&
            (categoryDefaultBudgets[categoryId] ?? 0) > 0) {
          budgetMinor = categoryDefaultBudgets[categoryId]!;
        }
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
        insertedBudgetKeys.add('${cycleId}_$categoryId');
      }

      // Ensure active expense categories with default allocations have a budget row in restored cycles
      for (final cycleId in restoredCycleIds) {
        final nowIso = DateTime.now().toIso8601String();
        for (final catId in activeExpenseCategoryIds) {
          if (!insertedBudgetKeys.contains('${cycleId}_$catId') &&
              (categoryDefaultBudgets[catId] ?? 0) > 0) {
            await db.into(db.categoryBudgetsTable).insert(
              CategoryBudgetsTableCompanion.insert(
                id: _uuid.v4(),
                cycleId: cycleId,
                categoryId: catId,
                budgetAmountMinor: categoryDefaultBudgets[catId]!,
                createdAt: nowIso,
                updatedAt: nowIso,
              ),
            );
          }
        }
      }

      // 6. Insert transactions
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

      // 9. Insert app settings
      final restoredSettingKeys = <String>{};
      for (final row in backup.appSettings) {
        final key = row['key'] as String;
        final value = row['value'] as String;

        // Skip PIN settings if preservation was requested
        if (keepCurrentPin && (key == 'pin_enabled' || key == 'pin_hash')) {
          continue;
        }

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
