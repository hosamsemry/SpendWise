import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/providers/bill_providers.dart';
import 'package:money_tracker/features/bills/presentation/bill_actions.dart';
import 'package:money_tracker/features/bills/presentation/bills_screen.dart';

/// Dashboard card listing unpaid bills due within a week (overdue first),
/// each with Skip and Paid. Hidden when nothing is due.
class DueBillsCard extends ConsumerWidget {
  static const int maxRows = 3;

  const DueBillsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dueAsync = ref.watch(billsDueSoonProvider);
    return dueAsync.when(
      skipLoadingOnReload: true,
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (dues) {
        if (dues.isEmpty) return const SizedBox.shrink();
        final accent = context.accentColor;
        final shown = dues.take(maxRows).toList();
        final more = dues.length - shown.length;

        return Container(
          key: const ValueKey('due_bills_card'),
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 6),
          decoration: BoxDecoration(
            color: context.isDark ? accent.withValues(alpha: 0.08) : context.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: context.isDark ? 0.35 : 0.45)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.event_note_rounded, size: 18, color: accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.billsDueSoon,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('due_bills_see_all'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: accent,
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const BillsScreen()),
                    ),
                    child: Text(more > 0 ? '${context.l10n.seeAllBills} (+$more)' : context.l10n.seeAllBills),
                  ),
                ],
              ),
              for (final due in shown) BillDueTile(due: due),
            ],
          ),
        );
      },
    );
  }
}
