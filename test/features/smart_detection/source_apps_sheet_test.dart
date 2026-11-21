import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/features/smart_detection/data/smart_detection_channel.dart';
import 'package:money_tracker/features/smart_detection/domain/source_app.dart';
import 'package:money_tracker/features/smart_detection/presentation/smart_detection_providers.dart';
import 'package:money_tracker/features/smart_detection/presentation/source_apps_sheet.dart';
import '../../test_helper.dart';

class _FakeChannel extends SmartDetectionChannel {
  final List<SuggestedSourceApp> suggestions;
  List<String> lastWatched = const [];

  _FakeChannel(this.suggestions);

  @override
  Future<List<SuggestedSourceApp>> getSuggestedApps() async => suggestions;

  @override
  Future<void> setSourcePolicy({
    required List<String> watched,
    required List<String> dismissed,
  }) async => lastWatched = watched;
}

SuggestedSourceApp _suggestion(String pkg, String label) => SuggestedSourceApp(
  packageName: pkg,
  label: label,
  count: 3,
  lastSeen: DateTime(2026, 11, 20),
  preview: 'EGP 120 debited from your account',
);

/// Scrolls [finder] into view (the sheet scrolls once it has suggestions).
Future<Finder> _visible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  return finder;
}

Finder _emptyState() =>
    find.textContaining('No apps added yet', skipOffstage: false);

void main() {
  setUpAll(setupTestSqlite);

  Future<_FakeChannel> pumpSheet(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    // Phone-sized viewport (360x800 logical) so the whole sheet is laid out.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final channel = _FakeChannel([
      _suggestion('com.example.bank', 'Example Bank'),
      _suggestion('com.example.chat', 'Chat App'),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          smartDetectionChannelProvider.overrideWithValue(channel),
        ],
        child: MaterialApp(
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const Scaffold(body: SourceAppsSheet()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return channel;
  }

  testWidgets('watching, ignoring and removing source apps', (tester) async {
    final channel = await pumpSheet(tester);

    expect(find.text('Suggested'), findsOneWidget);
    expect(find.text('Example Bank'), findsOneWidget);
    expect(find.text('Sent 3 money-related notifications'), findsNWidgets(2));
    expect(_emptyState(), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('watch_app_com.example.bank')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const ValueKey('watched_app_com.example.bank'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('suggested_app_com.example.bank')),
      findsNothing,
    );
    expect(channel.lastWatched, ['com.example.bank']);

    await tester.tap(
      await _visible(
        tester,
        find.byKey(const ValueKey('ignore_app_com.example.chat')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Suggested'), findsNothing);

    await tester.tap(
      await _visible(
        tester,
        find.byKey(const ValueKey('unwatch_app_com.example.bank')),
      ),
    );
    await tester.pumpAndSettle();
    expect(_emptyState(), findsOneWidget);
    expect(channel.lastWatched, isEmpty);
  });

  testWidgets('renders in Arabic', (tester) async {
    await pumpSheet(tester, locale: const Locale('ar'));
    expect(find.text('تطبيقات البنوك والمحافظ'), findsOneWidget);
    expect(find.text('مقترحة'), findsOneWidget);
    expect(find.text('إضافة'), findsNWidgets(2));
  });
}
