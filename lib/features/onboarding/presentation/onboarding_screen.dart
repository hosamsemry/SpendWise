import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/core/providers/cycle_providers.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/features/categories/domain/category.dart';

class OnboardingCategoryItem {
  final String name;
  final String? icon;
  final String? color;
  Money defaultBudget;
  bool isSelected;

  OnboardingCategoryItem({
    required this.name,
    this.icon,
    this.color,
    this.defaultBudget = const Money.zero(),
    this.isSelected = true,
  });
}

class OnboardingScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late List<OnboardingCategoryItem> _items;
  bool _isSaving = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final isAr = context.l10n.isArabic;
      _items = [
        OnboardingCategoryItem(
          name: isAr ? 'طعام وبقالة' : 'Food & Groceries',
          defaultBudget: const Money.fromMinorUnits(200000), // 2,000 EGP
        ),
        OnboardingCategoryItem(
          name: isAr ? 'مواصلات' : 'Transportation',
          defaultBudget: const Money.fromMinorUnits(100000), // 1,000 EGP
        ),
        OnboardingCategoryItem(
          name: isAr ? 'حياة اجتماعية ومطاعم' : 'Social & Dining',
          defaultBudget: const Money.fromMinorUnits(50000), // 500 EGP
        ),
        OnboardingCategoryItem(
          name: isAr ? 'رياضة ولياقة' : 'Gym & Fitness',
          defaultBudget: const Money.fromMinorUnits(100000), // 1,000 EGP
        ),
        OnboardingCategoryItem(
          name: isAr ? 'مدخرات' : 'Savings',
          defaultBudget: const Money.fromMinorUnits(300000), // 3,000 EGP
        ),
        OnboardingCategoryItem(
          name: isAr ? 'استثمارات' : 'Investments',
          defaultBudget: const Money.fromMinorUnits(200000), // 2,000 EGP
        ),
      ];
    }
  }

  void _showAddCategoryDialog() {
    final nameController = TextEditingController();
    final budgetController = TextEditingController();
    String? errorMessage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.l10n.addCategory),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: context.l10n.categoryName,
                  hintText: context.l10n.utilitiesHint,
                  errorText: errorMessage,
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: budgetController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: context.l10n.defaultAllocationLabel,
                  hintText: '0.00',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  setDialogState(() => errorMessage = context.l10n.nameIsRequired);
                  return;
                }
                final budgetText = budgetController.text.trim();
                final Money budget;
                if (budgetText.isEmpty) {
                  budget = const Money.zero();
                } else {
                  final p = Money.tryParse(budgetText);
                  if (p == null) {
                    setDialogState(
                      () => errorMessage = context.l10n.enterValidBudgetAmount,
                    );
                    return;
                  }
                  if (p.isNegative) {
                    setDialogState(
                      () => errorMessage = context.l10n.budgetCannotBeNegative,
                    );
                    return;
                  }
                  budget = p;
                }

                setState(() {
                  _items.add(
                    OnboardingCategoryItem(
                      name: name,
                      defaultBudget: budget,
                      isSelected: true,
                    ),
                  );
                });
                Navigator.pop(ctx);
              },
              child: Text(context.l10n.add),
            ),
          ],
        ),
      ),
    );
  }

  void _editCategoryBudget(int index) {
    final item = _items[index];
    final controller = TextEditingController(
      text: item.defaultBudget.inMinorUnits == 0
          ? ''
          : item.defaultBudget.toFormattedString(includeCurrency: false),
    );
    String? errorMessage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            context.l10n.defaultBudgetForCategory(
              context.l10n.localizedCategoryName(item.name),
            ),
          ),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: context.l10n.defaultAllocationLabel,
              hintText: '0.00',
              errorText: errorMessage,
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.trim();
                final Money parsed;
                if (text.isEmpty) {
                  parsed = const Money.zero();
                } else {
                  final p = Money.tryParse(text);
                  if (p == null) {
                    setDialogState(
                      () => errorMessage = context.l10n.enterValidAmount,
                    );
                    return;
                  }
                  if (p.isNegative) {
                    setDialogState(
                      () => errorMessage = context.l10n.budgetCannotBeNegative,
                    );
                    return;
                  }
                  parsed = p;
                }

                setState(() {
                  item.defaultBudget = parsed;
                });
                Navigator.pop(ctx);
              },
              child: Text(context.l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _completeSetup() async {
    final selectedItems = _items.where((i) => i.isSelected).toList();
    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.selectAtLeastOneCategory),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final db = ref.read(appDatabaseProvider);
      final categoryRepo = ref.read(categoryRepositoryProvider);
      final cycleRepo = ref.read(budgetCycleRepositoryProvider);
      final notificationService = ref.read(notificationServiceProvider);

      // 1. Create categories and initialize current cycle in a single atomic transaction
      await db.transaction(() async {
        for (final item in selectedItems) {
          await categoryRepo.createCategory(
            name: item.name,
            type: CategoryType.expense,
            defaultBudget: item.defaultBudget,
            icon: item.icon,
            color: item.color,
          );
        }

        // Seed default income categories
        final defaultIncome = [
          'Salary',
          'Freelance / Side Gig',
          'Investments / Dividends',
          'Gifts & Bonus',
          'Other Income',
        ];
        for (final incomeName in defaultIncome) {
          await categoryRepo.createCategory(
            name: incomeName,
            type: CategoryType.income,
          );
        }

        await cycleRepo.getOrCreateCycleForDate(DateTime.now());
      });

      // 2. Setup notifications & request permission
      await notificationService.initialize();
      await notificationService.requestPermission();
      await notificationService.scheduleNext25thReminder(DateTime.now());

      // 3. Trigger state refresh and complete
      ref.read(refreshTriggerProvider.notifier).trigger();
      widget.onComplete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${context.l10n.failedToCompleteSetupMsg}: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.welcomeTitle)),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.setUpYourCategories,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.onboardingCategoryDescription,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: Checkbox(
                        value: item.isSelected,
                        activeColor: AppColors.primary,
                        onChanged: (val) {
                          setState(() {
                            item.isSelected = val ?? false;
                          });
                        },
                      ),
                      title: Text(
                        context.l10n.localizedCategoryName(item.name),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${context.l10n.budget}: ${item.defaultBudget.toFormattedString(currencySymbol: context.l10n.currencySymbol)}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () => _editCategoryBudget(index),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  OutlinedButton.icon(
                    onPressed: _showAddCategoryDialog,
                    icon: const Icon(Icons.add),
                    label: Text(context.l10n.addCustomCategory),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _completeSetup,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            context.l10n.startBudgeting,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
