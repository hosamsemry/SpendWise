import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_tracker/core/date/budget_cycle_calculator.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/features/budgets/domain/cycle_summary.dart';
import 'package:money_tracker/features/transactions/data/transaction_repository.dart';
import 'package:money_tracker/core/files/export_file_store.dart';
import 'package:share_plus/share_plus.dart';

class CsvExportService {
  final TransactionRepository transactionRepo;
  final ExportFileStore exportFiles;

  CsvExportService(this.transactionRepo, {ExportFileStore? exportFiles})
      : exportFiles = exportFiles ?? ExportFileStore();

  static const _formulaTriggers = {'=', '+', '-', '@', '\t', '\r'};

  /// Escapes a free-text cell (category names, notes). Text that a spreadsheet
  /// would run as a formula (CSV injection) is prefixed with `'` so Excel /
  /// Google Sheets show it as text. Notes can come from bank SMS, so their
  /// content is partly attacker-controlled. Never use this for numeric cells.
  String _escapeText(String? value) {
    if (value == null || value.isEmpty) return '';
    final neutralized =
        _formulaTriggers.contains(value[0]) ? "'$value" : value;
    return _escapeCsv(neutralized);
  }

  String _escapeCsv(String? value) {
    if (value == null) return '';
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// Generates CSV text for all recorded transactions.
  Future<String> buildTransactionsCsv({
    String Function(String?)? categoryLocalizer,
  }) async {
    final transactions = await transactionRepo.getAllTransactions();
    final buffer = StringBuffer();

    // Prepend UTF-8 BOM for Excel
    buffer.write('\uFEFF');

    // CSV Header
    final currencySuffix = Money.currentCurrency == AppCurrency.none
        ? ''
        : ' (${Money.currentCurrency.code})';
    buffer.writeln(
      'ID,Date,Type,Category,Amount$currencySuffix,Note,Created At',
    );

    for (final tx in transactions) {
      final dateStr = BudgetCycleCalculator.formatDate(tx.date);
      final typeStr = tx.type.name.toUpperCase();
      final rawCat = tx.categoryName ?? (tx.isIncome ? 'Uncategorized Income' : 'Uncategorized');
      final localizedCat = categoryLocalizer != null ? categoryLocalizer(rawCat) : rawCat;
      final catStr = _escapeText(localizedCat);
      final amountStr = (tx.amount.inMinorUnits / 100.0).toStringAsFixed(2);
      final noteStr = _escapeText(tx.note);
      final createdStr = tx.createdAt.toIso8601String();

      buffer.writeln(
        '${tx.id},$dateStr,$typeStr,$catStr,$amountStr,$noteStr,$createdStr',
      );
    }

    return buffer.toString();
  }

  /// Generates CSV text for a specific cycle's budget summary.
  String buildCycleSummaryCsv(
    CycleSummary summary, {
    String Function(String?)? categoryLocalizer,
  }) {
    final buffer = StringBuffer();
    buffer.write('\uFEFF');

    buffer.writeln('Budget Cycle: ${summary.cycle.formattedRange}');
    buffer.writeln('Total Income: ${(summary.totalIncome.inMinorUnits / 100.0).toStringAsFixed(2)}');
    buffer.writeln(
      'Total Budgeted: ${(summary.totalBudgeted.inMinorUnits / 100.0).toStringAsFixed(2)}',
    );
    buffer.writeln('Total Spent: ${(summary.totalSpent.inMinorUnits / 100.0).toStringAsFixed(2)}');
    buffer.writeln(
      'Net Remaining: ${(summary.netRemainingTotal.inMinorUnits / 100.0).toStringAsFixed(2)}',
    );
    buffer.writeln('');

    final currencySuffix = Money.currentCurrency == AppCurrency.none
        ? ''
        : ' (${Money.currentCurrency.code})';
    buffer.writeln(
      'Category,Budgeted$currencySuffix,Spent$currencySuffix,Remaining$currencySuffix,Usage %',
    );
    for (final b in summary.categoryBudgets) {
      final localizedCat = categoryLocalizer != null ? categoryLocalizer(b.categoryName) : b.categoryName;
      final catName = _escapeText(localizedCat);
      final budgeted = (b.budgetedAmount.inMinorUnits / 100.0).toStringAsFixed(2);
      final spent = (b.spentAmount.inMinorUnits / 100.0).toStringAsFixed(2);
      final remaining = (b.remainingAmount.inMinorUnits / 100.0).toStringAsFixed(2);
      final usage = b.usagePercentage != null
          ? b.usagePercentage!.toStringAsFixed(1)
          : 'N/A';

      buffer.writeln('$catName,$budgeted,$spent,$remaining,$usage%');
    }

    return buffer.toString();
  }

  /// Saves CSV string to a local file and invokes standard share sheet.
  Future<File> shareCsv({
    required String fileName,
    required String csvContent,
    required String subject,
  }) async {
    final file = await exportFiles.fileFor(fileName);
    final contentWithBom = csvContent.startsWith('\uFEFF') ? csvContent : '\uFEFF$csvContent';
    await file.writeAsString(contentWithBom);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: subject,
        text: 'Exported from SpendWise: $subject',
      ),
    );

    return file;
  }
}

final csvExportServiceProvider = Provider<CsvExportService>((ref) {
  final txRepo = ref.watch(transactionRepositoryProvider);
  return CsvExportService(txRepo);
});
