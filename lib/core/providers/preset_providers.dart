import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_tracker/features/presets/data/preset_repository.dart';
import 'package:money_tracker/features/presets/domain/transaction_preset.dart';
import 'cycle_providers.dart';
import 'database_providers.dart';

final presetRepositoryProvider = Provider<PresetRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return PresetRepository(db);
});

final allPresetsProvider = FutureProvider<List<TransactionPreset>>((ref) async {
  ref.watch(refreshTriggerProvider);
  final repo = ref.watch(presetRepositoryProvider);
  return repo.getAllPresets();
});
