import 'dart:ui';
import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/notifications/notification_service.dart';
import 'package:money_tracker/features/budgets/domain/category_budget.dart';
import 'package:uuid/uuid.dart';

class ThresholdMonitor {
  final AppDatabase db;
  final INotificationService notificationService;
  final Uuid _uuid;

  ThresholdMonitor({
    required this.db,
    required this.notificationService,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  /// Evaluates whether the updated [budget] crosses the 80% or over-budget threshold
  /// for [cycleId], records the event if new, and triggers the corresponding local notification.
  Future<void> evaluateAndNotify({
    required String cycleId,
    required CategoryBudget budget,
  }) async {
    final code = Intl.defaultLocale ?? 'en';
    final l10n = AppLocalizations(Locale(code.startsWith('ar') ? 'ar' : 'en'));
    final localizedCat = l10n.localizedCategoryName(budget.categoryName);

    // 1. Check Over Budget (remaining < 0)
    if (budget.isOverspent) {
      await _checkAndRecord(
        cycleId: cycleId,
        categoryId: budget.categoryId,
        eventType: 'over_budget',
        title: l10n.budgetExceededNotificationTitle,
        body: l10n.budgetExceededNotificationBody(
          localizedCat,
          (-budget.remainingAmount).toFormattedString(currencySymbol: l10n.currencySymbol),
        ),
      );
      return;
    } else {
      // Clear over_budget event if spending was reduced or transaction deleted
      await (db.delete(db.notificationEventsTable)
            ..where((tbl) =>
                tbl.cycleId.equals(cycleId) &
                tbl.categoryId.equals(budget.categoryId) &
                tbl.eventType.equals('over_budget')))
          .go();
    }

    // 2. Check 80% Warning (usagePercentage >= 80% and <= 100%)
    if (budget.isNearLimit) {
      await _checkAndRecord(
        cycleId: cycleId,
        categoryId: budget.categoryId,
        eventType: 'reached_80_percent',
        title: l10n.budgetWarningNotificationTitle,
        body: l10n.budgetWarningNotificationBody(
          localizedCat,
          budget.usagePercentage!.toStringAsFixed(0),
        ),
      );
    } else {
      // Clear 80% event if spending was reduced below limit
      await (db.delete(db.notificationEventsTable)
            ..where((tbl) =>
                tbl.cycleId.equals(cycleId) &
                tbl.categoryId.equals(budget.categoryId) &
                tbl.eventType.equals('reached_80_percent')))
          .go();
    }
  }

  Future<void> _checkAndRecord({
    required String cycleId,
    required String categoryId,
    required String eventType,
    required String title,
    required String body,
  }) async {
    // Check if event has already been recorded for this category in this cycle
    final existing =
        await (db.select(db.notificationEventsTable)..where(
              (tbl) =>
                  tbl.cycleId.equals(cycleId) &
                  tbl.categoryId.equals(categoryId) &
                  tbl.eventType.equals(eventType),
            ))
            .getSingleOrNull();

    if (existing != null) {
      // Already notified for this threshold in this cycle
      return;
    }

    final now = DateTime.now().toIso8601String();
    final id = _uuid.v4();

    try {
      await db
          .into(db.notificationEventsTable)
          .insert(
            NotificationEventsTableCompanion.insert(
              id: id,
              cycleId: cycleId,
              categoryId: categoryId,
              eventType: eventType,
              createdAt: now,
            ),
          );

      // Generate a stable notification ID in range [30000, 79999] (disjoint from cycle reminder ID 25000)
      final notificationId =
          30000 + (Object.hash(cycleId, categoryId, eventType).abs() % 50000);

      await notificationService.showNotification(
        id: notificationId,
        title: title,
        body: body,
      );
    } catch (_) {
      // Ignored if race condition hits unique constraint or notification throws
    }
  }
}
