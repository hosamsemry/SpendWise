import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/notifications/notification_service.dart';
import 'package:money_tracker/features/bills/domain/recurring_bill.dart';
import 'package:timezone/timezone.dart' as tz;

/// Schedules one local notification per bill: the next due-date reminder.
abstract class BillReminderScheduler {
  Future<void> schedule({
    required RecurringBill bill,
    required DateTime at,
    required DateTime dueDate,
  });
  Future<void> cancel(String billId);
}

/// Notification id for [billId] in the 30000–38999 range (stable across
/// launches, unlike `String.hashCode`).
int billReminderNotificationId(String billId) {
  var hash = 0x811c9dc5;
  for (final unit in billId.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return 30000 + hash % 9000;
}

class LocalBillReminderScheduler implements BillReminderScheduler {
  final INotificationService notifications;
  final FlutterLocalNotificationsPlugin _plugin;

  static const String channelId = 'bill_reminders';
  static const String channelName = 'Bill Reminders';
  static const String channelDescription =
      'Reminders before recurring bills and subscriptions are due';

  LocalBillReminderScheduler(
    this.notifications, {
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  AppLocalizations get _l10n {
    final code = Intl.defaultLocale ?? 'en';
    return AppLocalizations(Locale(code.startsWith('ar') ? 'ar' : 'en'));
  }

  @override
  Future<void> schedule({
    required RecurringBill bill,
    required DateTime at,
    required DateTime dueDate,
  }) async {
    try {
      // Sets up the local time zone the first time.
      await notifications.initialize();
      final id = billReminderNotificationId(bill.id);
      await _plugin.cancel(id: id);

      final l10n = _l10n;
      final days = DateTime.utc(dueDate.year, dueDate.month, dueDate.day)
          .difference(DateTime.utc(at.year, at.month, at.day))
          .inDays;
      const androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      );
      await _plugin.zonedSchedule(
        id: id,
        title: l10n.billReminderTitle(bill.title),
        body: l10n.billReminderBody(
          bill.amount.toFormattedString(),
          days,
          isIncome: bill.isIncome,
          isVariable: bill.isVariable,
        ),
        scheduledDate: tz.TZDateTime.from(at, tz.local),
        notificationDetails: const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {
      // Reminders are best effort; never block saving or paying a bill.
    }
  }

  @override
  Future<void> cancel(String billId) async {
    try {
      await _plugin.cancel(id: billReminderNotificationId(billId));
    } catch (_) {}
  }
}
