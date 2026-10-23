import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'database_providers.dart';

const String _themeSettingKey = 'theme_mode';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _loadTheme();
    return ThemeMode.system;
  }

  Future<void> _loadTheme() async {
    final db = ref.read(appDatabaseProvider);
    final setting = await (db.select(
      db.appSettingsTable,
    )..where((tbl) => tbl.key.equals(_themeSettingKey))).getSingleOrNull();

    if (setting != null) {
      switch (setting.value) {
        case 'light':
          state = ThemeMode.light;
          break;
        case 'dark':
          state = ThemeMode.dark;
          break;
        default:
          state = ThemeMode.system;
          break;
      }
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final db = ref.read(appDatabaseProvider);
    final val = mode == ThemeMode.light
        ? 'light'
        : mode == ThemeMode.dark
        ? 'dark'
        : 'system';

    await db
        .into(db.appSettingsTable)
        .insertOnConflictUpdate(
          AppSettingsTableCompanion.insert(key: _themeSettingKey, value: val),
        );
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
