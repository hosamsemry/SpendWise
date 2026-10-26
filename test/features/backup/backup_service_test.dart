import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/features/backup/data/backup_service.dart';
import 'package:money_tracker/features/backup/domain/backup_data.dart';
import '../../test_helper.dart';

void main() {
  setUpAll(() {
    setupTestSqlite();
  });

  late AppDatabase db;
  late BackupService service;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    service = BackupService(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedTestData() async {
    final now = DateTime.now().toIso8601String();

    // 1. Categories
    await db.into(db.categoriesTable).insert(
      CategoriesTableCompanion.insert(
        id: 'cat-1',
        name: 'Groceries',
        type: const Value('expense'),
        color: const Value('0xFF22C55E'),
        defaultBudgetMinor: const Value(200000),
        isActive: const Value(true),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.into(db.categoriesTable).insert(
      CategoriesTableCompanion.insert(
        id: 'cat-2',
        name: 'Salary',
        type: const Value('income'),
        color: const Value('0xFF3B82F6'),
        defaultBudgetMinor: const Value(0),
        isActive: const Value(true),
        createdAt: now,
        updatedAt: now,
      ),
    );

    // 2. Cycle
    await db.into(db.budgetCyclesTable).insert(
      BudgetCyclesTableCompanion.insert(
        id: 'cycle-1',
        startDate: '2026-10-25',
        endDate: '2026-11-24',
        createdAt: now,
      ),
    );

    // 3. Category Budget
    await db.into(db.categoryBudgetsTable).insert(
      CategoryBudgetsTableCompanion.insert(
        id: 'cb-1',
        cycleId: 'cycle-1',
        categoryId: 'cat-1',
        budgetAmountMinor: 200000,
        createdAt: now,
        updatedAt: now,
      ),
    );

    // 4. Transactions
    await db.into(db.transactionsTable).insert(
      TransactionsTableCompanion.insert(
        id: 'tx-1',
        type: 'expense',
        amountMinor: 35000, // 350.00 EGP
        categoryId: const Value('cat-1'),
        categoryName: const Value('Groceries'),
        transactionDate: '2026-10-26',
        note: const Value('Supermarket run'),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.into(db.transactionsTable).insert(
      TransactionsTableCompanion.insert(
        id: 'tx-2',
        type: 'income',
        amountMinor: 1500000, // 15,000.00 EGP
        categoryId: const Value('cat-2'),
        categoryName: const Value('Salary'),
        transactionDate: '2026-10-25',
        note: const Value('Monthly paycheck'),
        createdAt: now,
        updatedAt: now,
      ),
    );

    // 5. Presets
    await db.into(db.transactionPresetsTable).insert(
      TransactionPresetsTableCompanion.insert(
        id: 'preset-1',
        title: 'Coffee',
        type: 'expense',
        amountMinor: 4500,
        categoryId: const Value('cat-1'),
        categoryName: const Value('Groceries'),
        createdAt: now,
      ),
    );

    // 6. Settings
    await db.into(db.appSettingsTable).insert(
      AppSettingsTableCompanion.insert(
        key: 'theme_mode',
        value: 'dark',
      ),
    );
    await db.into(db.appSettingsTable).insert(
      AppSettingsTableCompanion.insert(
        key: 'pin_enabled',
        value: 'true',
      ),
    );
    await db.into(db.appSettingsTable).insert(
      AppSettingsTableCompanion.insert(
        key: 'pin_hash',
        value: 'hash_1234',
      ),
    );
  }

  group('BackupService Tests', () {
    test('createBackupData extracts all tables correctly', () async {
      await seedTestData();

      final backup = await service.createBackupData();

      expect(backup.metadata.appName, equals('SpendWise'));
      expect(backup.metadata.version, equals(1));
      expect(backup.metadata.schemaVersion, equals(4));

      expect(backup.categoryCount, equals(2));
      expect(backup.budgetCycleCount, equals(1));
      expect(backup.categoryBudgets.length, equals(1));
      expect(backup.transactionCount, equals(2));
      expect(backup.presetCount, equals(1));
      expect(backup.appSettings.length, equals(3));
    });

    test('JSON serialization round-trip maintains full fidelity', () async {
      await seedTestData();

      final backup = await service.createBackupData();
      final jsonString = backup.toFormattedJsonString();
      final parsed = service.parseBackupString(jsonString);

      expect(parsed.metadata.appName, equals(backup.metadata.appName));
      expect(parsed.metadata.schemaVersion, equals(backup.metadata.schemaVersion));
      expect(parsed.categoryCount, equals(backup.categoryCount));
      expect(parsed.transactionCount, equals(backup.transactionCount));
      expect(parsed.transactions.first['id'], equals('tx-1'));
      expect(parsed.transactions.first['amountMinor'], equals(35000));
    });

    test('restoreFromBackup replaces database state (even with active notification_events) and respects keepCurrentPin', () async {
      await seedTestData();

      final backup = await service.createBackupData();

      // Modify the active database (including inserting a notification_event referencing cycle-1 and cat-1)
      await db.into(db.notificationEventsTable).insert(
        NotificationEventsTableCompanion.insert(
          id: 'notif-1',
          cycleId: 'cycle-1',
          categoryId: 'cat-1',
          eventType: 'reached_80_percent',
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
      await db.into(db.transactionsTable).insert(
        TransactionsTableCompanion.insert(
          id: 'tx-temporary',
          type: 'expense',
          amountMinor: 99900,
          categoryName: const Value('Temporary Snacks'),
          transactionDate: '2026-10-27',
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
        ),
      );
      // Update PIN
      await db.into(db.appSettingsTable).insertOnConflictUpdate(
        AppSettingsTableCompanion.insert(key: 'pin_hash', value: 'new_device_pin_hash'),
      );

      final txBeforeRestore = await db.select(db.transactionsTable).get();
      expect(txBeforeRestore.length, equals(3));

      // Restore backup preserving current device PIN
      await service.restoreFromBackup(backup, keepCurrentPin: true);

      // Verify transactions are restored to original 2
      final txAfterRestore = await db.select(db.transactionsTable).get();
      expect(txAfterRestore.length, equals(2));
      expect(txAfterRestore.any((t) => t.id == 'tx-temporary'), isFalse);

      // Verify categories
      final categories = await db.select(db.categoriesTable).get();
      expect(categories.length, equals(2));

      // Verify PIN hash was preserved
      final pinHashSetting = await (db.select(db.appSettingsTable)
            ..where((tbl) => tbl.key.equals('pin_hash')))
          .getSingle();
      expect(pinHashSetting.value, equals('new_device_pin_hash'));
    });

    test('restoreFromBackup overwrites PIN when keepCurrentPin is false', () async {
      await seedTestData();

      final backup = await service.createBackupData();

      // Change PIN
      await db.into(db.appSettingsTable).insertOnConflictUpdate(
        AppSettingsTableCompanion.insert(key: 'pin_hash', value: 'newer_pin'),
      );

      // Restore with keepCurrentPin: false
      await service.restoreFromBackup(backup, keepCurrentPin: false);

      final pinHashSetting = await (db.select(db.appSettingsTable)
            ..where((tbl) => tbl.key.equals('pin_hash')))
          .getSingle();
      expect(pinHashSetting.value, equals('hash_1234'));
    });

    test('parseBackupString rejects malformed JSON and incompatible apps', () {
      expect(
        () => service.parseBackupString('{"invalid": true}'),
        throwsA(isA<InvalidBackupFormatException>()),
      );

      expect(
        () => service.parseBackupString('not a json string'),
        throwsA(isA<InvalidBackupFormatException>()),
      );

      const foreignAppBackup = '''
      {
        "metadata": {
          "version": 1,
          "schemaVersion": 4,
          "appName": "OtherApp",
          "createdAt": "2026-10-17T12:00:00Z"
        },
        "data": {}
      }
      ''';
      expect(
        () => service.parseBackupString(foreignAppBackup),
        throwsA(isA<IncompatibleBackupException>()),
      );
    });
  });
}
