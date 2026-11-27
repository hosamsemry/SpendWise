import 'package:drift/drift.dart';
import 'connection/connection.dart';
import 'tables/app_settings_table.dart';
import 'tables/bill_occurrences_table.dart';
import 'tables/budget_cycles_table.dart';
import 'tables/categories_table.dart';
import 'tables/category_budgets_table.dart';
import 'tables/notification_events_table.dart';
import 'tables/recurring_bills_table.dart';
import 'tables/savings_goals_table.dart';
import 'tables/savings_movements_table.dart';
import 'tables/transaction_presets_table.dart';
import 'tables/transactions_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    CategoriesTable,
    BudgetCyclesTable,
    CategoryBudgetsTable,
    TransactionsTable,
    NotificationEventsTable,
    AppSettingsTable,
    TransactionPresetsTable,
    RecurringBillsTable,
    BillOccurrencesTable,
    SavingsGoalsTable,
    SavingsMovementsTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? openConnection());

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON;');
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(transaction_date);',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_transactions_category ON transactions(category_id);',
      );
    },
    onCreate: (m) async {
      await m.createAll();
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(transaction_date);',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_transactions_category ON transactions(category_id);',
      );
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(categoriesTable, categoriesTable.type);
      }
      if (from < 3) {
        await m.addColumn(transactionsTable, transactionsTable.categoryName);
      }
      if (from < 4) {
        await m.createTable(appSettingsTable);
        await m.createTable(transactionPresetsTable);
      }
      if (from < 5) {
        await m.createTable(recurringBillsTable);
        await m.createTable(billOccurrencesTable);
      }
      if (from < 6) {
        await m.createTable(savingsGoalsTable);
        await m.createTable(savingsMovementsTable);
        // The vault balance used to be one number in app_settings; it now
        // lives in the movement history as an opening entry.
        await migrateLegacyVaultBalance(this);
      }
    },
  );
}

/// app_settings key of the pre-v6 vault balance (minor units).
const String legacyVaultBalanceKey = 'savings_vault_balance_minor';

/// Moves a pre-v6 vault balance stored in app_settings into an 'opening'
/// savings movement and removes the old key. Safe to run more than once.
Future<void> migrateLegacyVaultBalance(AppDatabase db) async {
  final rows = await db
      .customSelect(
        'SELECT value FROM app_settings WHERE key = ?',
        variables: [Variable.withString(legacyVaultBalanceKey)],
      )
      .get();
  if (rows.isEmpty) return;
  final minor = int.tryParse(rows.first.read<String>('value')) ?? 0;
  if (minor > 0) {
    final now = DateTime.now().toIso8601String();
    await db.customStatement(
      'INSERT INTO savings_movements (id, goal_id, amount_minor, kind, group_id, cycle_id, created_at) '
      "VALUES (?, NULL, ?, 'opening', ?, NULL, ?)",
      ['opening-balance', minor, 'opening-balance', now],
    );
  }
  await db.customStatement(
    'DELETE FROM app_settings WHERE key = ?',
    [legacyVaultBalanceKey],
  );
}
