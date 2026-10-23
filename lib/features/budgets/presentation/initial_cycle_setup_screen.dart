import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/date/budget_cycle_calculator.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/providers/cycle_providers.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/core/providers/language_provider.dart';

class InitialCycleSetupScreen extends ConsumerStatefulWidget {
  const InitialCycleSetupScreen({super.key});

  @override
  ConsumerState<InitialCycleSetupScreen> createState() =>
      _InitialCycleSetupScreenState();
}

enum _CycleMode { calendarMonth, customPayday }

class _InitialCycleSetupScreenState
    extends ConsumerState<InitialCycleSetupScreen> {
  _CycleMode? _selectedMode; // Null by default - NO DEFAULT VALUE!
  int? _selectedCustomDay; // Null by default - NO DEFAULT VALUE!
  bool _isSaving = false;

  int? get _effectiveDay {
    if (_selectedMode == _CycleMode.calendarMonth) {
      return 1;
    } else if (_selectedMode == _CycleMode.customPayday) {
      return _selectedCustomDay;
    }
    return null;
  }

  String _formatOrdinal(int day, {bool isArabic = false}) {
    if (isArabic) return '$day';
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

  Future<void> _handleConfirm() async {
    final day = _effectiveDay;
    if (day == null || _isSaving) return;

    final isArabic = context.l10n.isArabic;
    setState(() => _isSaving = true);

    try {
      // 1. Save start day to app_settings via provider
      await ref.read(budgetCycleStartDayProvider.notifier).setStartDay(day);

      // 2. Seed default categories if none exist and unarchive any inactive categories
      final catRepo = ref.read(categoryRepositoryProvider);
      final lang = ref.read(appLanguageProvider).value?.languageCode ?? (isArabic ? 'ar' : 'en');
      await catRepo.seedDefaultCategories(languageCode: lang);
      await catRepo.unarchiveAllCategories();

      // 3. Initialize the budget cycle for today
      final cycleRepo = ref.read(budgetCycleRepositoryProvider);
      await cycleRepo.getOrCreateCycleForDate(DateTime.now());

      // 4. Trigger reactive refresh
      ref.read(refreshTriggerProvider.notifier).trigger();
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.failedToSave(e.toString())),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Widget _buildSelectionIndicator(bool isSelected) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? context.primaryColor : context.borderColor,
          width: 2,
        ),
        color: isSelected ? context.primaryColor : Colors.transparent,
      ),
      child: isSelected
          ? const Center(
              child: Icon(Icons.check, size: 16, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildBadge({required String label, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.surfaceVariantColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.primaryColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveDay = _effectiveDay;
    final now = DateTime.now();
    final sampleCycle = effectiveDay != null
        ? BudgetCycleCalculator(startDay: effectiveDay).getCycleForDate(now)
        : null;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: context.primaryColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.calendar_month_rounded,
                    size: 38,
                    color: context.primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                context.l10n.welcomeTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.setupCycleDescription,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: context.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),

              // Option 1: Calendar Month Card
              InkWell(
                onTap: () {
                  setState(() {
                    _selectedMode = _CycleMode.calendarMonth;
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _selectedMode == _CycleMode.calendarMonth
                        ? context.primaryColor.withValues(alpha: 0.08)
                        : context.surfaceVariantColor.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _selectedMode == _CycleMode.calendarMonth
                          ? context.primaryColor
                          : context.borderColor,
                      width: _selectedMode == _CycleMode.calendarMonth ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      _buildSelectionIndicator(
                        _selectedMode == _CycleMode.calendarMonth,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.calendarMonth,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: context.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              context.l10n.calendarMonthSubtitle,
                              style: TextStyle(
                                fontSize: 13,
                                color: context.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              children: [
                                _buildBadge(
                                  label: context.l10n.isArabic ? 'البداية: 1' : 'Starts: 1st',
                                  icon: Icons.play_arrow_rounded,
                                ),
                                _buildBadge(
                                  label: context.l10n.isArabic ? 'النهاية: آخر يوم' : 'Ends: Last Day',
                                  icon: Icons.stop_rounded,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Option 2: Custom Payday Cycle Card
              InkWell(
                onTap: () {
                  setState(() {
                    _selectedMode = _CycleMode.customPayday;
                    _selectedCustomDay ??= 25; // Convenient initial day once mode selected
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _selectedMode == _CycleMode.customPayday
                        ? context.primaryColor.withValues(alpha: 0.08)
                        : context.surfaceVariantColor.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _selectedMode == _CycleMode.customPayday
                          ? context.primaryColor
                          : context.borderColor,
                      width: _selectedMode == _CycleMode.customPayday ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildSelectionIndicator(
                            _selectedMode == _CycleMode.customPayday,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.l10n.customPaydayCycle,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: context.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  context.l10n.customPaydayCycleSubtitle,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: context.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_selectedMode == _CycleMode.customPayday) ...[
                        const SizedBox(height: 14),
                        const Divider(height: 1),
                        const SizedBox(height: 14),
                        Text(
                          context.l10n.isArabic
                              ? 'حدد يوم بدء الدورة (1 - 31)'
                              : 'SELECT CYCLE START DAY (1 - 31)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: context.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          key: ValueKey(_selectedCustomDay),
                          initialValue: _selectedCustomDay,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: const Icon(Icons.today, size: 20),
                          ),
                          items: List.generate(31, (index) {
                            final day = index + 1;
                            final endDay = day == 1 ? 0 : day - 1;
                            final isAr = context.l10n.isArabic;
                            final label = isAr
                                ? (day == 1
                                    ? 'يوم 1 (شهر تقويمي: ينتهي بنهاية الشهر)'
                                    : day == 31
                                        ? 'يوم 31 (نهاية الشهر / آخر يوم)'
                                        : 'يوم $day (يبدأ: $day ➡️ ينتهي: $endDay)')
                                : (day == 1
                                    ? 'Day 1 (Calendar Month: Ends End of Month)'
                                    : day == 31
                                        ? 'Day 31 (Month-End / Last Day)'
                                        : 'Day $day (${_formatOrdinal(day)} ➡️ Ends: ${_formatOrdinal(endDay)})');
                            return DropdownMenuItem(
                              value: day,
                              child: Text(label, style: const TextStyle(fontSize: 13)),
                            );
                          }),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedCustomDay = val);
                            }
                          },
                        ),
                        if (_selectedCustomDay != null) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _buildBadge(
                                label: context.l10n.isArabic
                                    ? 'البداية: يوم $_selectedCustomDay'
                                    : 'Starts: ${_formatOrdinal(_selectedCustomDay!)}',
                                icon: Icons.play_arrow_rounded,
                              ),
                              _buildBadge(
                                label: context.l10n.isArabic
                                    ? (_selectedCustomDay == 1
                                        ? 'النهاية: آخر الشهر'
                                        : 'النهاية: اليوم السابق للدورة التالية')
                                    : (_selectedCustomDay == 1
                                        ? 'Ends: End of month'
                                        : 'Ends: Day before next cycle'),
                                icon: Icons.stop_rounded,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Live Date Preview Box
              if (sampleCycle != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context.primaryColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        color: context.primaryColor,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.isArabic
                                  ? 'نطاق الدورة الفعالة:'
                                  : 'Active Cycle Range:',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: context.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              sampleCycle.formattedRange,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: context.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.surfaceVariantColor.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.borderColor),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: context.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.l10n.isArabic
                              ? 'اختر أحد الخيارات أعلاه لتحديد دورة ميزانيتك الشهرية.'
                              : 'Select one of the options above to configure your monthly cycle.',
                          style: TextStyle(
                            fontSize: 13,
                            color: context.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 32),

              // Confirm Button (Disabled until an option is selected)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                onPressed: effectiveDay == null || _isSaving
                    ? null
                    : _handleConfirm,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        context.l10n.confirmAndContinue,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.isArabic
                    ? 'يمكنك دائماً تعديل أيام بدء ونهاية الدورة لاحقاً من الإعدادات.'
                    : 'You can always modify your cycle start and end days later in Settings.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: context.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
