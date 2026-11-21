import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/main.dart';
import '../../test_helper.dart';

void main() {
  setUpAll(setupTestSqlite);

  testWidgets('privacy cover hides content while the app is not in front',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    for (final e in {'app_language': 'en', 'budget_cycle_start_day': '1'}.entries) {
      await db.into(db.appSettingsTable).insert(
            AppSettingsTableCompanion.insert(key: e.key, value: e.value),
          );
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MoneyTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();

    final cover = find.byKey(const ValueKey('privacy_cover'));
    expect(cover, findsNothing);

    // inactive is when Android may snapshot the app for the recents list.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(cover.hitTestable(), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(cover.hitTestable(), findsOneWidget);

    for (final s in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    await tester.pumpAndSettle();
    expect(cover, findsNothing);
  });
}
