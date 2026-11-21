import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/core/security/presentation/pin_lock_screen.dart';
import 'package:money_tracker/core/security/security_service.dart';
import 'package:money_tracker/features/settings/presentation/settings_screen.dart';
import 'package:money_tracker/main.dart';
import '../../test_helper.dart';

void main() {
  setUpAll(setupTestSqlite);

  Future<ProviderContainer> pumpLockedApp(WidgetTester tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    for (final e in {'app_language': 'en', 'budget_cycle_start_day': '1'}.entries) {
      await db.into(db.appSettingsTable).insert(
            AppSettingsTableCompanion.insert(key: e.key, value: e.value),
          );
    }
    final security = SecurityService(db, iterations: 1000, runInBackground: false);
    await security.setPin('1234');

    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        securityServiceProvider.overrideWithValue(security),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MoneyTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> enterPin(WidgetTester tester, String pin) async {
    for (final d in pin.split('')) {
      await tester.tap(find.text(d).hitTestable());
    }
    await tester.pumpAndSettle();
  }

  Future<void> sendToBackgroundAndBack(WidgetTester tester) async {
    for (final s in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    await tester.pumpAndSettle();
    for (final s in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    await tester.pumpAndSettle();
  }

  Finder pinPad() => find.byType(PinLockScreen).hitTestable();
  Finder settings() => find.byType(SettingsScreen).hitTestable();

  testWidgets('screens opened before locking stay covered by the lock',
      (tester) async {
    final container = await pumpLockedApp(tester);
    expect(pinPad(), findsOneWidget);
    await enterPin(tester, '1234');

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(settings(), findsOneWidget);

    await sendToBackgroundAndBack(tester);

    expect(container.read(isAppLockedProvider), isTrue);
    expect(pinPad(), findsOneWidget);
    expect(settings(), findsNothing, reason: 'Settings must not be reachable');

    // Unlocking returns the user exactly where they were.
    await enterPin(tester, '1234');
    expect(pinPad(), findsNothing);
    expect(settings(), findsOneWidget);
  });

  testWidgets('system back while locked does not pop hidden screens',
      (tester) async {
    await pumpLockedApp(tester);
    await enterPin(tester, '1234');
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await sendToBackgroundAndBack(tester);

    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(handled, isTrue);
    expect(pinPad(), findsOneWidget);

    await enterPin(tester, '1234');
    expect(settings(), findsOneWidget, reason: 'Settings was not popped');
  });
}
