import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_tracker/core/date/budget_cycle_calculator.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/features/budgets/domain/cycle_summary.dart';
import 'package:money_tracker/features/transactions/data/transaction_repository.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class CsvExportService {
  final TransactionRepository transactionRepo;

  CsvExportService(this.transactionRepo);

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
    buffer.writeln('ID,Date,Type,Category,Amount (EGP),Note,Created At');

    for (final tx in transactions) {
      final dateStr = BudgetCycleCalculator.formatDate(tx.date);
      final typeStr = tx.type.name.toUpperCase();
      final rawCat = tx.categoryName ?? (tx.isIncome ? 'Uncategorized Income' : 'Uncategorized');
      final localizedCat = categoryLocalizer != null ? categoryLocalizer(rawCat) : rawCat;
      final catStr = _escapeCsv(localizedCat);
      final amountStr = (tx.amount.inMinorUnits / 100.0).toStringAsFixed(2);
      final noteStr = _escapeCsv(tx.note);
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

    buffer.writeln(
      'Category,Budgeted (EGP),Spent (EGP),Remaining (EGP),Usage %',
    );
    for (final b in summary.categoryBudgets) {
      final localizedCat = categoryLocalizer != null ? categoryLocalizer(b.categoryName) : b.categoryName;
      final catName = _escapeCsv(localizedCat);
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
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
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
