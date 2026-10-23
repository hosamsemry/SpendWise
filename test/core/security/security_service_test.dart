import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/security/security_service.dart';
import '../../test_helper.dart';

void main() {
  setUpAll(() {
    setupTestSqlite();
  });

  late AppDatabase db;
  late SecurityService securityService;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    securityService = SecurityService(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('SecurityService Tests', () {
    test('isPinEnabled returns false by default', () async {
      final enabled = await securityService.isPinEnabled();
      expect(enabled, isFalse);
    });

    test('setPin hashes PIN and enables PIN lock', () async {
      await securityService.setPin('1234');

      final enabled = await securityService.isPinEnabled();
      expect(enabled, isTrue);

      final verifyCorrect = await securityService.verifyPin('1234');
      expect(verifyCorrect, isTrue);

      final verifyWrong = await securityService.verifyPin('9999');
      expect(verifyWrong, isFalse);
    });

    test('disablePin requires correct PIN to disable lock', () async {
      await securityService.setPin('5678');

      // Attempt with wrong PIN
      final wrongResult = await securityService.disablePin('0000');
      expect(wrongResult, isFalse);
      expect(await securityService.isPinEnabled(), isTrue);

      // Attempt with correct PIN
      final correctResult = await securityService.disablePin('5678');
      expect(correctResult, isTrue);
      expect(await securityService.isPinEnabled(), isFalse);
    });

    test('resetPin disables PIN lock safely', () async {
      await securityService.setPin('4321');
      expect(await securityService.isPinEnabled(), isTrue);

      await securityService.resetPin();
      expect(await securityService.isPinEnabled(), isFalse);
    });
  });
}
