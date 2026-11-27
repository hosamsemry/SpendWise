import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';

void main() {
  group('AppLocalizations Unit Tests', () {
    test('English dictionary contains valid strings and currency', () {
      final l10n = AppLocalizations(const Locale('en'));
      expect(l10n.isArabic, isFalse);
      expect(l10n.appName, 'Paydial');
      expect(l10n.currencySymbol, 'EGP');
      expect(l10n.navDashboard, 'Dashboard');
      expect(l10n.navTransactions, 'Transactions');
      expect(l10n.navBudgets, 'Budgets');
      expect(l10n.navSettings, 'Settings');
      expect(l10n.lifetimeSavingsVault, 'Lifetime Savings Vault');
      expect(l10n.autoBalancedBadge, 'Auto-balanced');
      expect(l10n.savingsCategoryName, 'Savings');
      expect(l10n.undo, 'Undo');
      expect(l10n.searchNotesHint, 'Search notes...');
      expect(l10n.ofTotal('1,000 EGP'), 'of 1,000 EGP');
      expect(l10n.lockoutNotice(30), 'Too many failed attempts. Try again in 30s');
      expect(l10n.percentOfBudget('5'), '5% of budget');
      expect(l10n.daysLeftLabel(1), 'day left');
      expect(l10n.daysLeftLabel(5), 'days left');
      expect(l10n.noBudgetSetShort, 'No budget set');
    });

    test('Arabic dictionary contains correct Arabic translations and Egyptian pound symbol', () {
      final l10n = AppLocalizations(const Locale('ar'));
      expect(l10n.isArabic, isTrue);
      expect(l10n.appName, 'باي دايل');
      expect(l10n.currencySymbol, 'ج.م');
      expect(l10n.navDashboard, 'الرئيسية');
      expect(l10n.navTransactions, 'المعاملات');
      expect(l10n.navBudgets, 'الميزانيات');
      expect(l10n.navSettings, 'الإعدادات');
      expect(l10n.lifetimeSavingsVault, 'خزينة المدخرات الدائمة');
      expect(l10n.autoBalancedBadge, 'موازنة تلقائية');
      expect(l10n.savingsCategoryName, 'مدخرات');
      expect(l10n.confirmAndContinue, 'تأكيد ومتابعة');
      expect(l10n.undo, 'تراجع');
      expect(l10n.searchNotesHint, 'بحث في الملاحظات...');
      expect(l10n.ofTotal('1,000 ج.م'), 'من 1,000 ج.م');
      expect(l10n.lockoutNotice(30), 'محاولات خاطئة كثيرة. حاول ثانية بعد 30ث');
      expect(l10n.percentOfBudget('5'), '5% من الميزانية');
      expect(l10n.daysLeftLabel(1), 'يوم متبقٍ');
      expect(l10n.daysLeftLabel(5), 'أيام متبقية');
      expect(l10n.noBudgetSetShort, 'لا توجد ميزانية');
    });

    test('Delegate supports en and ar locales', () {
      const delegate = AppLocalizations.delegate;
      expect(delegate.isSupported(const Locale('en')), isTrue);
      expect(delegate.isSupported(const Locale('ar')), isTrue);
      expect(delegate.isSupported(const Locale('fr')), isFalse);
    });
  });

  test('backupAgeLabel uses calendar days in both languages', () {
    final en = AppLocalizations(const Locale('en'));
    final ar = AppLocalizations(const Locale('ar'));
    final now = DateTime(2026, 11, 21, 9);
    expect(en.backupAgeLabel(null, now), 'Never backed up');
    expect(en.backupAgeLabel(DateTime(2026, 11, 21, 1), now), 'Backed up today');
    expect(en.backupAgeLabel(DateTime(2026, 11, 20, 23), now), 'Backed up yesterday');
    expect(en.backupAgeLabel(DateTime(2026, 11, 18), now), 'Backed up 3 days ago');
    expect(ar.backupAgeLabel(null, now), 'لم يتم النسخ الاحتياطي بعد');
    expect(ar.backupAgeLabel(DateTime(2026, 11, 19), now), 'آخر نسخة منذ يومين');
    expect(ar.backupAgeLabel(DateTime(2026, 11, 16), now), 'آخر نسخة منذ 5 أيام');
    expect(ar.backupAgeLabel(DateTime(2026, 10, 1), now), 'آخر نسخة منذ 51 يومًا');
  });
}
