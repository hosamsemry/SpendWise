import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/features/smart_detection/data/smart_detection_channel.dart';
import 'package:money_tracker/features/smart_detection/data/source_app_repository.dart';
import 'package:money_tracker/features/smart_detection/domain/source_app.dart';
import 'package:money_tracker/features/smart_detection/presentation/smart_detection_providers.dart';
import '../../test_helper.dart';

class _FakeChannel extends SmartDetectionChannel {
  List<RawNativeAlert> queued = [];
  List<SuggestedSourceApp> suggestions = [];
  final List<({List<String> watched, List<String> dismissed})> policies = [];

  @override
  Future<void> setNativeDetectionEnabled(bool enabled) async {}

  @override
  Future<void> setSourcePolicy({
    required List<String> watched,
    required List<String> dismissed,
  }) async =>
      policies.add((watched: watched, dismissed: dismissed));

  @override
  Future<List<RawNativeAlert>> consumePendingNativeAlerts() async {
    final out = queued;
    queued = [];
    return out;
  }

  @override
  Future<String?> consumeSharedText() async => null;

  @override
  Future<List<SuggestedSourceApp>> getSuggestedApps() async => suggestions;
}

RawNativeAlert _alert(
  String text, {
  required String pkg,
  required AlertSourceKind kind,
}) =>
    RawNativeAlert(
      id: text.hashCode.toString(),
      packageName: pkg,
      title: '',
      text: text,
      receivedAt: DateTime(2026, 11, 20, 12),
      sourceKind: kind,
    );

const _walletPkg = 'com.example.wallet';
const _smsPkg = 'com.google.android.apps.messaging';

// Loose wording a real wallet app might use: no card/account marker.
const _walletReceipt = 'You paid EGP 85.50 to Uber';
const _personalSms = 'I paid 200 EGP for dinner, send me your share';
const _bankSms =
    'Your card ending 1234 was debited with EGP 350.00 at Carrefour on 20/11 Ref# 998877';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(setupTestSqlite);

  late AppDatabase db;
  late _FakeChannel channel;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.into(db.appSettingsTable).insert(
          AppSettingsTableCompanion.insert(
            key: 'smart_detection_enabled',
            value: 'true',
          ),
        );
    channel = _FakeChannel();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        smartDetectionChannelProvider.overrideWithValue(channel),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  SourceAppRepository sources() => container.read(sourceAppRepositoryProvider);
  SmartDetectionCoordinator coordinator() =>
      container.read(smartDetectionCoordinatorProvider);
  Future<List<String>> pendingTexts() async => (await container
          .read(pendingTransactionRepositoryProvider)
          .getPendingTransactions())
      .map((p) => p.rawMessage)
      .toList();

  group('SourceAppRepository', () {
    test('watch, unwatch and dismiss persist in app_settings', () async {
      expect(await sources().getWatchedApps(), isEmpty);

      await sources().watchApp(packageName: _walletPkg, label: 'My Wallet');
      await sources().watchApp(packageName: _walletPkg, label: 'My Wallet');
      final watched = await sources().getWatchedApps();
      expect(watched.map((a) => a.packageName), [_walletPkg]);
      expect(watched.single.label, 'My Wallet');

      await sources().unwatchApp(_walletPkg);
      expect(await sources().getWatchedApps(), isEmpty);

      await sources().dismissApp('com.whatsapp');
      expect(await sources().getDismissedPackages(), ['com.whatsapp']);
    });

    test('watching a dismissed app un-dismisses it', () async {
      await sources().dismissApp(_walletPkg);
      await sources().watchApp(packageName: _walletPkg, label: 'Wallet');
      expect(await sources().getDismissedPackages(), isEmpty);
    });

    test('corrupt stored JSON reads as empty instead of throwing', () async {
      await db.into(db.appSettingsTable).insertOnConflictUpdate(
            AppSettingsTableCompanion.insert(
              key: watchedSourceAppsKey,
              value: '{not json',
            ),
          );
      expect(await sources().getWatchedApps(), isEmpty);
    });
  });

  group('alert ingestion by source', () {
    test('SMS alerts are parsed strictly: bank text queued, chat dropped',
        () async {
      channel.queued = [
        _alert(_personalSms, pkg: _smsPkg, kind: AlertSourceKind.sms),
        _alert(_bankSms, pkg: _smsPkg, kind: AlertSourceKind.sms),
      ];
      expect(await coordinator().syncFromNative(), 1);
      expect(await pendingTexts(), [_bankSms]);
    });

    test('watched apps use the normal parser', () async {
      await sources().watchApp(packageName: _walletPkg, label: 'Wallet');
      channel.queued = [
        _alert(_walletReceipt, pkg: _walletPkg, kind: AlertSourceKind.watched),
      ];
      expect(await coordinator().syncFromNative(), 1);
      expect(await pendingTexts(), [_walletReceipt]);
    });

    test('alerts from an app that was unwatched since are parsed strictly',
        () async {
      channel.queued = [
        _alert(_walletReceipt, pkg: _walletPkg, kind: AlertSourceKind.watched),
      ];
      expect(await coordinator().syncFromNative(), 0);
    });

    test('alerts queued before source gating (unknown kind) are strict',
        () async {
      channel.queued = [
        _alert(_walletReceipt, pkg: _walletPkg, kind: AlertSourceKind.unknown),
        _alert(_bankSms, pkg: _smsPkg, kind: AlertSourceKind.unknown),
      ];
      expect(await coordinator().syncFromNative(), 1);
      expect(await pendingTexts(), [_bankSms]);
    });

    test('live alerts follow the same rules', () async {
      final dropped = await coordinator().ingestLiveAlert(
        _alert(_personalSms, pkg: _smsPkg, kind: AlertSourceKind.sms),
      );
      expect(dropped, isNull);

      await sources().watchApp(packageName: _walletPkg, label: 'Wallet');
      final kept = await coordinator().ingestLiveAlert(
        _alert(_walletReceipt, pkg: _walletPkg, kind: AlertSourceKind.watched),
      );
      expect(kept, isNotNull);
    });
  });

  group('source policy sync and suggestions', () {
    test('sync and every change push the policy to native', () async {
      await coordinator().syncFromNative();
      expect(channel.policies.last.watched, isEmpty);

      await coordinator().watchSourceApp(packageName: _walletPkg, label: 'W');
      expect(channel.policies.last.watched, [_walletPkg]);

      await coordinator().dismissSuggestedApp('com.whatsapp');
      expect(channel.policies.last.dismissed, ['com.whatsapp']);

      await coordinator().unwatchSourceApp(_walletPkg);
      expect(channel.policies.last.watched, isEmpty);
    });

    test('suggestions exclude watched and dismissed apps', () async {
      SuggestedSourceApp s(String pkg) => SuggestedSourceApp(
            packageName: pkg,
            label: pkg,
            count: 1,
            lastSeen: DateTime(2026, 11, 20),
            preview: '',
          );
      channel.suggestions = [s(_walletPkg), s('com.whatsapp'), s('com.bank')];

      await coordinator().watchSourceApp(packageName: _walletPkg, label: 'W');
      await coordinator().dismissSuggestedApp('com.whatsapp');

      final shown = await container.read(suggestedSourceAppsProvider.future);
      expect(shown.map((a) => a.packageName), ['com.bank']);
    });
  });
}
