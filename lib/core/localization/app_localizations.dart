import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:money_tracker/core/money/money.dart';

/// Centralized localization dictionary for SpendWise supporting English ('en') and Arabic ('ar').
class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('en'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  bool get isArabic => locale.languageCode == 'ar';

  // --- General & App ---
  String get appName => isArabic ? 'سبيند وايز' : 'SpendWise';
  String get currencySymbol => isArabic ? 'ج.م' : 'EGP';
  String get cancel => isArabic ? 'إلغاء' : 'Cancel';
  String get save => isArabic ? 'حفظ' : 'Save';
  String get delete => isArabic ? 'حذف' : 'Delete';
  String get edit => isArabic ? 'تعديل' : 'Edit';
  String get update => isArabic ? 'تحديث' : 'Update';
  String get create => isArabic ? 'إنشاء' : 'Create';
  String get confirm => isArabic ? 'تأكيد' : 'Confirm';
  String get confirmAndContinue => isArabic ? 'تأكيد ومتابعة' : 'Confirm & Continue';
  String get undo => isArabic ? 'تراجع' : 'Undo';
  String get dismiss => isArabic ? 'تجاهل' : 'Dismiss';
  String get manage => isArabic ? 'إدارة' : 'Manage';
  String get summary => isArabic ? 'الملخص' : 'Summary';
  String get viewAll => isArabic ? 'عرض الكل' : 'View All';
  String get newLabel => isArabic ? 'جديد' : 'New';
  String get reset => isArabic ? 'إعادة ضبط' : 'Reset';
  String get recorded => isArabic ? 'المسجل' : 'Recorded';
  String get error => isArabic ? 'خطأ' : 'Error';
  String get today => isArabic ? 'اليوم' : 'Today';
  String get yesterday => isArabic ? 'أمس' : 'Yesterday';
  String get uncategorized => isArabic ? 'غير مصنف' : 'Uncategorized';
  String get all => isArabic ? 'الكل' : 'All';
  String get expenses => isArabic ? 'المصروفات' : 'Expenses';
  String get income => isArabic ? 'الدخل' : 'Income';
  String get expense => isArabic ? 'مصروف' : 'Expense';
  String get cycleLabel => isArabic ? 'الدورة:' : 'Cycle:';
  String get allCategories => isArabic ? 'كل الفئات' : 'All Categories';
  String get noCategoriesYet => isArabic ? 'لم يتم إنشاء فئات بعد.' : 'No categories created yet.';
  String get noTransactionsYet => isArabic ? 'لا توجد معاملات مسجلة حتى الآن.' : 'No transactions yet.';
  String get filterOptions => isArabic ? 'خيارات التصفية' : 'Filter Options';
  String get closeSearch => isArabic ? 'إغلاق البحث' : 'Close Search';
  String get searchNotes => isArabic ? 'بحث في الملاحظات' : 'Search Notes';
  String get dateRange => isArabic ? 'نطاق التاريخ' : 'Date Range';
  String get filtersCleared => isArabic ? 'تم مسح الفلاتر' : 'Filters cleared';
  String spentPrefix(String amt) => isArabic ? 'المصروف: $amt' : 'Spent: $amt';
  String incomePrefix(String amt) => isArabic ? 'الدخل: $amt' : 'Income: $amt';

  // --- Navigation Tabs ---
  String get navDashboard => isArabic ? 'الرئيسية' : 'Dashboard';
  String get navTransactions => isArabic ? 'المعاملات' : 'Transactions';
  String get navBudgets => isArabic ? 'الميزانيات' : 'Budgets';
  String get navSettings => isArabic ? 'الإعدادات' : 'Settings';

  // --- Language Selection Onboarding ---
  String get welcomeTitle => isArabic ? 'مرحباً بك في سبيند وايز' : 'Welcome to SpendWise';
  String get welcomeSubtitle => isArabic
      ? 'اختر لغتك المفضلة للمتابعة'
      : 'Choose your preferred language to continue';
  String get englishLanguage => 'English';
  String get arabicLanguage => 'عربي';
  String get languageSelectInstruction => isArabic
      ? 'يمكنك تغيير اللغة في أي وقت من الإعدادات'
      : 'You can change the language anytime in Settings';

  // --- Initial Cycle Setup ---
  String get setupCycleTitle => isArabic ? 'تحديد دورة الميزانية' : 'Determine Budget Cycle';
  String get setupCycleDescription => isArabic
      ? 'حدد أيام بداية ونهاية دورة ميزانيتك الشهرية لبدء متابعة أموالك.'
      : 'Determine your monthly budget cycle start and end days to begin tracking your finances.';
  String get calendarMonth => isArabic ? 'شهر تقويمي' : 'Calendar Month';
  String get calendarMonthSubtitle => isArabic
      ? 'تبدأ الميزانية من يوم 1 إلى آخر يوم في الشهر'
      : 'Runs from the 1st to the last day of each month';
  String get customPaydayCycle => isArabic ? 'دورة الراتب المخصصة' : 'Custom Payday Cycle';
  String get customPaydayCycleSubtitle => isArabic
      ? 'تبدأ في يوم استلام راتبك وتستمر حتى اليوم السابق للراتب التالي'
      : 'Starts on your payday and ends the day before next payday';
  String get cycleStartDayLabel => isArabic ? 'يوم بدء الدورة الشهرية' : 'Monthly Cycle Start Day';
  String cycleSummaryPreview(int day, int endDay) => isArabic
      ? 'الدورة: من يوم $day حتى يوم $endDay من الشهر التالي'
      : 'Cycle: Day $day to Day $endDay of following month';

  // --- Dashboard Screen ---
  String get currentBudgetCycle => isArabic ? 'دورة الميزانية الحالية' : 'CURRENT BUDGET CYCLE';
  String get totalBudget => isArabic ? 'إجمالي الميزانية' : 'Total Budget';
  String get spent => isArabic ? 'المصروف' : 'Spent';
  String get remaining => isArabic ? 'المتبقي' : 'Remaining';
  String get remainingBudget => isArabic ? 'الميزانية المتبقية' : 'REMAINING BUDGET';
  String ofTotal(String total) => isArabic ? 'من $total' : 'of $total';
  String get safeDailySpend => isArabic ? 'الإنفاق اليومي الآمن' : 'Safe Daily Spend';
  String get safeDailySpendSubtitle => isArabic
      ? 'المعدل الموصى به يومياً للحفاظ على الميزانية'
      : 'Recommended daily pace to stay on budget';
  String overDailyPaceBadge(String amt) => isArabic ? '⚠️ تجاوز الوتيرة (+$amt)' : '⚠️ Over pace (+$amt)';
  String safeDailyPaceBadge(String amt) => isArabic ? 'آمن: ~$amt/يوم' : 'Safe: ~$amt/d';
  String get onTrack => isArabic ? 'على المسار الصحيح' : 'On Track';
  String get pacingFast => isArabic ? 'وتيرة إنفاق سريعة' : 'Pacing Fast';
  String get overBudget => isArabic ? 'تجاوزت الميزانية' : 'Over Budget';
  String get todaysSpending => isArabic ? 'إنفاق اليوم' : "TODAY'S SPENDING";
  String get cycleSpent => isArabic ? 'مصروف الدورة' : 'CYCLE SPENT';
  String get overDailyPace => isArabic ? 'تجاوز الوتيرة اليومية' : 'Over daily pace';
  String safeLeft(String amt) => isArabic ? 'المتبقي الآمن $amt' : '$amt safe left';
  String expensesCount(int count) => isArabic
      ? (count == 0 ? 'لا توجد مصروفات' : (count == 1 ? 'مصروف واحد' : '$count مصروفات'))
      : (count == 0 ? '0 expenses' : (count == 1 ? '1 expense' : '$count expenses'));
  String categoriesCount(int count) => isArabic
      ? (count == 1 ? 'فئة واحدة' : '$count فئات')
      : (count == 1 ? '1 category' : '$count categories');
  String get noSpendingToday => isArabic ? 'لا يوجد إنفاق اليوم حتى الآن' : 'No expenses logged today';
  String get categoryBudgets => isArabic ? 'ميزانيات الفئات' : 'CATEGORY BUDGETS';
  String get recentTransactions => isArabic ? 'أحدث المعاملات' : 'Recent Transactions';
  String get quickPresets => isArabic ? 'المعاملات السريعة' : 'QUICK PRESETS';
  String overspentAlert(int count) => isArabic
      ? (count == 1
          ? 'فئة واحدة تجاوزت الميزانية! راجع ميزانياتك.'
          : '$count فئات تجاوزت الميزانية! راجع ميزانياتك.')
      : '$count ${count == 1 ? "category is" : "categories are"} over budget! Review your category allocations.';
  String nearLimitAlert(int count) => isArabic
      ? (count == 1
          ? 'فئة واحدة تقترب من حد الميزانية (≥ 80%).'
          : '$count فئات تقترب من حد الميزانية (≥ 80%).')
      : '$count ${count == 1 ? "category is" : "categories are"} approaching budget limit (≥ 80%).';
  String addedPresetNotice(String title, String amount) => isArabic
      ? 'تم تسجيل "$title" ($amount)'
      : 'Added "$title" ($amount)';
  String daysRemaining(int days) => isArabic
      ? (days == 1 ? 'يوم واحد متبقٍ' : '$days أيام متبقية')
      : (days == 1 ? '1 day left' : '$days days left');

  // --- Savings & Lifetime Vault ---
  String get lifetimeSavingsVault => isArabic ? 'خزينة المدخرات الدائمة' : 'Lifetime Savings Vault';
  String get vaultAccumulatedBalance => isArabic
      ? 'إجمالي الفائض المالي المحفوظ عبر الدورات'
      : 'Accumulated surplus saved across all cycles';
  String lastSweptNotice(String amount, String date) => isArabic
      ? 'تم حفظ +$amount في $date'
      : '+$amount swept on $date';
  String get cycleCloseoutTitle => isArabic ? 'اختتام الدورة السابقة بنجاح!' : 'Cycle Closeout: Great Job!';
  String cycleCloseoutMessage(String range, String surplus) => isArabic
      ? 'أنهيت دورة ($range) بفائض قدره $surplus! انقر للتحويل إلى الخزينة.'
      : 'You completed ($range) with a surplus of $surplus! Tap to sweep into your vault.';
  String get sweepToVault => isArabic ? 'تحويل للخزينة' : 'Sweep to Vault';
  String sweptSuccess(String amount) => isArabic
      ? 'تم تحويل $amount إلى خزينة المدخرات!'
      : 'Swept $amount into Savings Vault!';
  String get deposit => isArabic ? 'إيداع' : 'Deposit';
  String get withdraw => isArabic ? 'سحب' : 'Withdraw';
  String get manageSavingsVault => isArabic ? 'إدارة خزينة المدخرات' : 'Manage Savings Vault';
  String get depositDescription => isArabic
      ? 'إضافة مدخرات أو أموال خارجية إلى الخزينة'
      : 'Add external or cash savings directly to the vault';
  String get withdrawDescription => isArabic
      ? 'سحب أموال للطوارئ أو لمصروفات مخطط لها'
      : 'Withdraw funds for emergency expenses or planned goals';
  String get cannotWithdrawOverdraft => isArabic
      ? 'لا يمكنك سحب مبلغ أكبر من رصيد الخزينة الحالي'
      : 'Cannot withdraw more than available vault balance';
  String get autoBalancedBadge => isArabic ? 'موازنة تلقائية' : 'Auto-balanced';
  String get savingsCategoryName => isArabic ? 'مدخرات' : 'Savings';

  // --- Transactions Screen ---
  String get searchNotesHint => isArabic ? 'بحث في الملاحظات...' : 'Search notes...';
  String get noTransactionsFound => isArabic ? 'لا توجد معاملات مسجلة لهذه الدورة.' : 'No transactions found for this cycle.';
  String get addTransaction => isArabic ? 'إضافة معاملة' : 'Add Transaction';
  String get editTransaction => isArabic ? 'تعديل المعاملة' : 'Edit Transaction';
  String get amountLabel => isArabic ? 'المبلغ' : 'Amount';
  String get amountLabelWithCurrency => isArabic ? 'المبلغ (ج.م)' : 'Amount (EGP)';
  String get amountHint => isArabic ? '0.00 أو معادلة مثل 50+20*2' : '0.00 or math like 50+20*2';
  String get mathPreview => isArabic ? 'الناتج:' : 'Evaluates to:';
  String get categoryLabelRequired => isArabic ? 'الفئة (مطلوبة)' : 'Category (Required)';
  String get categoryLabelOptional => isArabic ? 'الفئة (اختيارية)' : 'Category (Optional)';
  String get transactionDate => isArabic ? 'تاريخ المعاملة' : 'Date';
  String get noteOptional => isArabic ? 'ملاحظة (اختيارية)' : 'Note (Optional)';
  String get noteHint => isArabic ? 'مثال: مشتريات البقالة الأسبوعية' : 'e.g. Weekly family groceries';
  String get updateTransactionButton => isArabic ? 'تحديث المعاملة' : 'Update Transaction';
  String get saveTransactionButton => isArabic ? 'حفظ المعاملة' : 'Save Transaction';
  String get newExpenseCategory => isArabic ? 'فئة مصروفات جديدة' : 'New Expense Category';
  String get newIncomeCategory => isArabic ? 'فئة دخل جديدة' : 'New Income Category';
  String get nameRequired => isArabic ? 'الاسم مطلوب' : 'Name is required';
  String get enterValidAmount => isArabic ? 'أدخل مبلغاً صالحاً' : 'Enter a valid amount';
  String get amountCannotBeNegative => isArabic ? 'لا يمكن أن يكون المبلغ سالباً' : 'Amount cannot be negative';
  String get amountExceedsLimit => isArabic ? 'لا يمكن أن يتجاوز المبلغ 999,999,999 ج.م' : 'Amount cannot exceed 999,999,999 EGP';
  String get enterValidAmountOrExpr => isArabic ? 'أدخل مبلغاً أو معادلة صحيحة (مثال: 45 + 30)' : 'Enter a valid amount or expression (e.g. 45 + 30)';
  String get selectCategoryForExpense => isArabic ? 'يرجى اختيار فئة لهذا المصروف' : 'Please select a category for this expense';
  String deletedTransactionNotice(String name, String amount) => isArabic
      ? 'تم حذف $name ($amount)'
      : 'Deleted $name ($amount)';

  // --- Budgets Screen & Tabs ---
  String get budgetsAndInsights => isArabic ? 'الميزانيات والتقارير' : 'Budgets & Insights';
  String get tabCycleBudgets => isArabic ? 'ميزانية الدورة' : 'Cycle Budgets';
  String get tabCategories => isArabic ? 'إدارة الفئات' : 'Categories';
  String get tabInsights => isArabic ? 'التحليلات' : 'Insights';
  String get budgetCycleLabel => isArabic ? 'دورة الميزانية:' : 'Budget Cycle:';
  String get editBudget => isArabic ? 'تعديل الميزانية' : 'Edit Budget';
  String editBudgetForCategory(String name) => isArabic ? 'تعديل الميزانية: $name' : 'Edit Budget: $name';
  String get budgetedAmount => isArabic ? 'المبلغ المخصص للميزانية' : 'Budgeted Amount';
  String get budgetAmountForCycle => isArabic ? 'مبلغ الميزانية لهذه الدورة (ج.م)' : 'Budget Amount for this Cycle (EGP)';
  String get updateDefaultAllocationForFuture => isArabic
      ? 'تحديث التخصيص الافتراضي للدورات المستقبلية أيضاً'
      : 'Also update default allocation for future cycles';
  String get cycleAppliesUpcomingNote => isArabic
      ? 'هذا المبلغ الجديد سينطبق على هذه الدورة وجميع الدورات المستقبلية.'
      : 'This new amount will apply to this cycle AND all future cycles.';
  String cycleAppliesCurrentOnlyNote(String label) => isArabic
      ? 'هذا التغيير يؤثر فقط على هذه الدورة ($label). الدورات المستقبلية ستستخدم التخصيص الافتراضي.'
      : 'This change affects only this cycle ($label). Future cycles will use your category default.';
  String get noExpenseCategoriesFound => isArabic ? 'لم يتم العثور على فئات مصروفات' : 'No expense categories found';
  String get createCategoriesToTrackDesc => isArabic
      ? 'أنشئ فئات لتتبع إنفاقك مقابل الميزانيات الشهرية.'
      : 'Create categories to track your spending against monthly budgets.';
  String get addAnotherCategory => isArabic ? 'إضافة فئة أخرى' : 'Add Another Category';
  String percentUsed(String pct) => isArabic ? 'تم استهلاك $pct%' : '$pct% used';
  String get noBudgetSet => isArabic ? 'لم تحدد ميزانية (الإنفاق يتجاوز الميزانية)' : 'No budget set (Spending exceeds budget)';
  String get overspent => isArabic ? 'تجاوزت' : 'Overspent';
  String get nearLimit => isArabic ? 'قريب من الحد' : 'Near limit';
  String get addCategory => isArabic ? 'إضافة فئة' : 'Add Category';
  String get addExpenseCategory => isArabic ? 'إضافة فئة مصروفات' : 'Add Expense Category';
  String get addIncomeCategory => isArabic ? 'إضافة فئة دخل' : 'Add Income Category';
  String get categoryNameLabel => isArabic ? 'اسم الفئة' : 'Category Name';
  String get expenseCategoryNameLabel => isArabic ? 'اسم فئة المصروفات' : 'Expense Category Name';
  String get incomeCategoryNameLabel => isArabic ? 'اسم فئة الدخل' : 'Income Category Name';
  String get defaultAllocationLabel => isArabic ? 'التخصيص الافتراضي (ج.م)' : 'Default Allocation (EGP)';
  String get expectedIncomeLabel => isArabic ? 'الدخل المتوقع / الافتراضي (ج.م)' : 'Expected / Default Income (EGP)';
  String get defaultBudgetDesc => isArabic ? 'الميزانية الشهرية الافتراضية للدورات المستقبلية' : 'Default monthly budget for future cycles';
  String get defaultIncomeDesc => isArabic ? 'المبلغ المتوقع افتراضياً (مثل الراتب، اختياري)' : 'Default expected amount (e.g. Salary, optional)';
  String get editingDefaultBudgetNote => isArabic
      ? 'تعديل التخصيص الافتراضي ينطبق على الدورات القادمة. لتعديل ميزانية هذا الشهر، استخدم تبويب ميزانية الدورة.'
      : 'Editing the default allocation applies to upcoming cycles. To modify this month\'s budget, use the Budgets tab.';
  String editCategoryName(String name) => isArabic ? 'تعديل "$name"' : 'Edit "$name"';
  String deleteCategoryName(String name) => isArabic ? 'حذف "$name"؟' : 'Delete "$name"?';
  String get deleteCategoryConfirmTitle => isArabic ? 'حذف هذه الفئة؟' : 'Delete this category?';
  String get deleteCategoryConfirmBody => isArabic
      ? 'هل أنت متأكد من رغبتك في حذف هذه الفئة؟\n\nالمعاملات السابقة ستبقى مسجلة في سجلك المالي مع الاحتفاظ باسم الفئة.'
      : 'Are you sure you want to delete this category?\n\nExisting transactions will remain in your history with the category name preserved.';
  String get tabExpenseCategories => isArabic ? 'فئات المصروفات' : 'Expense Categories';
  String get tabIncomeCategories => isArabic ? 'فئات الدخل' : 'Income Categories';
  String get noExpenseCategories => isArabic ? 'لا توجد فئات مصروفات' : 'No Expense Categories';
  String get noIncomeCategories => isArabic ? 'لا توجد فئات دخل' : 'No Income Categories';
  String get noExpenseCategoriesDesc => isArabic
      ? 'أضف فئات لتخصيص الميزانيات وتتبع مصروفاتك.'
      : 'Add categories to allocate budgets and track your expenses.';
  String get noIncomeCategoriesDesc => isArabic
      ? 'أضف فئات الدخل لتتبع راتبك أو مكافآتك أو عملك الحر.'
      : 'Add income categories to track your salary, bonuses, or freelance income.';
  String get addFirstExpenseCategory => isArabic ? 'إضافة أول فئة مصروفات' : 'Add First Expense Category';
  String get addFirstIncomeCategory => isArabic ? 'إضافة أول فئة دخل' : 'Add First Income Category';
  String defaultBudgetPrefix(String amt) => isArabic ? 'الميزانية الافتراضية: $amt' : 'Default Budget: $amt';
  String expectedIncomePrefix(String amt) => isArabic ? 'الدخل المتوقع: $amt' : 'Expected Income: $amt';
  String get incomeCategorySubtitle => isArabic ? 'فئة دخل' : 'Income Category';

  // --- Cycle Summary Screen ---
  String get cycleSummaryTitle => isArabic ? 'ملخص الدورة' : 'Cycle Summary';
  String get budgetCyclePeriod => isArabic ? 'فترة دورة الميزانية' : 'Budget Cycle Period';
  String get totalIncomeLabel => isArabic ? 'إجمالي الدخل' : 'Total Income';
  String get totalExpensesLabel => isArabic ? 'إجمالي المصروفات' : 'Total Expenses';
  String get totalBudgetedLabel => isArabic ? 'إجمالي الميزانية' : 'Total Budgeted';
  String get overspentCategoriesLabel => isArabic ? 'الفئات المتجاوزة' : 'Overspent Categories';
  String get budgetBalanceAnalysis => isArabic ? 'تحليل رصيد الميزانية' : 'Budget Balance Analysis';
  String get positiveUnusedTotal => isArabic ? 'إجمالي الفائض غير المستغل' : 'Positive Unused Total';
  String get positiveUnusedDesc => isArabic ? 'مجموع الميزانيات المتبقية غير المتجاوزة' : 'Sum of non-overspent remaining budgets';
  String get netRemainingTotalLabel => isArabic ? 'صافي المتبقي الإجمالي' : 'Net Remaining Total';
  String get netRemainingDesc => isArabic ? 'بعد خصم مبالغ التجاوز في الفئات' : 'After deducting category overspending';
  String get perCategoryBreakdown => isArabic ? 'تفصيل الفئات' : 'Per-Category Breakdown';
  String get colCategory => isArabic ? 'الفئة' : 'Category';
  String get colBudget => isArabic ? 'الميزانية' : 'Budget';
  String get colSpent => isArabic ? 'المصروف' : 'Spent';
  String get colRemaining => isArabic ? 'المتبقي' : 'Remaining';

  // --- Presets Management Screen ---
  String get quickTransactionPresets => isArabic ? 'قوالب المعاملات السريعة' : 'Quick Transaction Presets';
  String get noPresetsCreatedYet => isArabic ? 'لم يتم إنشاء قوالب سريعة بعد' : 'No Presets Created Yet';
  String get presetsDescription => isArabic
      ? 'أنشئ اختصارات سريعة بنقرة واحدة للمصروفات المتكررة كالمواصلات والقهوة أو للدخل كالراتب.'
      : 'Create custom 1-tap shortcuts for repetitive expenses or recurring income like Coffee, Metro, or Salary.';
  String get createFirstPreset => isArabic ? 'إنشاء أول قالب سريع' : 'Create First Preset';
  String get addPresetTooltip => isArabic ? 'إضافة قالب سريع' : 'Add Preset';
  String get newQuickPreset => isArabic ? 'قالب سريع جديد' : 'New Quick Preset';
  String get editQuickPreset => isArabic ? 'تعديل القالب السريع' : 'Edit Preset';
  String get presetTitleLabel => isArabic ? 'عنوان القالب' : 'Preset Title';
  String get presetTitleHint => isArabic ? 'مثال: قهوة الصباح، تذكرة المترو' : 'e.g. Morning Espresso, Metro Ticket';
  String get noCategory => isArabic ? 'بدون فئة' : 'No Category';
  String get defaultNoteOptional => isArabic ? 'ملاحظة افتراضية (اختيارية)' : 'Default Note (Optional)';
  String get titleRequired => isArabic ? 'العنوان مطلوب' : 'Title is required';
  String get enterAmountGreaterThanZero => isArabic ? 'أدخل مبلغاً صالحاً أكبر من صفر' : 'Enter a valid amount greater than 0';
  String deletedPresetNotice(String title) => isArabic ? 'تم حذف القالب "$title"' : 'Deleted preset "$title"';

  // --- Reports & Analytics ---
  String get reportsAndAnalysis => isArabic ? 'التقارير والتحليلات' : 'Reports & Analysis';
  String get reportCycleLabel => isArabic ? 'دورة التقرير:' : 'Report Cycle:';
  String get tabCategoryReport => isArabic ? 'الفئات' : 'Category';
  String get tabBudgetVsActualReport => isArabic ? 'الميزانية والفعلي' : 'Budget vs Actual';
  String get tabCycleVsPrevReport => isArabic ? 'مقارنة بالسابقة' : 'Cycle vs Prev';
  String get tabCashFlowTrend => isArabic ? 'التدفق المالي (شهرياً)' : 'Cash Flow (MoM)';
  String get noExpensesRecordedInCycle => isArabic ? 'لا توجد مصروفات مسجلة في هذه الدورة.' : 'No expenses recorded in this cycle.';
  String get totalCycleExpenses => isArabic ? 'إجمالي مصروفات الدورة' : 'Total Cycle Expenses';
  String get expenseBreakdown => isArabic ? 'تفصيل المصروفات' : 'Expense Breakdown';
  String pctOfTotalExpenses(String pct) => isArabic ? '$pct% من إجمالي المصروفات' : '$pct% of total expenses';
  String get totalActualSpent => isArabic ? 'إجمالي المنصرف الفعلي' : 'Total Actual Spent';
  String overAmount(String amt) => isArabic ? '$amt تجاوز' : '$amt Over';
  String underAmount(String amt) => isArabic ? '$amt متبقٍ' : '$amt Under';
  String budgetPrefix(String amt) => isArabic ? 'الميزانية: $amt' : 'Budget: $amt';
  String actualPrefix(String amt) => isArabic ? 'الفعلي: $amt' : 'Actual: $amt';
  String get totalSpendingVariance => isArabic ? 'فارق إجمالي الإنفاق' : 'TOTAL SPENDING VARIANCE';
  String get identical => isArabic ? 'متطابق' : 'Identical';
  String get spendIncreased => isArabic ? 'زاد الإنفاق' : 'Spend increased';
  String get spendDecreased => isArabic ? 'انخفض الإنفاق' : 'Spend decreased';
  String differenceVsLastCycle(String diff) => isArabic ? '$diff مقارنة بالدورة السابقة' : '$diff vs last cycle';
  String comparingCyclesText(String c1, String c2) => isArabic ? 'المقارنة: $c1 مقابل $c2' : 'Comparing: $c1 vs $c2';
  String get spendingIncreasedDesc => isArabic ? 'لقد أنفقت أكثر في هذه الدورة مقارنة بالدورة السابقة.' : 'You have spent more in this cycle compared to the previous cycle.';
  String get spendingDecreasedDesc => isArabic ? 'رائع جداً! لقد خفضت مصروفاتك ووفرت المزيد في هذه الدورة.' : 'Excellent! You reduced expenses and saved more this cycle.';
  String get spendingMatchesDesc => isArabic ? 'الإنفاق مطابق تماماً للدورة السابقة.' : 'Spending matches previous cycle exactly.';
  String get cycleComparisonTitle => isArabic ? 'مقارنة بالدورة السابقة' : 'Cycle-over-Cycle Comparison';
  String spendingPaceComparison(String pct, bool isSlower) => isArabic
      ? (isSlower
          ? 'أنت تنفق بمعدل أبطأ بنسبة $pct مقارنة بنفس اليوم من الدورة السابقة ↘'
          : 'أنت تنفق بمعدل أسرع بنسبة $pct مقارنة بنفس اليوم من الدورة السابقة ↗')
      : (isSlower
          ? 'Spending $pct slower than the previous cycle at this day ↘'
          : 'Spending $pct faster than the previous cycle at this day ↗');
  String get freshInstallNotice => isArabic
      ? 'أكمل دورتك الحالية لتفعيل المقارنات الدقيقة وتحليلات الأداء المالي.'
      : 'Complete your first cycle to unlock comparative velocity and historical trends.';

  // --- Settings Screen ---
  String get settingsTitle => isArabic ? 'الإعدادات' : 'Settings';
  String get sectionLanguage => isArabic ? 'اللغة' : 'LANGUAGE';
  String get currentLanguageLabel => isArabic ? 'لغة التطبيق' : 'App Language';
  String get sectionAppearance => isArabic ? 'المظهر' : 'APPEARANCE';
  String get themeModeLabel => isArabic ? 'وضع السمة' : 'Theme Mode';
  String get themeLight => isArabic ? 'فاتح' : 'Light';
  String get themeDark => isArabic ? 'داكن' : 'Dark';
  String get themeSystem => isArabic ? 'تلقائي (حسب النظام)' : 'System';
  String get sectionSecurity => isArabic ? 'الأمان' : 'SECURITY';
  String get pinLock => isArabic ? 'قفل برمز PIN' : 'PIN Lock';
  String get pinLockSubtitle => isArabic ? 'حماية التطبيق عند المغادرة' : 'Protect SpendWise when paused';
  String get biometricLock => isArabic ? 'بصمة الإصبع / الوجه' : 'Biometric Unlock';
  String get changePin => isArabic ? 'تغيير رمز PIN' : 'Change PIN';
  String get disablePin => isArabic ? 'تعطيل رمز PIN' : 'Disable PIN';
  String get pinEnabledSuccess => isArabic ? 'تم تفعيل قفل PIN بنجاح!' : 'PIN Lock enabled successfully!';
  String get pinDisabledSuccess => isArabic ? 'تم تعطيل قفل PIN.' : 'PIN Lock disabled.';
  String get sectionQuickPresets => isArabic ? 'المعاملات السريعة' : 'QUICK PRESETS';
  String get quickPresetsTileTitle => isArabic ? 'قوالب المعاملات السريعة' : 'Quick Transaction Presets';
  String get quickPresetsTileSubtitle => isArabic ? 'تخصيص قوالب المعاملات بنقرة واحدة في الرئيسية' : 'Customize 1-tap presets displayed on the dashboard';
  String get sectionBudgetCycle => isArabic ? 'دورة الميزانية' : 'BUDGET CYCLE';
  String get cycleStartDay => isArabic ? 'يوم بدء الدورة' : 'Cycle Start Day';
  String get sectionNotifications => isArabic ? 'الإشعارات والتذكيرات' : 'NOTIFICATIONS & REMINDERS';
  String get dailyEveningReminder => isArabic ? 'التذكير المسائي اليومي' : 'Daily Evening Reminder';
  String scheduledForTime(String time) => isArabic ? 'مجدول يومياً في $time' : 'Scheduled for $time daily';
  String get remindMeToLogDaily => isArabic ? 'تذكيري بتسجيل المصروفات اليومية' : 'Remind me to log daily expenses';
  String get reminderTime => isArabic ? 'وقت التذكير' : 'Reminder Time';
  String get notificationPermissionDenied => isArabic ? 'لم يتم منح إذن الإشعارات.' : 'Notification permission was not granted.';
  String get sectionDataManagement => isArabic ? 'إدارة البيانات' : 'DATA MANAGEMENT';
  String get exportTransactionsCsv => isArabic ? 'تصدير كل المعاملات (CSV)' : 'Export All Transactions (CSV)';
  String get exportCycleSummaryCsv => isArabic ? 'تصدير ملخص الدورة (CSV)' : 'Export Budget Cycle Summary (CSV)';
  String get backupAndRestore => isArabic ? 'النسخ الاحتياطي والاستعادة' : 'Backup & Restore';
  String get createBackup => isArabic ? 'إنشاء نسخة احتياطية' : 'Create Backup';
  String get restoreBackup => isArabic ? 'استعادة من نسخة احتياطية' : 'Restore from Backup';
  String get restoreBackupDialogTitle => isArabic ? 'استعادة النسخة الاحتياطية؟' : 'Restore Backup?';
  String get restoreWarning => isArabic
      ? '⚠️ تحذير: الاستعادة ستستبدل جميع البيانات المالية الحالية على هذا الجهاز بمحتويات هذه النسخة. لا يمكن التراجع عن هذا الإجراء.'
      : '⚠️ Warning: Restoring will overwrite all current financial data on this device with the contents of this backup. This cannot be undone.';
  String restoreCompleted(int txCount, int catCount) => isArabic
      ? 'تمت الاستعادة بنجاح! تم استرجاع $txCount معاملة و $catCount فئة.'
      : 'Restore completed! Restored $txCount transactions and $catCount categories.';
  String get preservePin => isArabic ? 'الحفاظ على رمز PIN الحالي' : 'Preserve device PIN lock';
  String get preservePinSubtitle => isArabic ? 'الاحتفاظ برمز PIN المفعل حالياً' : 'Keep your currently active PIN code';

  // --- PIN Lock Screen ---
  String get enterAppPin => isArabic ? 'أدخل رمز PIN' : 'Enter App PIN';
  String get setAppPin => isArabic ? 'تعيين رمز PIN من 4 أرقام' : 'Set a 4-Digit PIN';
  String get confirmAppPin => isArabic ? 'تأكيد رمز PIN' : 'Confirm Your PIN';
  String get unlockFinancesSubtitle => isArabic ? 'افتح حسابك المالي في سبيند وايز' : 'Unlock your SpendWise finances';
  String get choosePinSubtitle => isArabic ? 'اختر رمزاً من 4 أرقام لحماية تطبيقك' : 'Choose a 4-digit code to protect your app';
  String get reenterPinSubtitle => isArabic ? 'أعد إدخال رمز PIN المكون من 4 أرقام' : 'Re-enter your 4-digit PIN';
  String get pinsDoNotMatch => isArabic ? 'الرمزان غير متطابقين. حاول ثانية.' : 'PINs do not match. Try again.';
  String incorrectPinNotice(int remaining) => isArabic
      ? (remaining == 1 ? 'رمز خاطئ. تبقى لك محاولة واحدة.' : 'رمز خاطئ. تبقى لك $remaining محاولات.')
      : 'Incorrect PIN. $remaining attempt${remaining == 1 ? "" : "s"} remaining.';
  String lockoutNotice(int seconds) => isArabic
      ? 'محاولات خاطئة كثيرة. حاول ثانية بعد $secondsث'
      : 'Too many failed attempts. Try again in ${seconds}s';

  // --- Category Translation ---
  String localizedCategoryName(String? name) {
    if (name == null || name.isEmpty) return '';
    final trimmed = name.trim();
    if (isArabic) {
      switch (trimmed) {
        case 'Food': return 'طعام';
        case 'Food & Groceries': return 'طعام وبقالة';
        case 'Transportation': return 'مواصلات';
        case 'Social Life': return 'حياة اجتماعية';
        case 'Social & Dining': return 'حياة اجتماعية ومطاعم';
        case 'Gym & Fitness': return 'رياضة ولياقة';
        case 'AI Subscription': return 'اشتراكات ذكاء اصطناعي';
        case 'Savings': return 'مدخرات';
        case 'Investments': return 'استثمارات';
        case 'Salary': return 'راتب';
        default: return name;
      }
    } else {
      switch (trimmed) {
        case 'طعام': return 'Food';
        case 'طعام وبقالة': return 'Food & Groceries';
        case 'مواصلات': return 'Transportation';
        case 'حياة اجتماعية': return 'Social Life';
        case 'حياة اجتماعية ومطاعم': return 'Social & Dining';
        case 'رياضة ولياقة': return 'Gym & Fitness';
        case 'اشتراكات ذكاء اصطناعي': return 'AI Subscription';
        case 'مدخرات': return 'Savings';
        case 'استثمارات': return 'Investments';
        case 'راتب': return 'Salary';
        default: return name;
      }
    }
  }

  // --- Metrics & Dashboard additions ---
  String get incomeUpper => isArabic ? 'الدخل' : 'INCOME';

  // --- Reports & Comparison additions ---
  String get noTransactionsPreviousCycle => isArabic
      ? 'الدورة السابقة ليس بها معاملات مسجلة حتى الآن. ستظهر المقارنات مع استمرارك في التسجيل عبر الدورات.'
      : 'Previous cycle has no recorded transactions yet. Comparative trends will enrich as you log across cycles.';
  String get expensesLabel => isArabic ? 'المصروفات' : 'Expenses';
  String get incomeLabel => isArabic ? 'الدخل' : 'Income';
  String get netSavingsLabel => isArabic ? 'صافي المدخرات' : 'Net Savings';
  String prevPrefix(String val) => isArabic ? 'السابق: $val' : 'Prev: $val';
  String currentPrefix(String val) => isArabic ? 'الحالي: $val' : 'Current: $val';
  String previousPrefix(String val) => isArabic ? 'السابق: $val' : 'Previous: $val';
  String get categoryVarianceTitle => isArabic ? 'الفروقات حسب الفئات' : 'Category-by-Category Variance';
  String get noCategorySpendingEither => isArabic ? 'لم يتم تسجيل أي إنفاق للفئات في أي من الدورتين.' : 'No category spending recorded in either cycle.';
  String get noCyclesRecordedYet => isArabic ? 'لا توجد دورات ميزانية مسجلة حتى الآن.' : 'No budget cycles recorded yet.';
  String get newBadge => isArabic ? 'جديد' : 'New';
  String get sameBadge => isArabic ? 'مطابق' : 'Same';
  String get zeroDiffNotice => isArabic ? 'لا يوجد فارق في الإنفاق (0.00 ج.م)' : '0.00 EGP difference';
  String varianceVsLastCycle(String diff, bool increase) => isArabic
      ? (increase ? '+$diff مقارنة بالدورة السابقة' : '-$diff مقارنة بالدورة السابقة')
      : (increase ? '+$diff vs last cycle' : '-$diff vs last cycle');

  // --- Cash Flow Bar Chart additions ---
  String get noDataAvailable => isArabic ? 'لا توجد بيانات متاحة للدورات.' : 'No budget cycle data available.';
  String get netCashFlow => isArabic ? 'صافي التدفق النقدي' : 'Net Cash Flow';
  String savingsPercent(String pct, bool isPositive) => isArabic
      ? '$pct% مدخرات'
      : '${isPositive ? "+" : ""}$pct% savings';

  // --- Cycle Settings Dialog & Hints additions ---
  String get cycleStartDayDialogTitle => isArabic ? 'يوم بدء الدورة' : 'Cycle Start Day';
  String get cycleStartDayDialogDesc => isArabic
      ? 'اختر اليوم من الشهر الذي يتم فيه إيداع راتبك أو تبدأ فيه دورتك المالية.'
      : 'Select the day of the month when your salary is credited or your budget cycle begins.';
  String get firstCalendarMonth => isArabic ? 'الأول (شهر تقويمي)' : '1st (Calendar Month)';
  String get twentyFifthPayday => isArabic ? '25 (موعد الراتب الافتراضي)' : '25th (Payday Default)';
  String get customStartDayHeader => isArabic ? 'يوم بدء مخصص (1 - 31)' : 'CUSTOM START DAY (1 - 31)';
  String get cyclePreviewHeader => isArabic ? 'معاينة الدورة:' : 'Cycle Preview:';
  String get dayOnePreviewDesc => isArabic
      ? 'تمتد من اليوم الأول حتى آخر يوم في كل شهر.'
      : 'Runs from 1st to the last day of each month.';
  String dayLatePreviewDesc(int day) => isArabic
      ? 'تمتد من يوم $day حتى اليوم السابق للدورة التالية. الشهور ذات الأيام الأقل تنتقل لآخر يوم تلقائياً.'
      : 'Runs from Day $day (or month-end) to the day before next cycle. Months with fewer days automatically snap to their last day.';
  String dayNormalPreviewDesc(int day, int endDay) => isArabic
      ? 'تمتد من يوم $day حتى يوم $endDay من الشهر التالي.'
      : 'Runs from Day $day to Day $endDay of the following month.';
  String cycleStartDayUpdatedToast(int day) => isArabic
      ? 'تم تحديث يوم بدء الدورة إلى يوم $day.'
      : 'Budget cycle start day updated to Day $day.';
  String dayLabel(int day) => isArabic ? 'يوم $day' : 'Day $day';
  String get calendarMonthSubtitleSettings => isArabic
      ? 'يوم 1 • شهر تقويمي (من 1 إلى نهاية الشهر)'
      : 'Day 1 • Calendar Month (1st to end of month)';
  String get paydaySubtitleSettings => isArabic
      ? 'يوم 25 • دورة الراتب الشهرية (من 25 إلى 24)'
      : 'Day 25 • Monthly Payday (25th to 24th)';
  String customDaySubtitleSettings(int day, int endDay) => isArabic
      ? 'يوم $day (من $day إلى $endDay من الشهر التالي)'
      : 'Day $day (Day $day to Day $endDay of next month)';
  String get groceriesGymHint => isArabic ? 'مثال: بقالة، نادي، قهوة' : 'e.g. Groceries, Gym, Coffee';
  String get salaryFreelanceHint => isArabic ? 'مثال: راتب، عمل حر' : 'e.g. Salary, Freelance';
  String get tapToRecordInstantly => isArabic ? 'انقر للتسجيل الفوري' : 'Tap to record instantly';
  String get groceriesHint => isArabic ? 'مثال: بقالة' : 'e.g. Groceries';
  String get dailyCommuteHint => isArabic ? 'مثال: المواصلات اليومية' : 'e.g. Daily commute';
  String get healthPharmacyHint => isArabic ? 'مثال: صحة وصيدلية' : 'e.g. Health & Pharmacy';
  String get freelanceDesignHint => isArabic ? 'مثال: تصميم حر' : 'e.g. Freelance Design';
  String failedToCreate(String e) => isArabic ? 'فشل الإنشاء: $e' : 'Failed to create: $e';
  String failedToSave(String e) => isArabic ? 'فشل الحفظ: $e' : 'Failed to save: $e';
  String failedToUpdate(String e) => isArabic ? 'فشل التحديث: $e' : 'Failed to update: $e';
  String failedToDelete(String e) => isArabic ? 'فشل الحذف: $e' : 'Failed to delete: $e';
  String exportFailed(String e) => isArabic ? 'فشل التصدير: $e' : 'Export failed: $e';
  String backupFailed(String e) => isArabic ? 'فشلت النسخة الاحتياطية: $e' : 'Backup failed: $e';
  String restoreFailed(String e) => isArabic ? 'فشلت الاستعادة: $e' : 'Restore failed: $e';
  String failedToAddPreset(String e) => isArabic ? 'فشل تسجيل المعاملة السريعة: $e' : 'Failed to add preset transaction: $e';
  String errorSavingTransaction(String e) => isArabic ? 'فشل حفظ المعاملة: $e' : 'Error saving transaction: $e';
  String get newBudgetCycleNotificationTitle => isArabic ? 'بدأت دورة ميزانية جديدة' : 'New Budget Cycle Started';
  String newBudgetCycleNotificationBody(int day) => isArabic
      ? 'اليوم هو يوم $day! راجع مخصصات فئاتك للدورة الجديدة.'
      : 'Today is the $day! Review your category allocations for the new cycle.';
  String get eveningCheckinNotificationTitle => isArabic ? 'تسجيل مصاريف المساء مع سبيند وايز 🌙' : 'SpendWise Evening Check-in 🌙';
  String get eveningCheckinNotificationBody => isArabic
      ? 'هل أنفقت أي شيء اليوم؟ انقر لتسجيل مصروفاتك.'
      : 'Did you spend anything today? Tap to record your expenses.';
  String get budgetExceededNotificationTitle => isArabic ? 'تجاوز الميزانية!' : 'Budget Exceeded!';
  String budgetExceededNotificationBody(String cat, String amt) => isArabic
      ? 'لقد تجاوزت ميزانية $cat بمقدار $amt.'
      : 'You have exceeded your budget for $cat by $amt.';
  String get budgetWarningNotificationTitle => isArabic ? 'تحذير الميزانية (80%)' : 'Budget Warning (80%)';
  String budgetWarningNotificationBody(String cat, String pct) => isArabic
      ? 'وصلت فئة $cat إلى $pct% من ميزانيتها.'
      : '$cat has reached $pct% of its budget.';

  // --- Category Onboarding Screen ---
  String get setUpYourCategories => isArabic ? 'إعداد الفئات الخاصة بك' : 'Set Up Your Categories';
  String get onboardingCategoryDescription => isArabic
      ? 'اختر فئات مصروفاتك ومبالغ ميزانياتها الافتراضية الثابتة.'
      : 'Choose your expense categories and their fixed default budget amounts.';
  String get addCustomCategory => isArabic ? 'إضافة فئة مخصصة' : 'Add Custom Category';
  String get startBudgeting => isArabic ? 'ابدأ تتبع الميزانية' : 'Start Budgeting';
  String get selectAtLeastOneCategory => isArabic
      ? 'يرجى تحديد فئة واحدة على الأقل للمتابعة.'
      : 'Please select at least one category to get started.';
  String defaultBudgetForCategory(String name) => isArabic
      ? 'الميزانية الافتراضية لـ $name'
      : 'Default Budget for $name';
  String get nameIsRequired => isArabic ? 'الاسم مطلوب' : 'Name is required';
  String get enterValidBudgetAmount => isArabic ? 'أدخل مبلغ ميزانية صالح' : 'Enter a valid budget amount';
  String get budgetCannotBeNegative => isArabic ? 'لا يمكن أن تكون الميزانية سالبة' : 'Budget cannot be negative';
  String get failedToCompleteSetupMsg => isArabic ? 'فشل إكمال الإعداد' : 'Failed to complete setup';
  String get utilitiesHint => isArabic ? 'مثال: فواتير وخدمات' : 'e.g. Utilities';
  String get categoryName => categoryNameLabel;
  String get add => isArabic ? 'إضافة' : 'Add';
  String get budget => isArabic ? 'الميزانية' : 'Budget';
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['en', 'ar'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    final localizations = AppLocalizations(locale);
    Money.defaultCurrencySymbol = localizations.currencySymbol;
    return SynchronousFuture<AppLocalizations>(localizations);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
