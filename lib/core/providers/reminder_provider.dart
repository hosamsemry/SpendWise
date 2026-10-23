import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/providers/database_providers.dart';

const String _reminderEnabledKey = 'daily_reminder_enabled';
const String _reminderTimeKey = 'daily_reminder_time';

class DailyReminderSettings {
  final bool isEnabled;
  final int hour;
  final int minute;

  const DailyReminderSettings({
    this.isEnabled = false,
    this.hour = 21,
    this.minute = 0,
  });

  String get formattedTime {
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m $period';
  }

  DailyReminderSettings copyWith({
    bool? isEnabled,
    int? hour,
    int? minute,
  }) {
    return DailyReminderSettings(
      isEnabled: isEnabled ?? this.isEnabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
    );
  }
}

class DailyReminderNotifier extends Notifier<DailyReminderSettings> {
  @override
  DailyReminderSettings build() {
    _loadSettings();
    return const DailyReminderSettings();
  }

  Future<void> _loadSettings() async {
    final db = ref.read(appDatabaseProvider);

    final enabledEntry = await (db.select(
      db.appSettingsTable,
    )..where((tbl) => tbl.key.equals(_reminderEnabledKey))).getSingleOrNull();

    final timeEntry = await (db.select(
      db.appSettingsTable,
    )..where((tbl) => tbl.key.equals(_reminderTimeKey))).getSingleOrNull();

    bool isEnabled = enabledEntry?.value == 'true';
    int hour = 21;
    int minute = 0;

    if (timeEntry != null && timeEntry.value.contains(':')) {
      final parts = timeEntry.value.split(':');
      if (parts.length == 2) {
        hour = int.tryParse(parts[0]) ?? 21;
        minute = int.tryParse(parts[1]) ?? 0;
      }
    }

    state = DailyReminderSettings(
      isEnabled: isEnabled,
      hour: hour,
      minute: minute,
    );
  }

  Future<bool> setEnabled(bool enabled) async {
    final notificationService = ref.read(notificationServiceProvider);
    final db = ref.read(appDatabaseProvider);

    if (enabled) {
      final granted = await notificationService.requestPermission();
      if (!granted) {
        return false;
      }

      await notificationService.scheduleDailyEveningReminder(
        hour: state.hour,
        minute: state.minute,
      );
    } else {
      await notificationService.cancelDailyEveningReminder();
    }

    state = state.copyWith(isEnabled: enabled);

    await db
        .into(db.appSettingsTable)
        .insertOnConflictUpdate(
          AppSettingsTableCompanion.insert(
            key: _reminderEnabledKey,
            value: enabled ? 'true' : 'false',
          ),
        );

    return true;
  }

  Future<void> setTime(int hour, int minute) async {
    final notificationService = ref.read(notificationServiceProvider);
    final db = ref.read(appDatabaseProvider);

    state = state.copyWith(hour: hour, minute: minute);

    final timeStr =
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

    await db
        .into(db.appSettingsTable)
        .insertOnConflictUpdate(
          AppSettingsTableCompanion.insert(
            key: _reminderTimeKey,
            value: timeStr,
          ),
        );

    if (state.isEnabled) {
      await notificationService.scheduleDailyEveningReminder(
        hour: hour,
        minute: minute,
      );
    }
  }
}

final dailyReminderProvider =
    NotifierProvider<DailyReminderNotifier, DailyReminderSettings>(
      DailyReminderNotifier.new,
    );
