import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/core/providers/cycle_providers.dart';
import 'package:money_tracker/core/providers/preset_providers.dart';
import 'package:money_tracker/features/presets/domain/transaction_preset.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';

class PresetsManagementScreen extends ConsumerStatefulWidget {
  const PresetsManagementScreen({super.key});

  @override
  ConsumerState<PresetsManagementScreen> createState() =>
      _PresetsManagementScreenState();
}

class _PresetsManagementScreenState
    extends ConsumerState<PresetsManagementScreen> {
  void _showAddEditPresetDialog([TransactionPreset? preset]) {
    final titleController = TextEditingController(text: preset?.title ?? '');
    final amountController = TextEditingController(
      text: preset != null
          ? preset.amount.toFormattedString(includeCurrency: false)
          : '',
    );
    final noteController = TextEditingController(text: preset?.note ?? '');
    TransactionType type = preset?.type ?? TransactionType.expense;
    String? selectedCategoryId = preset?.categoryId;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final categoriesAsync = ref.watch(categoriesProvider);

          return AlertDialog(
            title: Text(preset != null ? context.l10n.editQuickPreset : context.l10n.newQuickPreset),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<TransactionType>(
                    segments: [
                      ButtonSegment(
                        value: TransactionType.expense,
                        label: Text(context.l10n.expense),
                        icon: Icon(Icons.arrow_upward, size: 16),
                      ),
                      ButtonSegment(
                        value: TransactionType.income,
                        label: Text(context.l10n.income),
                        icon: Icon(Icons.arrow_downward, size: 16),
                      ),
                    ],
                    selected: {type},
                    onSelectionChanged: (set) {
                      setDialogState(() {
                        type = set.first;
                        selectedCategoryId = null;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: context.l10n.presetTitleLabel,
                      hintText: context.l10n.presetTitleHint,
                      errorText: errorMessage,
                    ),
                    autofocus: preset == null,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: context.l10n.amountLabelWithCurrency,
                      prefixText: '${context.l10n.currencySymbol} ',
                    ),
                  ),
                  const SizedBox(height: 16),
                  categoriesAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('${context.l10n.error}: $e'),
                    data: (cats) {
                      final filtered = cats
                          .where(
                            (c) => type == TransactionType.expense
                                ? c.type.isExpense
                                : c.type.isIncome,
                          )
                          .toList();

                      return DropdownButtonFormField<String?>(
                        initialValue: selectedCategoryId,
                        decoration: InputDecoration(
                          labelText: context.l10n.categoryLabelOptional,
                        ),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text(context.l10n.noCategory),
                          ),
                          ...filtered.map(
                            (c) => DropdownMenuItem<String?>(
                              value: c.id,
                              child: Text(context.l10n.localizedCategoryName(c.name)),
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          setDialogState(() => selectedCategoryId = val);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: noteController,
                    decoration: InputDecoration(
                      labelText: context.l10n.defaultNoteOptional,
                      hintText: context.l10n.dailyCommuteHint,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.l10n.cancel),
              ),
              ElevatedButton(
                onPressed: () async {
                  final title = titleController.text.trim();
                  if (title.isEmpty) {
                    setDialogState(() => errorMessage = context.l10n.titleRequired);
                    return;
                  }
                  final amount = Money.tryParse(amountController.text.trim());
                  if (amount == null || amount.inMinorUnits <= 0) {
                    setDialogState(
                      () =>
                          errorMessage = context.l10n.enterAmountGreaterThanZero,
                    );
                    return;
                  }

                  final repo = ref.read(presetRepositoryProvider);
                  try {
                    if (preset == null) {
                      await repo.createPreset(
                        title: title,
                        type: type,
                        categoryId: selectedCategoryId,
                        amount: amount,
                        note: noteController.text,
                      );
                    } else {
                      await repo.updatePreset(
                        id: preset.id,
                        title: title,
                        type: type,
                        categoryId: selectedCategoryId,
                        amount: amount,
                        note: noteController.text,
                      );
                    }
                    ref.read(refreshTriggerProvider.notifier).trigger();
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    setDialogState(() => errorMessage = context.l10n.failedToSave(e.toString()));
                  }
                },
                child: Text(preset != null ? context.l10n.update : context.l10n.save),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deletePresetWithUndo(TransactionPreset preset) async {
    HapticFeedback.lightImpact();
    final repo = ref.read(presetRepositoryProvider);
    await repo.deletePreset(preset.id);
    ref.read(refreshTriggerProvider.notifier).trigger();

    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.deletedPresetNotice(preset.title)),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: context.l10n.undo,
          textColor: Colors.amber,
          onPressed: () async {
            HapticFeedback.lightImpact();
            await repo.createPreset(
              title: preset.title,
              type: preset.type,
              amount: preset.amount,
              categoryId: preset.categoryId,
            );
            ref.read(refreshTriggerProvider.notifier).trigger();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final presetsAsync = ref.watch(allPresetsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.quickTransactionPresets)),
      floatingActionButton: FloatingActionButton(
        heroTag: 'presets_add_fab',
        tooltip: context.l10n.addPresetTooltip,
        onPressed: () => _showAddEditPresetDialog(),
        child: const Icon(Icons.add),
      ),
      body: presetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${context.l10n.error}: $e')),
        data: (presets) {
          if (presets.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.flash_on_outlined,
                      size: 48,
                      color: isDark
                          ? AppColorsDark.textTertiary
                          : AppColors.textTertiary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.noPresetsCreatedYet,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.presetsDescription,
                      style: TextStyle(
                        color: isDark
                            ? AppColorsDark.textSecondary
                            : AppColors.textSecondary,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _showAddEditPresetDialog(),
                      icon: const Icon(Icons.add),
                      label: Text(context.l10n.createFirstPreset),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              80 + MediaQuery.of(context).padding.bottom,
            ),
            itemCount: presets.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final p = presets[index];
              final isIncome = p.type == TransactionType.income;

              return Dismissible(
                key: ValueKey('preset_${p.id}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: isDark ? AppColorsDark.overspent : AppColors.overspent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.delete_outline, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        context.l10n.delete,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                onDismissed: (_) => _deletePresetWithUndo(p),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: isIncome
                          ? (isDark
                                ? AppColorsDark.incomeLight
                                : AppColors.incomeLight)
                          : (isDark
                                ? AppColorsDark.primaryLight
                                : AppColors.primaryLight),
                      child: Icon(
                        isIncome
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded,
                        color: isIncome
                            ? (isDark ? AppColorsDark.income : AppColors.income)
                            : (isDark
                                  ? AppColorsDark.primary
                                  : AppColors.primary),
                      ),
                    ),
                    title: Text(
                      p.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${(p.categoryName != null && p.categoryName!.isNotEmpty) ? context.l10n.localizedCategoryName(p.categoryName) : (isIncome ? context.l10n.income : context.l10n.expense)} • ${p.amount.toFormattedString()}',
                      style: TextStyle(
                        color: isDark
                            ? AppColorsDark.textSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          tooltip: context.l10n.edit,
                          onPressed: () => _showAddEditPresetDialog(p),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: isDark
                                ? AppColorsDark.overspent
                                : AppColors.overspent,
                          ),
                          tooltip: context.l10n.delete,
                          onPressed: () => _deletePresetWithUndo(p),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
