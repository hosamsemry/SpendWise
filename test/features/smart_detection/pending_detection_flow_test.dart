import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/core/providers/cycle_providers.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/features/budgets/data/budget_cycle_repository.dart';
import 'package:money_tracker/features/categories/data/category_repository.dart';
import 'package:money_tracker/features/categories/domain/category.dart';
import 'package:money_tracker/features/dashboard/presentation/dashboard_screen.dart';
import 'package:money_tracker/features/smart_detection/data/pending_transaction_repository.dart';
import 'package:money_tracker/features/smart_detection/presentation/pending_transactions_banner.dart';
import 'package:money_tracker/features/smart_detection/presentation/pending_transactions_sheet.dart';
import 'package:money_tracker/features/smart_detection/presentation/smart_detection_providers.dart';
import 'package:money_tracker/features/transactions/data/transaction_repository.dart';
import 'package:money_tracker/features/transactions/presentation/add_edit_transaction_dialog.dart';
import '../../test_helper.dart';

void main() {
  setUpAll(() {
    setupTestSqlite();
  });

  Future<({AppDatabase db, Category food, Category utilities})>
      createSeededDb() async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.into(db.appSettingsTable).insert(
          AppSettingsTableCompanion.insert(key: 'app_language', value: 'en'),
        );
    await db.into(db.appSettingsTable).insert(
          AppSettingsTableCompanion.insert(
            key: 'budget_cycle_start_day',
            value: '1',
          ),
        );

    final catRepo = CategoryRepository(db);
    final food = await catRepo.createCategory(
      name: 'Food',
      type: CategoryType.expense,
      defaultBudget: const Money.fromMinorUnits(300000),
    );
    final utilities = await catRepo.createCategory(
      name: 'Utilities',
      type: CategoryType.expense,
      defaultBudget: const Money.fromMinorUnits(200000),
    );

    final cycleRepo = BudgetCycleRepository(db);
    await cycleRepo.getOrCreateCycleForDate(DateTime.now());
    return (db: db, food: food, utilities: utilities);
  }

  test(
    'PendingTransactionRepository deduplicates alerts and learns merchant-to-category mapping',
    () async {
      final setup = await createSeededDb();
      addTearDown(setup.db.close);

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(setup.db)],
      );
      addTearDown(container.dispose);
      await container.read(budgetCycleStartDayProvider.future);
      final repo = container.read(pendingTransactionRepositoryProvider);

      const sampleAlert =
          'تم خصم مبلغ 515.00 جم لحظيا باستخدام (شبكة المدفوعات اللحظية) من حسابكم رقم 0140 عند كهرباء جنوب القاهرة يوم 10-29 الساعة20:32 مرجع التاجر 1613746459 للمزيد اتصل بـ 19623.';

      // First ingestion queues pending item
      final first = await repo.ingestMessage(sampleAlert);
      expect(first, isNotNull);
      expect(first!.amount, const Money.fromMinorUnits(51500));
      expect(first.note, 'كهرباء جنوب القاهرة');
      expect(first.suggestedCategoryId, isNull);

      // Duplicate delivery with same merchant ref is ignored
      final duplicate = await repo.ingestMessage(sampleAlert);
      expect(duplicate, isNull);

      // Confirm with Utilities category -> inserts transaction & learns merchant mapping
      await container.read(smartDetectionCoordinatorProvider).confirmPending(
        pending: first,
        type: first.type,
        amount: first.amount,
        categoryId: setup.utilities.id,
        date: DateTime.now(),
        note: first.note,
      );

      expect(await repo.getPendingTransactions(), isEmpty);
      final txs = await TransactionRepository(setup.db).getAllTransactions();
      expect(txs.length, 1);
      expect(txs.first.categoryId, setup.utilities.id);

      // Future alert from the same merchant automatically pre-selects Utilities!
      const nextMonthAlert =
          'تم خصم مبلغ 620.00 جم لحظيا باستخدام (شبكة المدفوعات اللحظية) من حسابكم رقم 0140 عند كهرباء جنوب القاهرة يوم 11-29 الساعة10:15 مرجع التاجر 999888777 للمزيد اتصل بـ 19623.';
      final second = await repo.ingestMessage(nextMonthAlert);
      expect(second, isNotNull);
      expect(second!.suggestedCategoryId, setup.utilities.id);
    },
  );

  testWidgets(
    'Dashboard shows PendingTransactionsBanner and confirms detected transaction into ledger',
    (tester) async {
      final setup = await createSeededDb();
      addTearDown(setup.db.close);

      final pendingRepo = PendingTransactionRepository(setup.db);
      final pending = await pendingRepo.ingestMessage(
        'تم خصم مبلغ 515.00 جم لحظيا باستخدام (شبكة المدفوعات اللحظية) من حسابكم رقم 0140 عند كهرباء جنوب القاهرة يوم 10-29 الساعة20:32 مرجع التاجر 1613746459 للمزيد اتصل بـ 19623.',
      );
      expect(pending, isNotNull);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(setup.db)],
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: const [Locale('en'), Locale('ar')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: DashboardScreen(
              onNavigateToTransactions: () {},
              onNavigateToBudgets: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Banner is visible on Dashboard
      expect(find.byType(PendingTransactionsBanner), findsOneWidget);
      expect(find.text('1 detected transaction to confirm'), findsOneWidget);

      // 2. Tap banner -> opens PendingTransactionsSheet
      await tester.tap(
        find.byKey(const ValueKey('pending_transactions_banner')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PendingTransactionsSheet), findsOneWidget);
      expect(find.text('Detected Transactions'), findsOneWidget);

      // 3. Pick Utilities category and Confirm & Save
      await tester.tap(
        find.byKey(ValueKey('pending_cat_${pending!.id}_${setup.utilities.id}')),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(ValueKey('pending_confirm_${pending.id}')),
      );
      await tester.pumpAndSettle();

      // Sheet closed, banner gone, transaction persisted to DB!
      expect(find.byType(PendingTransactionsSheet), findsNothing);
      expect(
        find.byKey(const ValueKey('pending_transactions_banner')),
        findsNothing,
      );

      final txs = await TransactionRepository(setup.db).getAllTransactions();
      expect(txs.length, 1);
      expect(txs.first.amount, const Money.fromMinorUnits(51500));
      expect(txs.first.note, 'كهرباء جنوب القاهرة');
      expect(txs.first.categoryId, setup.utilities.id);
    },
  );

  testWidgets(
    'AddEditTransactionDialog Paste SMS button parses clipboard alert directly into form fields',
    (tester) async {
      final setup = await createSeededDb();
      addTearDown(setup.db.close);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.getData') {
          return <String, dynamic>{
            'text':
                'IPN transfer sent with amount of EGP 100.01 from 5561 on 18/11 at 03:49 PM. Ref# 18369757. For more details call 19700.',
          };
        }
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(setup.db)],
      );
      addTearDown(container.dispose);

      // Trigger categories load
      await container.read(categoriesProvider.future);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            locale: Locale('en'),
            supportedLocales: [Locale('en'), Locale('ar')],
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(body: AddEditTransactionDialog()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('paste_sms_dialog_btn')));
      await tester.pumpAndSettle();

      expect(find.text('100.01'), findsOneWidget);
      expect(find.text('IPN transfer'), findsOneWidget);
    },
  );
}
