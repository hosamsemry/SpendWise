import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/providers/currency_provider.dart';
import 'package:money_tracker/core/providers/bill_providers.dart';
import 'package:money_tracker/core/date/budget_cycle_calculator.dart';
import 'package:money_tracker/core/notifications/notification_service.dart';
import 'package:money_tracker/core/providers/cycle_providers.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/core/providers/language_provider.dart';
import 'package:money_tracker/core/providers/reminder_provider.dart';
import 'package:money_tracker/core/providers/savings_providers.dart';
import 'package:money_tracker/core/providers/theme_provider.dart';
import 'package:money_tracker/core/providers/transaction_providers.dart';
import 'package:money_tracker/features/backup/data/safety_snapshot_store.dart';
import 'package:money_tracker/features/backup/domain/backup_data.dart';
import 'package:money_tracker/features/backup/presentation/backup_password_dialogs.dart';
import 'package:money_tracker/features/backup/presentation/backup_providers.dart';
import 'package:money_tracker/features/export/data/csv_export_service.dart';

import 'package:money_tracker/features/settings/presentation/widgets/settings_page_scaffold.dart';

class BackupExportSettingsPage extends ConsumerStatefulWidget {
  const BackupExportSettingsPage({super.key});

  @override
  ConsumerState<BackupExportSettingsPage> createState() =>
      _BackupExportSettingsPageState();
}

class _BackupExportSettingsPageState
    extends ConsumerState<BackupExportSettingsPage> {
  /// The data saved automatically before the last restore, if any.
  SafetySnapshot? _undoSnapshot;

  @override
  void initState() {
    super.initState();
    _loadUndoSnapshot();
  }

  Future<void> _loadUndoSnapshot() async {
    final snapshot =
        await ref.read(backupServiceProvider).latestSafetySnapshot();
    if (mounted) setState(() => _undoSnapshot = snapshot);
  }

  String _formatSnapshotDate(DateTime at) => DateFormat(
        'MMM d, yyyy • h:mm a',
        context.l10n.isArabic ? 'ar' : 'en',
      ).format(at);

  /// Reloads everything that depends on the database after its contents were
  /// replaced (by a restore or an undo).
  Future<void> _refreshAfterRestore() async {
    ref.read(selectedCycleProvider.notifier).select(null);
    // The dashboard may be showing a cycle that no longer exists.
    ref.read(dashboardCycleProvider.notifier).select(null);
    ref.invalidate(budgetCycleStartDayProvider);
    ref.invalidate(appLanguageProvider);
    ref.invalidate(primaryCurrencyProvider);
    ref.invalidate(currentCycleProvider);
    ref.invalidate(allCyclesProvider);
    ref.invalidate(cycleSummaryProvider);
    ref.invalidate(transactionsForCycleProvider);

    final cycleRepo = ref.read(budgetCycleRepositoryProvider);
    final currentCycle = await cycleRepo.getCycleForDateOrNull(DateTime.now());
    if (currentCycle != null) {
      await cycleRepo.syncCategoriesForCycle(currentCycle.id);
      await ref
          .read(savingsSyncServiceProvider)
          .syncSavingsBudgetForCycle(cycleId: currentCycle.id);
    }

    // The restored data may have another start day and other bills.
    final startDay = await ref.read(budgetCycleStartDayProvider.future);
    if (startDay != null) {
      await ref.read(notificationServiceProvider).scheduleCycleStartReminder(
            nextCycleReminderTime(
              BudgetCycleCalculator(startDay: startDay),
              DateTime.now(),
            ),
          );
    }
    await ref.read(billServiceProvider).rescheduleReminders();

    ref.read(refreshTriggerProvider.notifier).trigger();
    ref.invalidate(themeModeProvider);
    ref.invalidate(dailyReminderProvider);
    await _loadUndoSnapshot();
  }

  Future<void> _undoLastRestore() async {
    final snapshot = _undoSnapshot;
    if (snapshot == null) return;
    final l10n = context.l10n;
    final date = _formatSnapshotDate(snapshot.createdAt);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l10n.undoRestoreDialogTitle),
        content: Text(l10n.undoRestoreDialogBody(date)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(l10n.undoRestoreAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(backupServiceProvider).undoLastRestore();
      await _refreshAfterRestore();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.undoRestoreDone)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.undoRestoreFailed(e.toString())),
            backgroundColor: context.overspentColor,
          ),
        );
      }
    }
  }

  Future<void> _exportAllTransactions() async {
    try {
      final exportService = ref.read(csvExportServiceProvider);
      final csv = await exportService.buildTransactionsCsv(
        categoryLocalizer: context.l10n.localizedCategoryName,
      );
      final nowStr = DateFormat(
        'yyyyMMdd_HHmm',
        'en_US',
      ).format(DateTime.now());
      await exportService.shareCsv(
        fileName: 'paydial_transactions_$nowStr.csv',
        csvContent: csv,
        subject: 'Paydial Transactions ($nowStr)',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.exportFailed(e.toString()))),
        );
      }
    }
  }

  Future<void> _exportCurrentCycle() async {
    try {
      final cycle = ref.read(currentCycleProvider).value;
      if (cycle == null) return;

      final summary = ref.read(cycleSummaryProvider(cycle)).value;
      if (summary == null) return;

      final exportService = ref.read(csvExportServiceProvider);
      final csv = exportService.buildCycleSummaryCsv(
        summary,
        categoryLocalizer: context.l10n.localizedCategoryName,
      );
      final startStr = DateFormat('yyyyMMdd', 'en_US').format(cycle.startDate);
      await exportService.shareCsv(
        fileName: 'paydial_cycle_$startStr.csv',
        csvContent: csv,
        subject: 'Paydial Budget Cycle (${cycle.formattedRange})',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.exportFailed(e.toString()))),
        );
      }
    }
  }

  Future<void> _createBackup() async {
    final choice = await showExportBackupDialog(context);
    if (choice == null || !mounted) return;
    try {
      final backupService = ref.read(backupServiceProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.isArabic
                ? 'جارٍ تجهيز النسخة الاحتياطية لباي دايل...'
                : 'Preparing Paydial backup...',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
      final file = await backupService.exportBackupFile(
        password: choice.password,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.isArabic
                  ? 'النسخة الاحتياطية جاهزة: ${file.path.split("/").last}'
                  : 'Backup ready: ${file.path.split("/").last}',
            ),
            backgroundColor: context.primaryColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.backupFailed(e.toString())),
            backgroundColor: context.overspentColor,
          ),
        );
      }
    }
  }

  Future<void> _restoreBackup() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.any);

      if (files.isEmpty) return;

      final picked = files.first;
      final bytes = await picked.readAsBytes();
      final jsonContent = utf8.decode(bytes);

      final backupService = ref.read(backupServiceProvider);
      final BackupData? parsed;
      if (backupService.isEncryptedBackup(jsonContent)) {
        if (!mounted) return;
        parsed = await showUnlockBackupDialog(
          context,
          unlock: (password) =>
              backupService.parseBackupContent(jsonContent, password: password),
        );
      } else {
        parsed = await backupService.parseBackupContent(jsonContent);
      }
      if (parsed == null) return;
      final BackupData backupData = parsed;

      if (!mounted) return;

      bool keepCurrentPin = true;
      bool keepSafetyCopy = true;
      final shouldRestore = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => StatefulBuilder(
          builder: (context, setDialogState) {
            final formattedDate = DateFormat(
              'MMM dd, yyyy • hh:mm a',
            ).format(backupData.metadata.createdAt);

            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: context.warningColor,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(context.l10n.restoreBackupDialogTitle)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.isArabic
                          ? 'تاريخ إنشاء النسخة الاحتياطية:'
                          : 'Backup snapshot created on:',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.surfaceVariantColor.withValues(
                          alpha: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.borderColor),
                      ),
                      child: Column(
                        children: [
                          _buildPreviewRow(
                            context.l10n.navTransactions,
                            '${backupData.transactionCount}',
                          ),
                          const Divider(height: 12),
                          _buildPreviewRow(
                            context.l10n.tabCategories,
                            '${backupData.categoryCount}',
                          ),
                          const Divider(height: 12),
                          _buildPreviewRow(
                            context.l10n.sectionBudgetCycle,
                            '${backupData.budgetCycleCount}',
                          ),
                          const Divider(height: 12),
                          _buildPreviewRow(
                            context.l10n.quickPresets,
                            '${backupData.presetCount}',
                          ),
                          const Divider(height: 12),
                          _buildPreviewRow(
                            context.l10n.billsTitle,
                            '${backupData.billCount}',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: keepCurrentPin,
                      title: Text(
                        context.l10n.preservePin,
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        context.l10n.preservePinSubtitle,
                        style: TextStyle(fontSize: 12),
                      ),
                      activeColor: context.primaryColor,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (val) {
                        setDialogState(() {
                          keepCurrentPin = val ?? true;
                        });
                      },
                    ),
                    CheckboxListTile(
                      key: const ValueKey('keep_safety_copy_checkbox'),
                      contentPadding: EdgeInsets.zero,
                      value: keepSafetyCopy,
                      title: Text(
                        context.l10n.keepSafetyCopy,
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        context.l10n.keepSafetyCopySubtitle,
                        style: const TextStyle(fontSize: 12),
                      ),
                      activeColor: context.primaryColor,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (val) {
                        setDialogState(() {
                          keepSafetyCopy = val ?? true;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.l10n.restoreWarning(undoable: keepSafetyCopy),
                      style: TextStyle(
                        color: context.overspentColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: Text(context.l10n.cancel),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.overspentColor,
                    foregroundColor: context.onOverspentColor,
                  ),
                  onPressed: () => Navigator.pop(dialogCtx, true),
                  child: Text(
                    context.l10n.isArabic ? 'استعادة البيانات' : 'Restore Data',
                  ),
                ),
              ],
            );
          },
        ),
      );

      if (shouldRestore != true || !mounted) return;

      await backupService.restoreFromBackup(
        backupData,
        keepCurrentPin: keepCurrentPin,
        takeSafetySnapshot: keepSafetyCopy,
      );

      await _refreshAfterRestore();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.restoreCompleted(
                backupData.transactionCount,
                backupData.categoryCount,
              ),
            ),
            backgroundColor: context.primaryColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.restoreFailed(e.toString())),
            backgroundColor: context.overspentColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Widget _buildPreviewRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13)),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsPageScaffold(
      title: context.l10n.settingsBackupExportTitle,
      children: [
        Card(
          child: Column(
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: context.primaryColor.withValues(alpha: 0.12),
                  child: Icon(
                    Icons.save_alt_rounded,
                    color: context.primaryColor,
                  ),
                ),
                title: Text(
                  context.l10n.createBackup,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
                subtitle: Text(
                  context.l10n.isArabic
                      ? 'حفظ نسخة كاملة من بياناتك (.json) محلياً أو على السحابة'
                      : 'Save complete snapshot (.json) to storage or cloud',
                  style: TextStyle(color: context.textSecondary, fontSize: 13),
                ),
                trailing: const Icon(Icons.share_outlined),
                onTap: _createBackup,
              ),
              const Divider(indent: 72, endIndent: 16),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: context.primaryLightColor,
                  child: Icon(
                    Icons.settings_backup_restore_rounded,
                    color: context.primaryColor,
                  ),
                ),
                title: Text(
                  context.l10n.restoreBackup,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
                subtitle: Text(
                  context.l10n.isArabic
                      ? 'استعادة المعاملات والميزانيات والفئات والقوالب السريعة'
                      : 'Restore transactions, budgets, categories & presets',
                  style: TextStyle(color: context.textSecondary, fontSize: 13),
                ),
                trailing: const Icon(Icons.file_open_outlined),
                onTap: _restoreBackup,
              ),
              if (_undoSnapshot != null) ...[
                const Divider(indent: 72, endIndent: 16),
                ListTile(
                  key: const ValueKey('undo_last_restore_tile'),
                  leading: CircleAvatar(
                    backgroundColor: context.warningLightColor,
                    child: Icon(
                      Icons.undo_rounded,
                      color: context.warningColor,
                    ),
                  ),
                  title: Text(
                    context.l10n.undoRestoreTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: context.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    context.l10n.undoRestoreSubtitle(
                      _formatSnapshotDate(_undoSnapshot!.createdAt),
                    ),
                    style: TextStyle(color: context.textSecondary, fontSize: 13),
                  ),
                  onTap: _undoLastRestore,
                ),
              ],
              const Divider(indent: 72, endIndent: 16),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: context.primaryLightColor,
                  child: Icon(
                    Icons.table_chart_outlined,
                    color: context.primaryColor,
                  ),
                ),
                title: Text(
                  context.l10n.exportTransactionsCsv,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
                subtitle: Text(
                  context.l10n.isArabic
                      ? 'تنزيل سجل كل المعاملات بصيغة CSV'
                      : 'Download complete transaction ledger in CSV format',
                  style: TextStyle(color: context.textSecondary, fontSize: 13),
                ),
                trailing: const Icon(Icons.share_outlined),
                onTap: _exportAllTransactions,
              ),
              const Divider(indent: 72, endIndent: 16),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: context.primaryLightColor,
                  child: Icon(
                    Icons.pie_chart_outline_rounded,
                    color: context.primaryColor,
                  ),
                ),
                title: Text(
                  context.l10n.exportCycleSummaryCsv,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
                subtitle: Text(
                  context.l10n.isArabic
                      ? 'تفاصيل ميزانيات الفئات وصافي الرصيد للدورة الحالية'
                      : 'Category budget breakdown and net balance summary',
                  style: TextStyle(color: context.textSecondary, fontSize: 13),
                ),
                trailing: const Icon(Icons.share_outlined),
                onTap: _exportCurrentCycle,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
