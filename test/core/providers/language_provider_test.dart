import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/core/providers/language_provider.dart';
import '../../test_helper.dart';

void main() {
  setUpAll(() {
    setupTestSqlite();
  });

  group('AppLanguageNotifier Tests', () {
    test('returns null on fresh database install', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );

      final initialLocale = await container.read(appLanguageProvider.future);
      expect(initialLocale, isNull);

      container.dispose();
      await db.close();
    });

    test('sets and persists Arabic language', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );

      // Verify null initially
      expect(await container.read(appLanguageProvider.future), isNull);

      // Set to Arabic
      await container.read(appLanguageProvider.notifier).setLanguage('ar');

      // Verify updated state
      final currentLocale = container.read(appLanguageProvider).asData?.value;
      expect(currentLocale, const Locale('ar'));

      // Verify persisted in database
      final row = await (db.select(db.appSettingsTable)
            ..where((tbl) => tbl.key.equals(appLanguageKey)))
          .getSingleOrNull();
      expect(row, isNotNull);
      expect(row!.value, 'ar');

      container.dispose();
      await db.close();
    });

    test('updates to English and throws on unsupported language', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );

      await container.read(appLanguageProvider.notifier).setLanguage('ar');
      expect(container.read(appLanguageProvider).asData?.value, const Locale('ar'));

      // Switch to English
      await container.read(appLanguageProvider.notifier).setLanguage('en');
      expect(container.read(appLanguageProvider).asData?.value, const Locale('en'));

      // Unsupported code throws
      expect(
        () => container.read(appLanguageProvider.notifier).setLanguage('es'),
        throwsArgumentError,
      );

      container.dispose();
      await db.close();
    });
  });
}
