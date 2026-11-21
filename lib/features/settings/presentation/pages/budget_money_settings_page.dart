import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/date/budget_cycle_calculator.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/core/notifications/notification_service.dart';
import 'package:money_tracker/core/providers/currency_provider.dart';
import 'package:money_tracker/core/providers/cycle_providers.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/core/providers/savings_providers.dart';

import 'package:money_tracker/features/settings/presentation/widgets/settings_page_scaffold.dart';

class BudgetMoneySettingsPage extends ConsumerStatefulWidget {
  const BudgetMoneySettingsPage({super.key});

  @override
  ConsumerState<BudgetMoneySettingsPage> createState() =>
      _BudgetMoneySettingsPageState();
}

class _BudgetMoneySettingsPageState
    extends ConsumerState<BudgetMoneySettingsPage> {
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

  Future<void> _showCycleStartDayDialog(
    BuildContext context,
    int initialDay,
  ) async {
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
                    style: TextStyle(
                      color: dialogContentCtx.textSecondary,
                      fontSize: 13,
                    ),
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
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.today, size: 20),
                    ),
                    items: List.generate(31, (index) {
                      final day = index + 1;
                      final isAr = dialogContentCtx.l10n.isArabic;
                      final label = day == 1
                          ? (isAr
                                ? 'يوم 1 (شهر تقويمي)'
                                : 'Day 1 (Calendar Month)')
                          : day == 25
                          ? (isAr
                                ? 'يوم 25 (موعد الراتب الافتراضي)'
                                : 'Day 25 (Payday Default)')
                          : day == 31
                          ? (isAr
                                ? 'يوم 31 (نهاية الشهر / آخر يوم)'
                                : 'Day 31 (Month-End / Last Day)')
                          : (isAr
                                ? 'يوم $day'
                                : 'Day $day (${_formatOrdinal(day)})');
                      return DropdownMenuItem(value: day, child: Text(label));
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
                      color: dialogContentCtx.surfaceVariantColor.withValues(
                        alpha: 0.5,
                      ),
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
                              ? dialogContentCtx.l10n.dayLatePreviewDesc(
                                  selectedDay,
                                )
                              : dialogContentCtx.l10n.dayNormalPreviewDesc(
                                  selectedDay,
                                  selectedDay - 1,
                                ),
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
                  final toastMsg = context.l10n.cycleStartDayUpdatedToast(
                    selectedDay,
                  );
                  Navigator.pop(dialogCtx);
                  if (selectedDay != initialDay) {
                    await ref
                        .read(budgetCycleRepositoryProvider)
                        .realignCyclesOnStartDayChange(selectedDay);
                    await ref
                        .read(budgetCycleStartDayProvider.notifier)
                        .setStartDay(selectedDay);
                    await ref
                        .read(notificationServiceProvider)
                        .scheduleCycleStartReminder(
                          nextCycleReminderTime(
                            BudgetCycleCalculator(startDay: selectedDay),
                            DateTime.now(),
                          ),
                        );
                    final currentCycle = await ref
                        .read(budgetCycleRepositoryProvider)
                        .getCycleForDateOrNull(DateTime.now());
                    if (currentCycle != null) {
                      await ref
                          .read(savingsSyncServiceProvider)
                          .syncSavingsBudgetForCycle(cycleId: currentCycle.id);
                    }
                    // Realigning can move or delete cycles: drop any stale
                    // selections pointing at them.
                    ref.read(selectedCycleProvider.notifier).select(null);
                    ref.read(dashboardCycleProvider.notifier).select(null);
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
    final startDay = ref.watch(budgetCycleStartDayProvider).asData?.value ?? 1;
    return SettingsPageScaffold(
      title: context.l10n.settingsBudgetMoneyTitle,
      children: [
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
                  : context.l10n.customDaySubtitleSettings(
                      startDay,
                      startDay - 1,
                    ),
              style: TextStyle(color: context.textSecondary, fontSize: 13),
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
                Icon(Icons.chevron_right, color: context.textSecondary),
              ],
            ),
            onTap: () => _showCycleStartDayDialog(context, startDay),
          ),
        ),

        const SizedBox(height: 24),

        // Section: Primary Currency
        Text(
          context.l10n.sectionCurrency,
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
                      Icons.payments_outlined,
                      color: context.primaryColor,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.primaryCurrencyLabel,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: context.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            context.l10n.primaryCurrencySubtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Builder(
                  builder: (context) {
                    final selectedCurrency = ref.watch(primaryCurrencyProvider);
                    final isArabic = context.l10n.isArabic;

                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: AppCurrency.values.map((currency) {
                        final isSelected = currency == selectedCurrency;
                        return ChoiceChip(
                          key: ValueKey('currency_chip_${currency.code}'),
                          label: Text(
                            currency.displayLabel(isArabic: isArabic),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? context.primaryColor
                                  : context.textPrimary,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: context.primaryColor.withValues(
                            alpha: 0.16,
                          ),
                          checkmarkColor: context.primaryColor,
                          side: BorderSide(
                            color: isSelected
                                ? context.primaryColor
                                : context.borderColor,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              ref
                                  .read(primaryCurrencyProvider.notifier)
                                  .setCurrency(currency);
                            }
                          },
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
