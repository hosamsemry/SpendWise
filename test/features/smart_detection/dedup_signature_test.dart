import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/features/smart_detection/data/pending_transaction_repository.dart';
import 'package:money_tracker/features/smart_detection/domain/bank_message_parser.dart';
import '../../test_helper.dart';

void main() {
  setUpAll(setupTestSqlite);

  late AppDatabase db;
  late PendingTransactionRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = PendingTransactionRepository(db);
  });
  tearDown(() => db.close());

  const morning =
      'Your card ending 1234 was debited with EGP 45.00 at Costa Coffee on 20/11 at 09:10';
  const afternoon =
      'Your card ending 1234 was debited with EGP 45.00 at Costa Coffee on 20/11 at 16:40';

  test('two identical purchases at different stated times are both kept', () async {
    final a = await repo.ingestMessage(morning, receivedAt: DateTime(2026, 11, 20, 9, 10));
    final b = await repo.ingestMessage(afternoon, receivedAt: DateTime(2026, 11, 20, 16, 40));
    expect(a, isNotNull);
    expect(b, isNotNull);
    expect(await repo.getPendingTransactions(), hasLength(2));
  });

  test('the same alert delivered twice is still deduplicated', () async {
    await repo.ingestMessage(morning, receivedAt: DateTime(2026, 11, 20, 9, 10));
    final again = await repo.ingestMessage(morning, receivedAt: DateTime(2026, 11, 20, 9, 12));
    expect(again, isNull);
  });

  test('without a stated time, re-delivery on the same day still collapses', () async {
    const noTime = 'Your card ending 1234 was debited with EGP 45.00 at Costa Coffee on 20/11';
    await repo.ingestMessage(noTime, receivedAt: DateTime(2026, 11, 20, 9, 10));
    final later = await repo.ingestMessage(noTime, receivedAt: DateTime(2026, 11, 20, 18, 0));
    expect(later, isNull);
  });

  test('a stated time without a date uses the received day', () {
    final p = BankMessageParser.parse(
      'Your card ending 1234 was debited with EGP 45.00 at Costa Coffee at 16:40',
      receivedAt: DateTime(2026, 11, 20, 18, 5),
    )!;
    expect(p.hasExplicitTime, isTrue);
    expect(p.transactionDate, DateTime(2026, 11, 20, 16, 40));
  });
}
