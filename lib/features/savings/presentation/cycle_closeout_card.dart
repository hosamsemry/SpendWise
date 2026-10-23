import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/providers/cycle_providers.dart';
import 'package:money_tracker/core/providers/savings_providers.dart';

class CycleCloseoutCard extends ConsumerWidget {
  final CycleCloseoutInfo closeout;

  const CycleCloseoutCard({
    super.key,
    required this.closeout,
  });

  Future<void> _sweepSurplus(BuildContext context, WidgetRef ref) async {
    HapticFeedback.mediumImpact();
    final repo = ref.read(savingsVaultRepositoryProvider);
    final cycle = closeout.cycle;
    final surplus = closeout.surplus;

    await repo.sweepSurplus(cycleId: cycle.id, amount: surplus);
    ref.read(refreshTriggerProvider.notifier).trigger();

    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.sweptSuccess(surplus.toFormattedString(currencySymbol: context.l10n.currencySymbol)),
        ),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: context.l10n.undo,
          textColor: Colors.amber,
          onPressed: () async {
            HapticFeedback.lightImpact();
            await repo.undoSweep(cycleId: cycle.id, amount: surplus);
            ref.read(refreshTriggerProvider.notifier).trigger();
          },
        ),
      ),
    );
  }

  Future<void> _dismiss(BuildContext context, WidgetRef ref) async {
    HapticFeedback.lightImpact();
    final repo = ref.read(savingsVaultRepositoryProvider);
    await repo.dismissCycle(closeout.cycle.id);
    ref.read(refreshTriggerProvider.notifier).trigger();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cycle = closeout.cycle;
    final surplus = closeout.surplus;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: context.isDark
              ? [
                  const Color(0xFF064E3B).withValues(alpha: 0.6),
                  const Color(0xFF0F172A),
                ]
              : [
                  const Color(0xFFD1FAE5),
                  const Color(0xFFECFDF5),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.isDark
              ? const Color(0xFF059669).withValues(alpha: 0.4)
              : const Color(0xFF34D399),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.savings_rounded,
                    color: Color(0xFF10B981),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.isArabic
                            ? 'اختتام الدورة — الفائض غير المنفق'
                            : 'CYCLE CLOSED — UNSPENT SURPLUS',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                          color: Color(0xFF10B981),
                        ),
                      ),
                      Text(
                        cycle.formattedRange,
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
            const SizedBox(height: 12),
            Text(
              context.l10n.isArabic
                  ? 'وفرت ${surplus.toFormattedString(currencySymbol: context.l10n.currencySymbol)} من دورتك السابقة!'
                  : 'You saved ${surplus.toFormattedString(currencySymbol: context.l10n.currencySymbol)} from your last budget cycle!',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.isArabic
                  ? 'حوّل هذا الفائض إلى خزينة المدخرات الدائمة لحفظ تقدمك المالي.'
                  : 'Sweep this surplus into your Lifetime Savings Vault to preserve your hard-earned progress.',
              style: TextStyle(
                fontSize: 12,
                color: context.textSecondary,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _sweepSurplus(context, ref),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: Text(
                      context.l10n.sweepToVault,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _dismiss(context, ref),
                  style: TextButton.styleFrom(
                    foregroundColor: context.textSecondary,
                  ),
                  child: Text(context.l10n.dismiss),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
