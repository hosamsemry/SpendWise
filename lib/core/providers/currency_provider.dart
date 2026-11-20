import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/core/providers/cycle_providers.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/core/providers/language_provider.dart';

const String primaryCurrencyKey = 'primary_currency';

class PrimaryCurrencyNotifier extends Notifier<AppCurrency> {
  @override
  AppCurrency build() {
    final db = ref.watch(databaseProvider);
    final langAsync = ref.watch(appLanguageProvider);
    final isArabic = langAsync.asData?.value?.languageCode == 'ar';

    // Reset synchronously to EGP before async database query resolves
    Money.applyCurrency(AppCurrency.egp, isArabic: isArabic);
    _loadCurrency(db, isArabic);
    return AppCurrency.egp;
  }

  Future<void> _loadCurrency(AppDatabase db, bool isArabic) async {
    final setting = await (db.select(db.appSettingsTable)
          ..where((tbl) => tbl.key.equals(primaryCurrencyKey)))
        .getSingleOrNull();

    final loaded = setting != null
        ? AppCurrency.fromCode(setting.value)
        : AppCurrency.egp;

    Money.applyCurrency(loaded, isArabic: isArabic);
    if (state != loaded) {
      state = loaded;
      ref.read(refreshTriggerProvider.notifier).trigger();
    }
  }

  Future<void> setCurrency(AppCurrency currency) async {
    final db = ref.read(databaseProvider);
    final isArabic =
        ref.read(appLanguageProvider).asData?.value?.languageCode == 'ar';

    Money.applyCurrency(currency, isArabic: isArabic);
    state = currency;

    await db.into(db.appSettingsTable).insertOnConflictUpdate(
          AppSettingsTableCompanion.insert(
            key: primaryCurrencyKey,
            value: currency.code,
          ),
        );

    ref.read(refreshTriggerProvider.notifier).trigger();
  }
}

final primaryCurrencyProvider =
    NotifierProvider<PrimaryCurrencyNotifier, AppCurrency>(
  PrimaryCurrencyNotifier.new,
);
