import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

abstract class INotificationService {
  Future<bool> initialize();
  Future<bool> requestPermission();
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  });
  Future<void> scheduleNext25thReminder(DateTime fromDate);
  Future<void> scheduleDailyEveningReminder({
    required int hour,
    required int minute,
  });
  Future<void> cancelDailyEveningReminder();
  Future<void> sendTestReminder();
  Future<void> cancel(int id);
}

class NotificationService implements INotificationService {
  final FlutterLocalNotificationsPlugin _plugin;
  bool _isInitialized = false;

  static const String channelId = 'budget_alerts';
  static const String channelName = 'Budget & Cycle Alerts';
  static const String channelDescription =
      'Notifications for monthly cycle reviews and category budget thresholds';
  static const int cycleReminderNotificationId = 25000;

  static const String reminderChannelId = 'daily_reminders';
  static const String reminderChannelName = 'Daily Evening Reminders';
  static const String reminderChannelDescription =
      'Daily evening notifications prompting you to log daily spending';
  static const int dailyReminderNotificationId = 26000;

  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  Future<void> _configureLocalTimeZone() async {
    try {
      tz.initializeTimeZones();
      try {
        final tzInfo = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
        return;
      } catch (_) {
        // Fallback: match by current device offset Duration
        final targetOffset = DateTime.now().timeZoneOffset;
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        final matches = tz.timeZoneDatabase.locations.values.where((loc) {
          return loc.timeZone(nowMs).offset == targetOffset;
        });
        if (matches.isNotEmpty) {
          tz.setLocalLocation(matches.first);
          return;
        }
      }
    } catch (_) {
      // Keep tz.local fallback
    }
  }

  @override
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      await _configureLocalTimeZone();

      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const linuxSettings = LinuxInitializationSettings(
        defaultActionName: 'Open notification',
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        linux: linuxSettings,
      );

      final initialized = await _plugin.initialize(settings: initSettings);
      _isInitialized = initialized ?? false;

      // Ensure notification channels are registered on Android with appropriate importance
      if (Platform.isAndroid && _isInitialized) {
        final androidImpl = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

        await androidImpl?.createNotificationChannel(
          const AndroidNotificationChannel(
            channelId,
            channelName,
            description: channelDescription,
            importance: Importance.high,
          ),
        );

        await androidImpl?.createNotificationChannel(
          const AndroidNotificationChannel(
            reminderChannelId,
            reminderChannelName,
            description: reminderChannelDescription,
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );
      }

      return _isInitialized;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      if (Platform.isAndroid) {
        final androidImpl = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        final granted =
            await androidImpl?.requestNotificationsPermission() ?? false;

        // Request exact alarm permission if on Android 12+ (API 31+)
        try {
          await androidImpl?.requestExactAlarmsPermission();
        } catch (_) {}

        return granted;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      );

      const notificationDetails = NotificationDetails(android: androidDetails);

      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
      );
    } catch (_) {
      // Suppress notification errors so financial actions are never blocked
    }
  }

  AppLocalizations get _l10n {
    final code = Intl.defaultLocale ?? 'en';
    return AppLocalizations(Locale(code.startsWith('ar') ? 'ar' : 'en'));
  }

  @override
  Future<void> scheduleNext25thReminder(DateTime fromDate) async {
    try {
      await cancel(cycleReminderNotificationId);

      // Determine the next 25th calendar date
      final int targetYear;
      final int targetMonth;
      if (fromDate.day < 25) {
        targetYear = fromDate.year;
        targetMonth = fromDate.month;
      } else {
        if (fromDate.month == 12) {
          targetYear = fromDate.year + 1;
          targetMonth = 1;
        } else {
          targetYear = fromDate.year;
          targetMonth = fromDate.month + 1;
        }
      }

      final targetDate = DateTime(targetYear, targetMonth, 25, 9, 0); // 9:00 AM
      final scheduledDate = tz.TZDateTime.from(targetDate, tz.local);

      const androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      );

      await _plugin.zonedSchedule(
        id: cycleReminderNotificationId,
        title: _l10n.newBudgetCycleNotificationTitle,
        body: _l10n.newBudgetCycleNotificationBody(25),
        scheduledDate: scheduledDate,
        notificationDetails: const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {
      // Non-blocking
    }
  }

  @override
  Future<void> scheduleDailyEveningReminder({
    required int hour,
    required int minute,
  }) async {
    try {
      await cancelDailyEveningReminder();
      await _configureLocalTimeZone();

      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      // If scheduled time has already passed today, start from tomorrow
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      const androidDetails = AndroidNotificationDetails(
        reminderChannelId,
        reminderChannelName,
        channelDescription: reminderChannelDescription,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );

      // Attempt exact alarm scheduling first, fallback to inexact if not allowed
      try {
        await _plugin.zonedSchedule(
          id: dailyReminderNotificationId,
          title: _l10n.eveningCheckinNotificationTitle,
          body: _l10n.eveningCheckinNotificationBody,
          scheduledDate: scheduledDate,
          notificationDetails: const NotificationDetails(
            android: androidDetails,
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } catch (_) {
        await _plugin.zonedSchedule(
          id: dailyReminderNotificationId,
          title: _l10n.eveningCheckinNotificationTitle,
          body: _l10n.eveningCheckinNotificationBody,
          scheduledDate: scheduledDate,
          notificationDetails: const NotificationDetails(
            android: androidDetails,
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
    } catch (_) {
      // Non-blocking
    }
  }

  @override
  Future<void> cancelDailyEveningReminder() async {
    await cancel(dailyReminderNotificationId);
  }

  @override
  Future<void> sendTestReminder() async {
    try {
      await initialize();
      const androidDetails = AndroidNotificationDetails(
        reminderChannelId,
        reminderChannelName,
        channelDescription: reminderChannelDescription,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );

      await _plugin.show(
        id: 99999,
        title: _l10n.eveningCheckinNotificationTitle,
        body: _l10n.isArabic
            ? 'الإشعارات تعمل بنجاح! هل أنفقت أي شيء اليوم؟'
            : 'Notifications are working! Did you spend anything today?',
        notificationDetails: const NotificationDetails(android: androidDetails),
      );
    } catch (_) {}
  }

  @override
  Future<void> cancel(int id) async {
    try {
      await _plugin.cancel(id: id);
    } catch (_) {
      // Non-blocking
    }
  }
}
