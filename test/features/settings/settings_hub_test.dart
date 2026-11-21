import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/features/settings/presentation/settings_screen.dart';
import '../../test_helper.dart';

void main() {
  setUpAll(setupTestSqlite);

  const groups = {
    'settings_nav_budget_money': 'Budget & Money',
    'settings_nav_language_appearance': 'Language & Appearance',
    'settings_nav_security': 'Privacy & Security',
    'settings_nav_smart_detection': 'Smart Detection',
    'settings_nav_reminders': 'Reminders',
    'settings_nav_backup': 'Backup & Export',
  };

  Future<void> pumpHub(WidgetTester tester, Locale locale) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.into(db.appSettingsTable).insert(
          AppSettingsTableCompanion.insert(key: 'budget_cycle_start_day', value: '25'),
        );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('every hub row opens its page and comes back', (tester) async {
    await pumpHub(tester, const Locale('en'));
    for (final entry in groups.entries) {
      final row = find.byKey(ValueKey(entry.key));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text(entry.value)),
        findsOneWidget,
        reason: entry.key,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
    }
  });

  testWidgets('hub and pages render in Arabic (RTL)', (tester) async {
    await pumpHub(tester, const Locale('ar'));
    expect(find.text('الخصوصية والأمان'), findsOneWidget);
    for (final key in groups.keys) {
      final row = find.byKey(ValueKey(key));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: key);
      expect(find.byType(BackButton), findsOneWidget, reason: key);
      // pageBack() looks for the English 'Back' tooltip, so tap it directly.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
    }
  });
}
