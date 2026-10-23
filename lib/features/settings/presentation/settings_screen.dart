import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/date/budget_cycle_calculator.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/providers/cycle_providers.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/core/providers/language_provider.dart';
import 'package:money_tracker/core/providers/reminder_provider.dart';
import 'package:money_tracker/core/providers/theme_provider.dart';
import 'package:money_tracker/core/security/biometric_service.dart';
import 'package:money_tracker/core/security/presentation/pin_lock_screen.dart';
import 'package:money_tracker/core/security/security_service.dart';
import 'package:money_tracker/features/backup/presentation/backup_providers.dart';
import 'package:money_tracker/features/export/data/csv_export_service.dart';
import 'package:money_tracker/features/presets/presentation/presets_management_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Future<void> _handlePinToggle(bool enable) async {
    final security = ref.read(securityServiceProvider);
    if (enable) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => PinLockScreen(
            mode: PinMode.create,
            onCancel: () => Navigator.pop(ctx),
            onPinCreated: (firstPin) {
              Navigator.pushReplacement(
                ctx,
                MaterialPageRoute(
                  builder: (confirmCtx) => PinLockScreen(
                    mode: PinMode.confirm,
                    pinToConfirm: firstPin,
                    onCancel: () => Navigator.pop(confirmCtx),
                    onPinCreated: (confirmedPin) async {
                      await security.setPin(confirmedPin);
                      if (confirmCtx.mounted) Navigator.pop(confirmCtx);
                      setState(() {});
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.l10n.pinEnabledSuccess),
                          ),
                        );
                      }
                    },
                  ),
                ),
              );
            },
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => PinLockScreen(
            mode: PinMode.unlock,
            onCancel: () => Navigator.pop(ctx),
            onUnlocked: () async {
              await security.resetPin();
              if (ctx.mounted) Navigator.pop(ctx);
              setState(() {});
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.l10n.pinDisabledSuccess)),
                );
              }
            },
          ),
        ),
      );
    }
  }

  Future<void> _exportAllTransactions() async {
    try {
      final exportService = ref.read(csvExportServiceProvider);
      final csv = await exportService.buildTransactionsCsv();
      final nowStr = DateFormat('yyyyMMdd_HHmm', 'en_US').format(DateTime.now());
      await exportService.shareCsv(
        fileName: 'spendwise_transactions_$nowStr.csv',
        csvContent: csv,
        subject: 'SpendWise Transactions ($nowStr)',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.exportFailed(e.toString()))));
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
      final csv = exportService.buildCycleSummaryCsv(summary);
      final startStr = DateFormat('yyyyMMdd', 'en_US').format(cycle.startDate);
      await exportService.shareCsv(
        fileName: 'spendwise_cycle_$startStr.csv',
        csvContent: csv,
        subject: 'SpendWise Budget Cycle (${cycle.formattedRange})',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.exportFailed(e.toString()))));
      }
    }
  }

  Future<void> _createBackup() async {
    try {
      final backupService = ref.read(backupServiceProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.isArabic
                ? 'جارٍ تجهيز النسخة الاحتياطية لسبيند وايز...'
                : 'Preparing SpendWise backup...',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
      final file = await backupService.exportBackupFile();
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
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _restoreBackup() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['spendwise', 'json'],
      );

      if (files.isEmpty) return;

      final picked = files.first;
      final bytes = await picked.readAsBytes();
      final jsonContent = utf8.decode(bytes);

      final backupService = ref.read(backupServiceProvider);
      final backupData = backupService.parseBackupString(jsonContent);

      if (!mounted) return;

      bool keepCurrentPin = true;
      final shouldRestore = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => StatefulBuilder(
          builder: (context, setDialogState) {
            final formattedDate = DateFormat('MMM dd, yyyy • hh:mm a').format(
              backupData.metadata.createdAt,
            );

            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
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
                      style: TextStyle(color: context.textSecondary, fontSize: 13),
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
                        color: context.surfaceVariantColor.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.borderColor),
                      ),
                      child: Column(
                        children: [
                          _buildPreviewRow(context.l10n.navTransactions, '${backupData.transactionCount}'),
                          const Divider(height: 12),
                          _buildPreviewRow(context.l10n.tabCategories, '${backupData.categoryCount}'),
                          const Divider(height: 12),
                          _buildPreviewRow(context.l10n.sectionBudgetCycle, '${backupData.budgetCycleCount}'),
                          const Divider(height: 12),
                          _buildPreviewRow(context.l10n.quickPresets, '${backupData.presetCount}'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: keepCurrentPin,
                      title: Text(context.l10n.preservePin, style: const TextStyle(fontSize: 14)),
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
                    const SizedBox(height: 12),
                    Text(
                      context.l10n.restoreWarning,
                      style: TextStyle(
                        color: Colors.redAccent.shade100,
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
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
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
      );

      ref.read(refreshTriggerProvider.notifier).trigger();
      ref.invalidate(themeModeProvider);
      ref.invalidate(dailyReminderProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.restoreCompleted(backupData.transactionCount, backupData.categoryCount),
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
            backgroundColor: Colors.redAccent,
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
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  String _formatOrdinal(int day) {
    if (day >= 11 && day <= 13) return '${day}th';
    switch (day % 10) {
      case 1:
        return '${day}st';
      case 2:
        return '${day}nd';
      case 3:
        return '${day}rd';
      default:
        return '${day}th';
    }
  }

  Future<void> _showCycleStartDayDialog(BuildContext context, int initialDay) async {
    int selectedDay = initialDay;
    final messenger = ScaffoldMessenger.of(context);
    final primaryColor = context.primaryColor;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogContentCtx, setDialogState) {
          final previewCalc = BudgetCycleCalculator(startDay: selectedDay);
          final sampleCycle = previewCalc.getCycleForDate(DateTime.now());

          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.calendar_month_rounded, color: primaryColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.l10n.cycleStartDayDialogTitle,
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dialogContentCtx.l10n.cycleStartDayDialogDesc,
                    style: TextStyle(color: dialogContentCtx.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    dialogContentCtx.l10n.quickPresets,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: dialogContentCtx.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(dialogContentCtx.l10n.firstCalendarMonth),
                        selected: selectedDay == 1,
                        onSelected: (selected) {
                          if (selected) {
                            setDialogState(() => selectedDay = 1);
                          }
                        },
                      ),
                      ChoiceChip(
                        label: Text(dialogContentCtx.l10n.twentyFifthPayday),
                        selected: selectedDay == 25,
                        onSelected: (selected) {
                          if (selected) {
                            setDialogState(() => selectedDay = 25);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    dialogContentCtx.l10n.customStartDayHeader,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: dialogContentCtx.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    key: ValueKey(selectedDay),
                    initialValue: selectedDay,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.today, size: 20),
                    ),
                    items: List.generate(31, (index) {
                      final day = index + 1;
                      final isAr = dialogContentCtx.l10n.isArabic;
                      final label = day == 1
                          ? (isAr ? 'يوم 1 (شهر تقويمي)' : 'Day 1 (Calendar Month)')
                          : day == 25
                              ? (isAr ? 'يوم 25 (موعد الراتب الافتراضي)' : 'Day 25 (Payday Default)')
                              : day == 31
                                  ? (isAr ? 'يوم 31 (نهاية الشهر / آخر يوم)' : 'Day 31 (Month-End / Last Day)')
                                  : (isAr ? 'يوم $day' : 'Day $day (${_formatOrdinal(day)})');
                      return DropdownMenuItem(
                        value: day,
                        child: Text(label),
                      );
                    }),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedDay = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: dialogContentCtx.surfaceVariantColor.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: dialogContentCtx.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dialogContentCtx.l10n.cyclePreviewHeader,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: dialogContentCtx.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          sampleCycle.formattedRange,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          selectedDay == 1
                              ? dialogContentCtx.l10n.dayOnePreviewDesc
                              : selectedDay >= 29
                                  ? dialogContentCtx.l10n.dayLatePreviewDesc(selectedDay)
                                  : dialogContentCtx.l10n.dayNormalPreviewDesc(selectedDay, selectedDay - 1),
                          style: TextStyle(
                            fontSize: 11,
                            color: dialogContentCtx.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(context.l10n.cancel),
              ),
              ElevatedButton(
                onPressed: () async {
                  final toastMsg = context.l10n.cycleStartDayUpdatedToast(selectedDay);
                  Navigator.pop(dialogCtx);
                  if (selectedDay != initialDay) {
                    await ref
                        .read(budgetCycleRepositoryProvider)
                        .realignCyclesOnStartDayChange(selectedDay);
                    await ref
                        .read(budgetCycleStartDayProvider.notifier)
                        .setStartDay(selectedDay);
                    ref.read(selectedCycleProvider.notifier).select(null);
                    ref.read(refreshTriggerProvider.notifier).trigger();
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(toastMsg),
                          backgroundColor: primaryColor,
                        ),
                      );
                    }
                  }
                },
                child: Text(context.l10n.save),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final security = ref.watch(securityServiceProvider);
    final startDay =
        ref.watch(budgetCycleStartDayProvider).asData?.value ?? 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settingsTitle),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            24 + MediaQuery.of(context).padding.bottom,
          ),
          children: [
            // Section 1: Quick Presets
            Text(
              context.l10n.sectionQuickPresets,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: 8),

            // Quick Presets Tile
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.amber.withValues(alpha: 0.12),
                  child: const Icon(
                    Icons.bolt_outlined,
                    color: Colors.amber,
                  ),
                ),
                title: Text(
                  context.l10n.quickPresetsTileTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
                subtitle: Text(
                  context.l10n.quickPresetsTileSubtitle,
                  style: TextStyle(
                    color: context.textSecondary,
                    fontSize: 13,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: context.textSecondary,
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PresetsManagementScreen(),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Section 2: Budget Cycle
            Text(
              context.l10n.sectionBudgetCycle,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: context.primaryColor.withValues(alpha: 0.12),
                  child: Icon(
                    Icons.calendar_month_outlined,
                    color: context.primaryColor,
                  ),
                ),
                title: Text(
                  context.l10n.cycleStartDay,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
                subtitle: Text(
                  startDay == 1
                      ? context.l10n.calendarMonthSubtitleSettings
                      : startDay == 25
                          ? context.l10n.paydaySubtitleSettings
                          : context.l10n.customDaySubtitleSettings(startDay, startDay - 1),
                  style: TextStyle(
                    color: context.textSecondary,
                    fontSize: 13,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: context.primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        context.l10n.dayLabel(startDay),
                        style: TextStyle(
                          color: context.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      color: context.textSecondary,
                    ),
                  ],
                ),
                onTap: () => _showCycleStartDayDialog(context, startDay),
              ),
            ),

            const SizedBox(height: 24),

            // Section: Language
            Text(
              context.l10n.sectionLanguage,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.language_rounded,
                          color: context.primaryColor,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          context.l10n.currentLanguageLabel,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment<String>(
                            value: 'en',
                            label: Text('English'),
                            icon: Icon(Icons.language, size: 16),
                          ),
                          ButtonSegment<String>(
                            value: 'ar',
                            label: Text('عربي'),
                            icon: Icon(Icons.translate, size: 16),
                          ),
                        ],
                        selected: {
                          ref.watch(appLanguageProvider).asData?.value?.languageCode ?? 'en'
                        },
                        onSelectionChanged: (set) {
                          ref
                              .read(appLanguageProvider.notifier)
                              .setLanguage(set.first);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Section 3: Appearance
            Text(
              context.l10n.sectionAppearance,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.palette_outlined,
                          color: context.primaryColor,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          context.l10n.themeModeLabel,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<ThemeMode>(
                        segments: [
                          ButtonSegment(
                            value: ThemeMode.system,
                            label: Text(context.l10n.themeSystem),
                            icon: const Icon(Icons.brightness_auto, size: 16),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            label: Text(context.l10n.themeLight),
                            icon: const Icon(Icons.light_mode, size: 16),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            label: Text(context.l10n.themeDark),
                            icon: const Icon(Icons.dark_mode, size: 16),
                          ),
                        ],
                        selected: {themeMode},
                        onSelectionChanged: (set) {
                          ref
                              .read(themeModeProvider.notifier)
                              .setThemeMode(set.first);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Section 4: Security Lock
            Text(
              context.l10n.sectionSecurity,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            FutureBuilder<bool>(
              future: security.isPinEnabled(),
              builder: (context, snapshot) {
                final isPinEnabled = snapshot.data ?? false;

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: isPinEnabled
                                      ? context.primaryColor.withValues(alpha: 0.12)
                                      : Colors.grey.withValues(alpha: 0.12),
                                  child: Icon(
                                    isPinEnabled
                                        ? Icons.lock_rounded
                                        : Icons.lock_open_rounded,
                                    color: isPinEnabled
                                        ? context.primaryColor
                                        : context.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.l10n.pinLock,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: context.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      isPinEnabled
                                          ? (context.l10n.isArabic
                                              ? 'التطبيق محمي برمز PIN مكون من 4 أرقام'
                                              : 'App is protected with a 4-digit PIN')
                                          : context.l10n.pinLockSubtitle,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: context.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Switch.adaptive(
                              value: isPinEnabled,
                              onChanged: (val) => _handlePinToggle(val),
                              activeTrackColor: context.primaryColor,
                            ),
                          ],
                        ),
                        if (isPinEnabled) ...[
                          const SizedBox(height: 12),
                          const Divider(),
                          const SizedBox(height: 8),
                          FutureBuilder<bool>(
                            future: ref.read(biometricServiceProvider).isBiometricsEnabled(),
                            builder: (context, bioSnap) {
                              final isBioEnabled = bioSnap.data ?? false;
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.fingerprint, size: 20, color: context.primaryColor),
                                      const SizedBox(width: 8),
                                      Text(
                                        context.l10n.biometricLock,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: context.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Switch.adaptive(
                                    value: isBioEnabled,
                                    activeTrackColor: context.primaryColor,
                                    onChanged: (val) async {
                                      final bioService = ref.read(biometricServiceProvider);
                                      final unsupportedNotice = context.l10n.isArabic
                                          ? 'المصادقة البيومترية غير مدعومة أو غير مفعلة على هذا الجهاز.'
                                          : 'Biometric authentication is not supported or enrolled on this device.';
                                      final reasonStr = context.l10n.isArabic
                                          ? 'تأكيد البصمة لتمكين الفتح السريع'
                                          : 'Confirm biometrics to enable quick unlock';
                                      if (val) {
                                        final supported = await bioService.isDeviceSupported();
                                        if (!supported) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(unsupportedNotice),
                                              ),
                                            );
                                          }
                                          return;
                                        }
                                        final authenticated = await bioService.authenticate(
                                          reason: reasonStr,
                                        );
                                        if (!authenticated) return;
                                      }
                                      await bioService.setBiometricsEnabled(val);
                                      setState(() {});
                                    },
                                  ),
                                ],
                              );
                            },
                          ),
                          const Divider(),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton.icon(
                                icon: const Icon(Icons.pin_outlined, size: 18),
                                label: Text(context.l10n.changePin),
                                onPressed: () => _handlePinToggle(true),
                              ),
                              TextButton.icon(
                                icon: Icon(
                                  Icons.lock_open_rounded,
                                  size: 18,
                                  color: context.overspentColor,
                                ),
                                label: Text(
                                  context.l10n.disablePin,
                                  style: TextStyle(
                                    color: context.overspentColor,
                                  ),
                                ),
                                onPressed: () => _handlePinToggle(false),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Section 4: Notifications & Reminders
            Text(
              context.l10n.sectionNotifications,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Consumer(
              builder: (context, ref, _) {
                final reminderSettings = ref.watch(dailyReminderProvider);

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: reminderSettings.isEnabled
                                      ? Colors.indigo.withValues(alpha: 0.12)
                                      : Colors.grey.withValues(alpha: 0.12),
                                  child: Icon(
                                    Icons.notifications_active_outlined,
                                    color: reminderSettings.isEnabled
                                        ? Colors.indigo
                                        : context.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.l10n.dailyEveningReminder,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: context.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      reminderSettings.isEnabled
                                          ? context.l10n.scheduledForTime(reminderSettings.formattedTime)
                                          : context.l10n.remindMeToLogDaily,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: context.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Switch.adaptive(
                              value: reminderSettings.isEnabled,
                              activeTrackColor: context.primaryColor,
                              onChanged: (val) async {
                                final success = await ref
                                    .read(dailyReminderProvider.notifier)
                                    .setEnabled(val);
                                if (!success && val && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        context.l10n.notificationPermissionDenied,
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                        if (reminderSettings.isEnabled) ...[
                          const SizedBox(height: 12),
                          const Divider(),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                context.l10n.reminderTime,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: context.textPrimary,
                                ),
                              ),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.access_time, size: 16),
                                label: Text(reminderSettings.formattedTime),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () async {
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay(
                                      hour: reminderSettings.hour,
                                      minute: reminderSettings.minute,
                                    ),
                                  );
                                  if (picked != null) {
                                    await ref
                                        .read(
                                          dailyReminderProvider.notifier,
                                        )
                                        .setTime(
                                          picked.hour,
                                          picked.minute,
                                        );
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Section 5: Data Backup & Export
            Text(
              context.l10n.sectionDataManagement,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
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
                          ? 'حفظ نسخة كاملة من بياناتك (.spendwise) محلياً أو على السحابة'
                          : 'Save complete snapshot (.spendwise) to storage or cloud',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    trailing: const Icon(Icons.share_outlined),
                    onTap: _createBackup,
                  ),
                  const Divider(indent: 72, endIndent: 16),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.amber.withValues(alpha: 0.12),
                      child: const Icon(
                        Icons.settings_backup_restore_rounded,
                        color: Colors.amber,
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
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    trailing: const Icon(Icons.file_open_outlined),
                    onTap: _restoreBackup,
                  ),
                  const Divider(indent: 72, endIndent: 16),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.withValues(alpha: 0.12),
                      child: const Icon(
                        Icons.table_chart_outlined,
                        color: Colors.blue,
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
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    trailing: const Icon(Icons.share_outlined),
                    onTap: _exportAllTransactions,
                  ),
                  const Divider(indent: 72, endIndent: 16),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.teal.withValues(alpha: 0.12),
                      child: const Icon(
                        Icons.pie_chart_outline_rounded,
                        color: Colors.teal,
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
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    trailing: const Icon(Icons.share_outlined),
                    onTap: _exportCurrentCycle,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    height: 48,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'SpendWise v1.0.0 • Offline & Private',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: context.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
