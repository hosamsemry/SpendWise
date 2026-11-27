import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/features/backup/data/backup_crypto.dart';
import 'package:money_tracker/features/backup/domain/backup_data.dart';
import 'package:money_tracker/features/backup/presentation/backup_password_dialogs.dart';

Widget _host(void Function(BuildContext) onTap, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('en'), Locale('ar')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => onTap(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

BackupData _emptyBackup() => BackupData(
      metadata: BackupMetadata(
        version: 1,
        schemaVersion: 4,
        appName: 'Paydial',
        createdAt: DateTime(2026, 11, 21),
      ),
      categories: const [],
      budgetCycles: const [],
      categoryBudgets: const [],
      transactions: const [],
      transactionPresets: const [],
      appSettings: const [],
    );

void main() {
  group('export dialog', () {
    Future<BackupExportChoice?> run(
      WidgetTester tester,
      Future<void> Function() interact,
    ) async {
      BackupExportChoice? result;
      var closed = false;
      await tester.pumpWidget(_host((ctx) async {
        result = await showExportBackupDialog(ctx);
        closed = true;
      }));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await interact();
      await tester.pumpAndSettle();
      expect(closed, isTrue, reason: 'dialog should have closed');
      return result;
    }

    Finder field(String key) => find.byKey(ValueKey(key));
    Finder confirm() => find.byKey(const ValueKey('export_backup_confirm'));

    testWidgets('protection is on by default and validates the password',
        (tester) async {
      final choice = await run(tester, () async {
        await tester.tap(confirm());
        await tester.pumpAndSettle();
        expect(find.text('Use at least 8 characters'), findsOneWidget);

        await tester.enterText(field('backup_password_field'), 'longenough');
        await tester.enterText(field('backup_password_confirm_field'), 'different!');
        await tester.tap(confirm());
        await tester.pumpAndSettle();
        expect(find.text('Passwords do not match'), findsOneWidget);

        await tester.enterText(field('backup_password_confirm_field'), 'longenough');
        await tester.tap(confirm());
      });
      expect(choice?.password, 'longenough');
    });

    testWidgets('turning protection off exports without a password',
        (tester) async {
      final choice = await run(tester, () async {
        await tester.tap(find.byKey(const ValueKey('protect_backup_switch')));
        await tester.pumpAndSettle();
        expect(
          find.text('This backup will be readable by anyone who gets the file.'),
          findsOneWidget,
        );
        await tester.tap(confirm());
      });
      expect(choice, isNotNull);
      expect(choice!.password, isNull);
    });

    testWidgets('cancel returns null', (tester) async {
      final choice = await run(tester, () => tester.tap(find.text('Cancel')));
      expect(choice, isNull);
    });
  });

  group('unlock dialog', () {
    testWidgets('stays open on a wrong password, returns data on the right one',
        (tester) async {
      final backup = _emptyBackup();
      BackupData? result;
      final tried = <String>[];
      await tester.pumpWidget(_host((ctx) async {
        result = await showUnlockBackupDialog(ctx, unlock: (pw) async {
          tried.add(pw);
          if (pw != 'right-password') throw const WrongBackupPasswordException();
          return backup;
        });
      }));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final field = find.byKey(const ValueKey('unlock_backup_password_field'));
      final unlock = find.byKey(const ValueKey('unlock_backup_confirm'));

      await tester.enterText(field, 'nope');
      await tester.tap(unlock);
      await tester.pumpAndSettle();
      expect(find.text('Wrong password, or the file is damaged.'), findsOneWidget);
      expect(result, isNull);

      await tester.enterText(field, 'right-password');
      await tester.tap(unlock);
      await tester.pumpAndSettle();
      expect(result, same(backup));
      expect(tried, ['nope', 'right-password']);
    });

    testWidgets('renders in Arabic', (tester) async {
      await tester.pumpWidget(_host(
        (ctx) => showUnlockBackupDialog(ctx, unlock: (_) async => _emptyBackup()),
        locale: const Locale('ar'),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('نسخة احتياطية محمية'), findsOneWidget);
    });
  });
}
