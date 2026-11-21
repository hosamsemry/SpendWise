# CLAUDE.md — SpendWise (money_tracker)

Project context for Claude Code. Keep this updated when architecture changes.

## What it is
**SpendWise** is an offline-first personal finance + **cycle budgeting** app for Android, built with Flutter. It has one user, no backend and no telemetry, and all data stays in local SQLite. It's bilingual (English / Arabic with RTL). The target market is Egypt/GCC: EGP is the default currency, and the bank SMS parser covers InstaPay/IPN, CIB, NBE, Banque Misr, AAIB, QNB and wallets.

- Dart package: `money_tracker` · App label: `SpendWise` · Android id: `com.personal.money_tracker`
- Version is in `pubspec.yaml` (currently `1.0.1+2`). Dart SDK `^3.10.4`.
- `money_tracker_app_spec.md` is the original product spec. The app has since grown past it (Arabic, multi-currency, savings vault, smart detection), so **the code is the source of truth**.
- `README.md` is the public, marketing-style overview.

## Commands
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # after editing any Drift table / AppDatabase
flutter test                                               # full suite (~40 test files)
flutter test test/features/smart_detection/                # single folder/file
flutter analyze
flutter build apk --release --target-platform android-arm64 --split-per-abi --obfuscate --split-debug-info=build/symbols
```
- Tests use an in-memory Drift DB plus a Linux system sqlite (`test/test_helper.dart` → `setupTestSqlite()`, which needs `libsqlite3.so`).
- **Release signing**: `android/app/build.gradle.kts` reads `android/key.properties` (gitignored; keys `storePassword`, `keyPassword`, `keyAlias`, `storeFile`). The keystore is `~/keystores/spendwise-release.jks` (alias `spendwise`, cert SHA-256 `59:D7:2A:CC:…:44:13`) and lives outside the repo. If `key.properties` is missing, release builds fail on purpose. They never fall back to debug signing. Losing the keystore means future APKs can't update existing installs.
- `*.apk` files are gitignored. `SpendWise*.apk` in the root are local build outputs.

## Stack
Flutter (Material 3) · **Riverpod 3** (`flutter_riverpod`, using `Notifier`/`AsyncNotifier`/`FutureProvider`, no codegen) · **Drift** (SQLite, `sqlite3_flutter_libs`) · `flutter_local_notifications` + `timezone` · `local_auth` (biometrics) · `crypto` (SHA-256 PIN) · `share_plus`, `file_picker`, `path_provider` · `intl` · `uuid`. Font: Outfit (static weights 400–800 in `assets/fonts`).

## Layout (feature-sliced, "clean-ish" architecture)
```
lib/
  main.dart                     App root: ProviderScope, lifecycle observer, gating (lock → language → cycle setup → shell)
  app/                          MainNavigationShell (IndexedStack, 4 tabs), FloatingDockNavBar, theme/app_theme.dart (light+dark)
  core/
    database/                   AppDatabase (schemaVersion 4), tables/*, connection (money_tracker.sqlite in app docs dir)
                                app_database.g.dart is GENERATED, never hand-edit
    date/                       BudgetCycle value object + BudgetCycleCalculator (pure)
    money/                      Money (int minor units) + AppCurrency enum, MathExpressionEvaluator (calculator in amount fields)
    localization/               AppLocalizations: hand-written en/ar getters (`isArabic ? '...' : '...'`), access via `context.l10n`
    notifications/              INotificationService / NotificationService (threshold alerts, 25th reminder, daily evening reminder)
    providers/                  All shared Riverpod providers (db, repos, cycles, transactions, savings, currency, theme, language…)
    security/                   SecurityService (PIN), BiometricService, PinLockScreen
  features/<name>/{data,domain,presentation}/
    backup/       JSON full-DB export/import (BackupService, BackupData), optional keep-current-PIN on restore
    budgets/      BudgetCycleRepository, BudgetCalculationService (pure), ThresholdMonitor, CycleSummary/CategoryBudget,
                  BudgetsScreen (envelope manager), CycleSummaryScreen, InitialCycleSetupScreen (onboarding: start day + currency)
    categories/   Category model (expense|income), CategoryRepository (seeding, archive, delete, selection-frequency sort)
    dashboard/    DashboardScreen, hero card (velvet_titanium_hero_card), near-limit / overspent alert cards, cycle switcher
    export/       CsvExportService (UTF-8 BOM for Excel, localized headers/categories)
    onboarding/   LanguageSelectionScreen
    presets/      1-tap transaction presets (TransactionPreset, PresetRepository, management screen)
    reports/      "Insights" tab: cash-flow bar chart, animated category donut chart, cycle-over-cycle (hand-drawn, no chart lib)
    savings/      SavingsVaultRepository, SavingsSyncService, cycle closeout (surplus sweep) card, vault dialog
    settings/     SettingsScreen (big file, ~1.8k lines), reached from the dashboard header (not a nav tab)
    smart_detection/ Bank SMS/notification parsing → pending confirm-first queue (see below)
    transactions/ TransactionModel, TransactionRepository, TransactionsScreen (filters), AddEditTransactionDialog
android/app/src/main/kotlin/com/personal/money_tracker/
    MainActivity.kt                       FlutterFragmentActivity (needed for local_auth), MethodChannel, ACTION_SEND handling
    TransactionNotificationListener.kt    NotificationListenerService that pre-filters financial alerts (skips OTP/declined)
    SmartDetectionStorage.kt              SharedPreferences queue for alerts captured while Flutter isn't running, plus diagnostic logs
```
Nav tabs (index order): 0 Dashboard, 1 Transactions, 2 Budgets, 3 Insights (Reports). Switch tabs via `currentNavigationIndexProvider`.

## Data model (Drift, `core/database/tables/`)
| Table | Notes |
|---|---|
| `categories` | id (uuid text), name, color (hex), icon, `default_budget_minor`, `is_active`, `type` ('expense'/'income'). UNIQUE(name NOCASE, type) |
| `budget_cycles` | id = uuid (the calculator's in-memory `BudgetCycle.id` is `"start_end"`, but stored rows use UUIDs, so look cycles up by date with `getCycleForDateOrNull`), `start_date` unique, `end_date` (ISO text dates) |
| `category_budgets` | per-cycle allocation snapshot (cycle_id, category_id) unique, `budget_amount_minor` |
| `transactions` | type, `amount_minor` > 0, category_id (nullable, ON DELETE SET NULL), **`category_name` denormalized** so history survives category deletion, `transaction_date` 'YYYY-MM-DD', note |
| `notification_events` | de-dupes threshold alerts: (cycle, category, 'reached_80_percent'/'over_budget') unique |
| `app_settings` | **key/value store used for nearly all prefs and small state** (see keys below) |
| `transaction_presets` | quick-log shortcuts, display_order |

- Dates are stored as ISO strings with ASCII digits. Use `BudgetCycleCalculator.formatDate/parseDate`, which normalize Arabic/Persian digits.
- Migrations go in `AppDatabase.migration.onUpgrade` with `if (from < N)` blocks. Bump `schemaVersion`, then run build_runner. `PRAGMA foreign_keys = ON` and the transaction indexes are applied in `beforeOpen`.
- When changing the schema, also update **BackupService/BackupData** (backup = all tables) and the tests in `test/core/database/`.

`app_settings` keys: `app_language`, `theme_mode`, `primary_currency`, `budget_cycle_start_day`, `pin_enabled`, `pin_hash`, `biometrics_enabled`, `daily_reminder_enabled`, `daily_reminder_time`, `category_selection_counts` (JSON map), `savings_vault_*` (balance_minor, last_swept_cycle_id, last_sweep_amount_minor, last_swept_at, swept_cycles, dismissed_cycles), `smart_detection_enabled`, `smart_detection_pending_json`, `smart_detection_seen_refs_json`, `smart_detection_merchant_categories_json`.

## Core domain rules (don't break these)
- **Money is always int minor units** (`Money.fromMinorUnits`, `inMinorUnits`). Never use doubles for amounts. Max is 999,999,999 major units. `Money.parse` accepts Arabic digits and currency symbols.
- **Currency is global static state**: `Money.applyCurrency()` sets `Money.currentCurrency`/`defaultCurrencySymbol`. It's driven by `primaryCurrencyProvider` (EGP, SAR, AED, USD, EUR, GBP, NONE = plain numbers) and the symbol is localized by language.
- **Budget cycles**: the start day is user-chosen (1–31; it's `null` until onboarding sets it, and then the app shows `InitialCycleSetupScreen`). startDay=1 means calendar month. Otherwise a cycle runs from day N to day N−1 of the next month, **clamped** for short months and leap years. Cycles are created lazily and idempotently by `getOrCreateCycleForDate`, which snapshots each category's `defaultBudget` into `category_budgets`. Past cycles are frozen snapshots. Changing the start day calls `realignCyclesOnStartDayChange` (truncates the overlapping cycle).
- **Savings auto-budget**: a "Savings"/"مدخرات" expense category gets budget = `max(0, totalIncome − Σ other budgets)`. `TransactionService` re-syncs it on transaction writes, including the old cycle when income moves cycles or changes type. Budget/category edits must still call `SavingsSyncService.syncSavingsBudgetForCycle` themselves.
- **Savings Vault**: a lifetime balance kept in app_settings. When the previous cycle ended with a surplus, `pendingCycleCloseoutProvider` offers a 1-tap sweep or a dismiss. Withdrawals have overdraft protection.
- **Threshold alerts**: `ThresholdMonitor.evaluateAndNotify` (80% and >100%) is run by `TransactionService` for every affected expense category, old and new. Each alert fires once per cycle/category and is recorded in `notification_events`. Dropping back under a threshold clears the record, so the alert can fire again.
- **All transaction writes go through `TransactionService`** (`features/transactions/domain/transaction_service.dart`, `transactionServiceProvider`) using `add`/`update`/`delete`/`restore`. Never call `TransactionRepository` write methods from UI or other features. The service creates the cycle with the user's start day, syncs Savings and evaluates thresholds. Callers only trigger `refreshTriggerProvider`.
- **Never construct `BudgetCycleRepository(db)` in app code**: its default calculator uses start day 25. Use `budgetCycleRepositoryProvider`, which applies the user's start day.
- **Expense needs a category** (DB CHECK: category_id or category_name). Income category is optional.
- Deleting a category nulls `category_id` on transactions/presets (the name is kept) and removes its budgets. The lifecycle reconcile **unarchives all categories** on each run.
- Categories are sorted by selection frequency (`category_selection_counts`, incremented on new tx).

## State management pattern
- Repos and services are plain `Provider`s in `core/providers/database_providers.dart`, `savings_providers.dart` and `transaction_providers.dart` (`transactionServiceProvider`). `budgetCycleRepositoryProvider` rebuilds when the start day changes.
- Read models are `FutureProvider`s that `ref.watch(refreshTriggerProvider)`. **After any write, call `ref.read(refreshTriggerProvider.notifier).trigger()`** to refresh the UI. This is the app-wide invalidation mechanism. There are no Drift streams.
- UI selection state: `selectedCycleProvider` (Budgets/Reports/Summary), `dashboardCycleProvider` (hero card cycle switcher, null = current), plus transaction filters (type/category/note search/date range) in `transaction_providers.dart`.
- `isAppLockedProvider` gates the PIN screen.

## App lifecycle (`main.dart`)
On start, and on resume from real background (paused/hidden → resumed; transient `inactive` is ignored):
1. Re-check the PIN lock.
2. Run `smartDetectionCoordinator.syncFromNative()` and refresh notification-access status.
3. Run `_reconcileLifecycle()` (only once per calendar day on resume): seed default categories (by language), unarchive categories, get/create the current cycle, sync categories into it, sync the savings budget, schedule the 25th reminder, then trigger a refresh. This step is skipped entirely until the cycle start day is configured.

## Smart detection (Android only, confirm-first)
1. `TransactionNotificationListener` (needs notification-access permission) filters out the app's own and ongoing notifications, OTP/declined/failed messages, and anything that isn't a financial alert.
   - If the app is in the foreground, the alert is pushed live via MethodChannel `com.personal.money_tracker/smart_detection` (`onAlertDetected`).
   - Otherwise it's queued in `SmartDetectionStorage` (max 50, with a 30s dedup window).
2. ACTION_SEND text/plain (sharing an SMS to the app) arrives via `onSharedText` / `consumeSharedText`. Users can also paste an SMS manually.
3. Dart side: `SmartDetectionChannel` → `SmartDetectionCoordinator` → `PendingTransactionRepository.ingestMessage`.
   - Parsing uses the offline regex-based `BankMessageParser` (Arabic + English: amount, type, merchant, reference, date).
   - It dedups by signature and suggests a category from the learned merchant→category map.
4. Pending items show in `PendingTransactionsBanner`/`Sheet`. Confirming calls `SmartDetectionCoordinator.confirmPending`, which runs `TransactionService.add` (so alerts and savings apply as for manual entries) and then `PendingTransactionRepository.markConfirmed` (learn merchant, record dedup signature, dequeue). Nothing is auto-inserted.
5. Native diagnostic logs (last 15) are viewable via `getDiagnosticLogs`.

Method channel methods: `isNotificationAccessEnabled`, `openNotificationAccessSettings`, `setSmartDetectionEnabled`, `consumePendingNativeAlerts`, `consumeSharedText`, `getDiagnosticLogs`, `clearDiagnosticLogs`.

## Security
- The PIN is stored in `app_settings.pin_hash` as a self-describing string `pbkdf2-sha256$<iterations>$<b64 salt>$<b64 hash>`:
  - PBKDF2-HMAC-SHA256 with a random 16-byte salt per PIN, 100k iterations (`SecurityService.defaultIterations`), constant-time compare.
  - Hashing runs in `Isolate.run`. Widget tests must inject `SecurityService(db, iterations: 1000, runInBackground: false)` via `securityServiceProvider.overrideWithValue`, because isolates never finish under the fake clock.
  - Verification uses the iteration count stored in the hash.
- Legacy v1 hashes (hex SHA-256 of `"$pin:money_tracker_salt_v1"`, from old installs and backups) still verify. They are re-hashed to the current format on the first successful verify, and so are hashes with fewer iterations than the current setting. Don't remove the legacy path.
- Biometric unlock goes through `local_auth` and requires `FlutterFragmentActivity`.
- The PIN screen has a 30-second lockout after repeated failures.

## Conventions
- Every user-visible string is a getter in `AppLocalizations` with both `en` and `ar` text. Use `context.l10n.xxx` and never hardcode strings. Remember RTL and Arabic numerals.
- Colors must work in light **and** dark themes. Several tests assert theme-adaptive colors (`*_theme_test.dart`). Brand palette: obsidian `#0B0B0E`/`#14141B`, champagne gold `#E5C158`/`#B38A24`, velvet crimson `#7B1123`.
- Commits follow Conventional Commits: `feat(scope): …`, `fix(scope): …`, `refactor`, `chore`. Scopes are typically the feature name. Issues are referenced as `(closes #N)`.
- Domain services (`BudgetCalculationService`, `BudgetCycleCalculator`, `BankMessageParser`, `Money`) are pure and unit-tested. Keep logic there rather than in widgets.
- Big screen files (settings, reports, budgets, dashboard) still mix UI with some orchestration, such as budget, category and savings-vault edits. Transaction writes are centralized in `TransactionService`. Check the screen before assuming a non-transaction repo method handles every side effect.
- Add or update tests under `test/` mirroring `lib/`. Cross-feature flows are in `test/features/end_to_end_flow_test.dart`, `audit_regression_test.dart`, and `test/widget_test.dart`.
