import 'package:drift/drift.dart';
import 'connection/connection.dart';
import 'tables/app_settings_table.dart';
import 'tables/budget_cycles_table.dart';
import 'tables/categories_table.dart';
import 'tables/category_budgets_table.dart';
import 'tables/notification_events_table.dart';
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
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? openConnection());

  @override
  int get schemaVersion => 4;

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
    },
  );
}
