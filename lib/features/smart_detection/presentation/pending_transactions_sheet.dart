import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/core/providers/cycle_providers.dart';
import 'package:money_tracker/features/categories/domain/category.dart';
import 'package:money_tracker/features/smart_detection/domain/pending_detected_transaction.dart';
import 'package:money_tracker/features/smart_detection/presentation/smart_detection_providers.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';

/// Opens a modal bottom sheet where users review, categorize, confirm, or dismiss
/// detected bank & wallet notifications before they enter the ledger.
class PendingTransactionsSheet extends ConsumerWidget {
  const PendingTransactionsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PendingTransactionsSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingTransactionsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: context.isDark
                ? context.accentColor.withValues(alpha: 0.4)
                : context.borderColor,
            width: 1.4,
          ),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: context.textTertiary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.detectedTransactionsSheetTitle,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                ),
              ),
              pendingAsync.maybeWhen(
                data: (items) => items.length > 1
                    ? TextButton(
                        onPressed: () async {
                          await ref
                              .read(pendingTransactionRepositoryProvider)
                              .clearAllPendingTransactions();
                          ref.read(refreshTriggerProvider.notifier).trigger();
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: Text(
                          context.l10n.clearAll,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: context.overspentColor,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
                orElse: () => const SizedBox.shrink(),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: pendingAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('${context.l10n.error}: $e'),
              data: (items) {
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        context.l10n.noTransactionsFound,
                        style: TextStyle(color: context.textSecondary),
                      ),
                    ),
                  );
                }

                final categories =
                    categoriesAsync.asData?.value ?? const <Category>[];

                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (ctx, index) {
                    final item = items[index];
                    return _PendingItemCard(
                      key: ValueKey('pending_card_${item.id}'),
                      item: item,
                      allCategories: categories,
                      onConfirmed: () {
                        if (items.length == 1 && context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                      onDismissed: () {
                        if (items.length == 1 && context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingItemCard extends ConsumerStatefulWidget {
  final PendingDetectedTransaction item;
  final List<Category> allCategories;
  final VoidCallback onConfirmed;
  final VoidCallback onDismissed;

  const _PendingItemCard({
    super.key,
    required this.item,
    required this.allCategories,
    required this.onConfirmed,
    required this.onDismissed,
  });

  @override
  ConsumerState<_PendingItemCard> createState() => _PendingItemCardState();
}

class _PendingItemCardState extends ConsumerState<_PendingItemCard> {
  late TransactionType _type;
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  String? _selectedCategoryId;
  String? _categoryError;
  String? _amountError;
  bool _showRawMessage = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _type = widget.item.type;
    _amountController = TextEditingController(
      text: widget.item.amount.toFormattedString(includeCurrency: false),
    );
    _noteController = TextEditingController(text: widget.item.note);
    _selectedCategoryId = widget.item.suggestedCategoryId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_isSaving) return;

    final parsedAmount = Money.tryParse(_amountController.text);
    if (parsedAmount == null || parsedAmount.inMinorUnits <= 0) {
      setState(() => _amountError = context.l10n.enterValidAmount);
      return;
    }

    if (_type == TransactionType.expense && _selectedCategoryId == null) {
      setState(() => _categoryError = context.l10n.selectCategoryHint);
      return;
    }

    setState(() {
      _isSaving = true;
      _amountError = null;
      _categoryError = null;
    });

    try {
      await ref.read(smartDetectionCoordinatorProvider).confirmPending(
        pending: widget.item,
        type: _type,
        amount: parsedAmount,
        categoryId: _selectedCategoryId,
        date: widget.item.transactionDate,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.transactionConfirmedNotice)),
        );
        widget.onConfirmed();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.failedToSave(e.toString()))),
        );
      }
    }
  }

  Future<void> _dismiss() async {
    HapticFeedback.lightImpact();
    await ref
        .read(pendingTransactionRepositoryProvider)
        .dismissPendingTransaction(widget.item);
    ref.read(refreshTriggerProvider.notifier).trigger();
    if (mounted) widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) {
    final matchingCategories = widget.allCategories.where((c) {
      return _type == TransactionType.expense
          ? c.type.isExpense
          : c.type.isIncome;
    }).toList();

    final effectiveSelectedId = matchingCategories.any(
      (c) => c.id == _selectedCategoryId,
    )
        ? _selectedCategoryId
        : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surfaceVariantColor.withValues(
          alpha: context.isDark ? 0.55 : 0.45,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SegmentedButton<TransactionType>(
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                segments: [
                  ButtonSegment(
                    value: TransactionType.expense,
                    label: Text(
                      context.l10n.expense,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  ButtonSegment(
                    value: TransactionType.income,
                    label: Text(
                      context.l10n.income,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (set) {
                  setState(() {
                    _type = set.first;
                    _selectedCategoryId = null;
                    _categoryError = null;
                  });
                },
              ),
              const Spacer(),
              Text(
                DateFormat('d MMM • HH:mm').format(widget.item.transactionDate),
                style: TextStyle(
                  fontSize: 11.5,
                  color: context.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: context.l10n.amountLabel,
                    isDense: true,
                    errorText: _amountError,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _noteController,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: context.l10n.noteOptional,
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _type == TransactionType.expense
                ? context.l10n.categoryLabelRequired
                : context.l10n.categoryLabelOptional,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _categoryError != null
                  ? context.overspentColor
                  : context.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: matchingCategories.map((cat) {
              final selected = effectiveSelectedId == cat.id;
              return ChoiceChip(
                key: ValueKey('pending_cat_${widget.item.id}_${cat.id}'),
                label: Text(
                  context.l10n.localizedCategoryName(cat.name),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    color: selected
                        ? context.primaryColor
                        : context.textPrimary,
                  ),
                ),
                selected: selected,
                selectedColor: context.primaryColor.withValues(alpha: 0.16),
                checkmarkColor: context.primaryColor,
                visualDensity: VisualDensity.compact,
                onSelected: (isSelected) {
                  setState(() {
                    _selectedCategoryId = isSelected ? cat.id : null;
                    _categoryError = null;
                  });
                },
              );
            }).toList(),
          ),
          if (_categoryError != null) ...[
            const SizedBox(height: 4),
            Text(
              _categoryError!,
              style: TextStyle(fontSize: 11.5, color: context.overspentColor),
            ),
          ],
          const SizedBox(height: 8),
          InkWell(
            onTap: () => setState(() => _showRawMessage = !_showRawMessage),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    _showRawMessage
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 16,
                    color: context.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    context.l10n.viewOriginalMessage,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: context.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_showRawMessage)
            Container(
              margin: const EdgeInsets.only(top: 4, bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.borderColor),
              ),
              child: Text(
                widget.item.rawMessage,
                style: TextStyle(
                  fontSize: 11.5,
                  color: context.textSecondary,
                  height: 1.35,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton(
                key: ValueKey('pending_dismiss_${widget.item.id}'),
                onPressed: _isSaving ? null : _dismiss,
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.textSecondary,
                  side: BorderSide(color: context.borderColor),
                ),
                child: Text(context.l10n.dismiss),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  key: ValueKey('pending_confirm_${widget.item.id}'),
                  onPressed: _isSaving ? null : _confirm,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: Text(context.l10n.confirmTransactionButton),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.primaryColor,
                    foregroundColor: context.onPrimaryColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

