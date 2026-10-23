import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/features/categories/data/category_repository.dart';
import 'package:money_tracker/features/categories/domain/category.dart';
import 'package:money_tracker/features/presets/data/preset_repository.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';
import '../../test_helper.dart';

void main() {
  setUpAll(() {
    setupTestSqlite();
  });

  late AppDatabase db;
  late PresetRepository presetRepo;
  late CategoryRepository categoryRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    presetRepo = PresetRepository(db);
    categoryRepo = CategoryRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('PresetRepository Tests', () {
    test('createPreset creates and stores a user-defined preset', () async {
      final category = await categoryRepo.createCategory(
        name: 'Morning Coffee',
        type: CategoryType.expense,
      );

      final preset = await presetRepo.createPreset(
        title: 'Espresso',
        type: TransactionType.expense,
        categoryId: category.id,
        amount: Money.fromMajorUnits(45), // 45.00 EGP
        note: 'Daily morning espresso',
      );

      expect(preset.title, 'Espresso');
      expect(preset.amount.inMinorUnits, 4500);
      expect(preset.categoryId, category.id);
      expect(preset.categoryName, 'Morning Coffee');
      expect(preset.note, 'Daily morning espresso');

      final all = await presetRepo.getAllPresets();
      expect(all.length, 1);
      expect(all.first.id, preset.id);
    });

    test('createPreset rejects empty title or zero/negative amount', () async {
      expect(
        () => presetRepo.createPreset(
          title: '   ',
          type: TransactionType.expense,
          amount: Money.fromMajorUnits(10),
        ),
        throwsArgumentError,
      );

      expect(
        () => presetRepo.createPreset(
          title: 'Valid Title',
          type: TransactionType.expense,
          amount: const Money.zero(),
        ),
        throwsArgumentError,
      );
    });

    test('updatePreset updates preset fields properly', () async {
      final preset = await presetRepo.createPreset(
        title: 'Metro',
        type: TransactionType.expense,
        amount: Money.fromMajorUnits(10),
      );

      await presetRepo.updatePreset(
        id: preset.id,
        title: 'Metro Ticket (Zone 2)',
        amount: Money.fromMajorUnits(15),
        note: 'Updated tariff',
      );

      final all = await presetRepo.getAllPresets();
      expect(all.length, 1);
      expect(all.first.title, 'Metro Ticket (Zone 2)');
      expect(all.first.amount.inMinorUnits, 1500);
      expect(all.first.note, 'Updated tariff');
    });

    test('deletePreset removes preset from database', () async {
      final p1 = await presetRepo.createPreset(
        title: 'Snack',
        type: TransactionType.expense,
        amount: Money.fromMajorUnits(20),
      );
      final p2 = await presetRepo.createPreset(
        title: 'Gym',
        type: TransactionType.expense,
        amount: Money.fromMajorUnits(500),
      );

      expect((await presetRepo.getAllPresets()).length, 2);

      await presetRepo.deletePreset(p1.id);

      final remaining = await presetRepo.getAllPresets();
      expect(remaining.length, 1);
      expect(remaining.first.id, p2.id);
    });

    test('createPreset handles non-existent or deleted categoryId safely', () async {
      final p = await presetRepo.createPreset(
        title: 'Unknown Cat',
        type: TransactionType.expense,
        amount: Money.fromMajorUnits(50),
        categoryId: 'non_existent_category_id',
      );

      expect(p.categoryId, isNull);
      expect(p.title, 'Unknown Cat');
      expect(p.amount, Money.fromMajorUnits(50));
    });
  });
}
