import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/core/security/security_service.dart';
import 'package:money_tracker/features/settings/presentation/pages/security_settings_page.dart';
import '../../test_helper.dart';

void main() {
  setUpAll(setupTestSqlite);

  testWidgets('Change PIN asks for the current PIN before a new one',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.into(db.appSettingsTable).insert(
          AppSettingsTableCompanion.insert(key: 'budget_cycle_start_day', value: '1'),
        );
    final security = SecurityService(db, iterations: 1000, runInBackground: false);
    await security.setPin('1234');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          securityServiceProvider.overrideWithValue(security),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          supportedLocales: [Locale('en'), Locale('ar')],
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: SecuritySettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final changePin = find.byKey(const ValueKey('change_pin_button'));
    await tester.scrollUntilVisible(
      changePin,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(changePin);
    await tester.pumpAndSettle();

    Future<void> enter(String pin) async {
      for (final d in pin.split('')) {
        await tester.tap(find.text(d).hitTestable());
      }
      await tester.pumpAndSettle();
    }

    expect(find.text('Enter App PIN'), findsOneWidget);
    expect(find.text('Set a 4-Digit PIN'), findsNothing);

    await enter('9999');
    expect(find.text('Set a 4-Digit PIN'), findsNothing, reason: 'wrong PIN rejected');

    await enter('1234');
    expect(find.text('Set a 4-Digit PIN'), findsOneWidget);
  });
}
