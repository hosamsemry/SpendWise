import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/providers/bill_providers.dart';
import 'package:money_tracker/core/providers/cycle_providers.dart';
import 'package:money_tracker/features/bills/domain/recurring_bill.dart';
import 'package:money_tracker/features/bills/presentation/bill_actions.dart';
import 'package:money_tracker/features/bills/presentation/bill_form_sheet.dart';

/// Lists every recurring bill with what is due now, the monthly total and
/// how much safe-to-spend is holding back for this cycle.
class BillsScreen extends ConsumerWidget {
  const BillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(billsOverviewProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.billsTitle)),
      floatingActionButton: FloatingActionButton(
        key: const ValueKey('bills_add_fab'),
        heroTag: 'bills_add_fab',
        tooltip: l10n.addBill,
        backgroundColor: context.primaryColor,
        foregroundColor: context.onPrimaryColor,
        onPressed: () => showBillForm(context),
        child: const Icon(Icons.add),
      ),
      body: overviewAsync.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${l10n.error}: $e')),
        data: (overview) {
          if (overview.items.isEmpty) return const _EmptyBills();
          return ListView(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 96 + MediaQuery.of(context).padding.bottom),
            children: [
              _SummaryCard(overview: overview),
              if (overview.needsAttention.isNotEmpty) ...[
                const SizedBox(height: 20),
                _SectionLabel(l10n.needsAttention),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    child: Column(
                      children: [for (final due in overview.needsAttention) BillDueTile(due: due)],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              _SectionLabel(l10n.allBills),
              for (final item in overview.items) ...[
                _BillTile(item: item),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: context.textSecondary,
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final BillsOverview overview;
  const _SummaryCard({required this.overview});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final committed = overview.committedThisCycle;

    Widget metric(String label, String value, {Key? key}) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: context.textSecondary)),
              const SizedBox(height: 4),
              Text(
                value,
                key: key,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                ),
              ),
            ],
          ),
        );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                metric(l10n.monthlyBills, overview.monthlyExpenseTotal.toFormattedString(),
                    key: const ValueKey('bills_monthly_total')),
                metric(l10n.dueThisCycle, committed.toFormattedString(),
                    key: const ValueKey('bills_committed_total')),
              ],
            ),
            if (committed.inMinorUnits > 0) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, size: 16, color: context.accentColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.billsSetAsideNote(committed.toFormattedString()),
                      style: TextStyle(fontSize: 12, color: context.textSecondary, height: 1.4),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BillTile extends StatelessWidget {
  final BillListItem item;
  const _BillTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final bill = item.bill;
    final l10n = context.l10n;
    final category = bill.categoryName == null ? null : l10n.localizedCategoryName(bill.categoryName);
    final nextDue = item.nextDue;
    final muted = !bill.isActive;

    return Card(
      key: ValueKey('bill_tile_${bill.id}'),
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: bill.isIncome ? context.incomeLightColor : context.primaryLightColor,
          child: Icon(
            bill.isIncome ? Icons.south_west_rounded : Icons.receipt_long_rounded,
            color: bill.isIncome ? context.incomeColor : context.accentColor,
          ),
        ),
        title: Text(
          bill.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: muted ? context.textTertiary : context.textPrimary,
          ),
        ),
        subtitle: Text(
          [
            billFrequencyText(context, bill.frequency),
            ?category,
            if (muted) l10n.billPaused else if (nextDue != null) l10n.nextDueOn(billDateText(nextDue)),
          ].join(' · '),
          maxLines: 2,
          style: TextStyle(fontSize: 12, color: context.textSecondary),
        ),
        // Shrink large amounts instead of cutting digits off.
        trailing: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.32),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerEnd,
            child: Text(
              billAmountText(context, bill),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: muted
                    ? context.textTertiary
                    : (bill.isIncome ? context.incomeColor : context.textPrimary),
              ),
            ),
          ),
        ),
        onTap: () => _BillDetailsSheet.show(context, item),
      ),
    );
  }
}

class _BillDetailsSheet extends ConsumerWidget {
  final BillListItem item;

  /// The screen that opened the sheet, used once the sheet is closed.
  final BuildContext parentContext;
  const _BillDetailsSheet({required this.item, required this.parentContext});

  static Future<void> show(BuildContext context, BillListItem item) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _BillDetailsSheet(item: item, parentContext: context),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final bill = item.bill;
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteBillTitle(bill.title)),
        content: Text(l10n.deleteBillBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          TextButton(
            key: const ValueKey('bill_delete_confirm'),
            style: TextButton.styleFrom(foregroundColor: ctx.overspentColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(billServiceProvider).delete(bill);
    HapticFeedback.lightImpact();
    ref.read(refreshTriggerProvider.notifier).trigger();
    if (context.mounted) Navigator.pop(context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(l10n.billDeletedNotice(bill.title))));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bill = item.bill;
    final l10n = context.l10n;
    final historyAsync = ref.watch(billHistoryProvider(bill.id));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            bill.title,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: context.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            [
              billAmountText(context, bill),
              billFrequencyText(context, bill.frequency),
              if (bill.categoryName != null) l10n.localizedCategoryName(bill.categoryName),
            ].join(' · '),
            style: TextStyle(fontSize: 13, color: context.textSecondary),
          ),
          if (bill.isActive && item.nextDue != null) ...[
            const SizedBox(height: 2),
            Text(
              '${l10n.nextDueOn(billDateText(item.nextDue!))} · ${l10n.reminderOption(bill.remindDaysBefore)}',
              style: TextStyle(fontSize: 13, color: context.textSecondary),
            ),
          ],
          if (bill.note != null) ...[
            const SizedBox(height: 8),
            Text(bill.note!, style: TextStyle(fontSize: 13, color: context.textPrimary)),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('bill_edit_button'),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(l10n.edit),
                onPressed: () {
                  Navigator.pop(context);
                  showBillForm(parentContext, bill: bill, nextDue: item.nextDue);
                },
              ),
              OutlinedButton.icon(
                key: const ValueKey('bill_pause_button'),
                icon: Icon(bill.isActive ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 18),
                label: Text(bill.isActive ? l10n.pauseBill : l10n.resumeBill),
                onPressed: () async {
                  await ref.read(billServiceProvider).setActive(bill, !bill.isActive);
                  ref.read(refreshTriggerProvider.notifier).trigger();
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              OutlinedButton.icon(
                key: const ValueKey('bill_delete_button'),
                style: OutlinedButton.styleFrom(foregroundColor: context.overspentColor),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: Text(l10n.delete),
                onPressed: () => _confirmDelete(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            l10n.billHistory,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.textPrimary),
          ),
          const SizedBox(height: 4),
          historyAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('${l10n.error}: $e'),
            data: (history) {
              if (history.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(l10n.billNoHistory, style: TextStyle(fontSize: 13, color: context.textSecondary)),
                );
              }
              return Column(
                children: [
                  for (final o in history.take(12))
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        o.status == BillOccurrenceStatus.paid
                            ? Icons.check_circle_rounded
                            : Icons.redo_rounded,
                        size: 20,
                        color: o.status == BillOccurrenceStatus.paid
                            ? context.incomeColor
                            : context.textTertiary,
                      ),
                      title: Text(billDateText(o.dueDate)),
                      trailing: Text(
                        o.status == BillOccurrenceStatus.paid
                            ? (o.amount?.toFormattedString() ?? '')
                            : l10n.billSkipped,
                        style: TextStyle(fontWeight: FontWeight.w600, color: context.textSecondary),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EmptyBills extends StatelessWidget {
  const _EmptyBills();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 48, color: context.textTertiary),
            const SizedBox(height: 16),
            Text(
              l10n.noBillsYet,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.billsEmptyDescription,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const ValueKey('bills_add_first'),
              style: FilledButton.styleFrom(
                backgroundColor: context.primaryColor,
                foregroundColor: context.onPrimaryColor,
              ),
              onPressed: () => showBillForm(context),
              icon: const Icon(Icons.add),
              label: Text(l10n.addFirstBill),
            ),
          ],
        ),
      ),
    );
  }
}
