import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/providers/cycle_providers.dart';
import 'package:money_tracker/core/providers/database_providers.dart';

const String appLanguageKey = 'app_language';

class AppLanguageNotifier extends AsyncNotifier<Locale?> {
  @override
  Future<Locale?> build() async {
    final db = ref.watch(databaseProvider);
    final setting = await (db.select(db.appSettingsTable)
          ..where((tbl) => tbl.key.equals(appLanguageKey)))
        .getSingleOrNull();

    if (setting != null) {
      final code = setting.value.trim().toLowerCase();
      if (code == 'ar') {
        Intl.defaultLocale = 'ar';
        return const Locale('ar');
      }
      if (code == 'en') {
        Intl.defaultLocale = 'en';
        return const Locale('en');
      }
    }
    Intl.defaultLocale = 'en';
    return null; // Fresh install: user must choose language first
  }

  Future<void> setLanguage(String languageCode) async {
    final code = languageCode.trim().toLowerCase();
    if (code != 'en' && code != 'ar') {
      throw ArgumentError('Supported languages are "en" and "ar"');
    }

    final db = ref.read(databaseProvider);
    await db.into(db.appSettingsTable).insertOnConflictUpdate(
          AppSettingsTableCompanion.insert(
            key: appLanguageKey,
            value: code,
          ),
        );

    Intl.defaultLocale = code;
    state = AsyncData(Locale(code));
    ref.read(refreshTriggerProvider.notifier).trigger();
  }
}

final appLanguageProvider =
    AsyncNotifierProvider<AppLanguageNotifier, Locale?>(
  AppLanguageNotifier.new,
);
