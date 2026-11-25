import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/core/notifications/notification_service.dart';
import 'package:money_tracker/core/providers/bill_providers.dart';
import 'package:money_tracker/core/providers/cycle_providers.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/features/bills/data/bill_reminder_scheduler.dart';
import 'package:money_tracker/features/bills/domain/recurring_bill.dart';
import 'package:money_tracker/features/bills/presentation/bills_screen.dart';
import 'package:money_tracker/features/categories/data/category_repository.dart';
import 'package:money_tracker/features/categories/domain/category.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';
import '../../test_helper.dart';

class _NoNotifications implements INotificationService {
  @override
  Future<bool> initialize() async => true;
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> showNotification({required int id, required String title, required String body}) async {}
  @override
  Future<void> scheduleCycleStartReminder(DateTime at) async {}
  @override
  Future<void> scheduleDailyEveningReminder({required int hour, required int minute}) async {}
  @override
  Future<void> cancelDailyEveningReminder() async {}
  @override
  Future<void> sendTestReminder() async {}
  @override
  Future<void> cancel(int id) async {}
}

class _NoReminders implements BillReminderScheduler {
  @override
  Future<void> schedule({required RecurringBill bill, required DateTime at, required DateTime dueDate}) async {}
  @override
  Future<void> cancel(String billId) async {}
}

void main() {
  setUpAll(setupTestSqlite);

  Future<AppDatabase> pumpBills(WidgetTester tester, {Locale locale = const Locale('en')}) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.into(db.appSettingsTable).insert(
          AppSettingsTableCompanion.insert(key: 'budget_cycle_start_day', value: '1'),
        );
    await CategoryRepository(db).createCategory(
      name: 'Housing',
      type: CategoryType.expense,
      defaultBudget: const Money.fromMinorUnits(900000),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notificationServiceProvider.overrideWithValue(_NoNotifications()),
          billReminderSchedulerProvider.overrideWithValue(_NoReminders()),
        ],
        child: MaterialApp(
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const BillsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return db;
  }

  testWidgets('add a bill, see it due today, and pay it in one tap', (tester) async {
    final db = await pumpBills(tester);
    expect(find.text('No bills yet'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('bills_add_first')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('bill_title_field')), 'Rent');
    await tester.enterText(find.byKey(const ValueKey('bill_amount_field')), '8000');

    // Saving without a category is refused for an expense.
    await tester.ensureVisible(find.byKey(const ValueKey('bill_save_button')));
    await tester.tap(find.byKey(const ValueKey('bill_save_button')));
    await tester.pumpAndSettle();
    expect(find.text('Please select a category for this expense'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('bill_category_expense')));
    await tester.tap(find.byKey(const ValueKey('bill_category_expense')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Housing').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('bill_save_button')));
    await tester.tap(find.byKey(const ValueKey('bill_save_button')));
    await tester.pumpAndSettle();

    // The due date defaults to today, so it needs attention right away.
    expect(find.text('NEEDS ATTENTION'), findsOneWidget);
    expect(find.textContaining('Due today'), findsOneWidget);
    expect(find.text('Bills per month'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('bills_committed_total'))).data,
      Money.fromMinorUnits(800000).toFormattedString(),
    );

    final bill = (await db.select(db.recurringBillsTable).get()).single;
    expect(bill.remindDaysBefore, 1);
    await tester.tap(find.byKey(ValueKey('bill_pay_${bill.id}')));
    await tester.pumpAndSettle();

    expect(find.text('Logged "Rent"'), findsOneWidget);
    expect(find.text('NEEDS ATTENTION'), findsNothing);
    final txs = await db.select(db.transactionsTable).get();
    expect(txs.single.amountMinor, 800000);
    expect(txs.single.note, 'Rent');

    // Undo removes the payment and the bill is due again.
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(await db.select(db.transactionsTable).get(), isEmpty);
    expect(find.textContaining('Due today'), findsOneWidget);
  });

  testWidgets('renders in Arabic with right-to-left layout', (tester) async {
    await pumpBills(tester, locale: const Locale('ar'));
    expect(find.text('الفواتير والاشتراكات'), findsOneWidget);
    expect(find.text('لا توجد فواتير بعد'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('لا توجد فواتير بعد'))),
      TextDirection.rtl,
    );
  });

  testWidgets('due rows fit a narrow phone in Arabic', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final db = await pumpBills(tester, locale: const Locale('ar'));
    final category = (await db.select(db.categoriesTable).get()).single;
    final container = ProviderScope.containerOf(tester.element(find.byType(BillsScreen)));
    final now = DateTime.now();
    await container.read(billServiceProvider).create(
          title: 'اشتراك الإنترنت المنزلي فائق السرعة مع الهاتف الأرضي',
          type: TransactionType.expense,
          categoryId: category.id,
          amount: const Money.fromMinorUnits(123456789),
          isVariable: true,
          frequency: BillFrequency.monthly,
          anchorDate: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 12)),
        );
    container.read(refreshTriggerProvider.notifier).trigger();
    await tester.pumpAndSettle();

    expect(find.text('تحتاج إلى إجراء'), findsOneWidget);
    expect(find.text('تم الدفع'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
