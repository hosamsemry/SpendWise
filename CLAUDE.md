# CLAUDE.md — Paydial (money_tracker)

Project context for Claude Code. Keep this updated when architecture changes.

## What it is
**Paydial** (Arabic «باي دايل», formerly SpendWise) is an offline-first personal finance + **cycle budgeting** app for Android, built with Flutter. It has one user, no backend and no telemetry, and all data stays in local SQLite. It's bilingual (English / Arabic with RTL). The target market is Egypt/GCC: EGP is the default currency, and the bank SMS parser covers InstaPay/IPN, CIB, NBE, Banque Misr, AAIB, QNB and wallets.

- Dart package: `money_tracker` · App label: `Paydial` · App ID (Android applicationId / iOS bundle id): `com.paydial.app`, permanent once on Google Play. Earlier IDs were `com.spendwise.app` (until 2026-11-28, app called SpendWise) and `com.personal.money_tracker` (until 2026-11-25). Each is a separate app on devices, so moving over means backup → install → restore.
- **Old names that must stay**: backups from SpendWise/money_tracker must keep restoring (`compatibleAppNames` in `backup_data.dart`), the encrypted-backup format id stays `spendwise-encrypted-backup` (golden test), and `ExportFileStore`'s legacy cleanup still matches `SpendWise_*`/`spendwise_*` files. The keystore file/alias keep their `spendwise` names (renaming them changes nothing for users).
- Version is in `pubspec.yaml` (currently `2.1.0+5`). Dart SDK `^3.10.4`.
- `money_tracker_app_spec.md` is the original product spec. The app has since grown past it (Arabic, multi-currency, savings vault, smart detection), so **the code is the source of truth**.
- `README.md` is the public, marketing-style overview.

## Commands
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs --force-jit   # after editing any Drift table / AppDatabase (AOT mode fails on this toolchain)
flutter test                                               # full suite (~40 test files)
flutter test test/features/smart_detection/                # single folder/file
flutter analyze
flutter build apk --release --target-platform android-arm64 --split-per-abi --obfuscate --split-debug-info=build/symbols
tool/build_release.sh                                      # same build, then copies it to Paydial-<version>-arm64.apk in the root
```
- Tests use an in-memory Drift DB plus a Linux system sqlite (`test/test_helper.dart` → `setupTestSqlite()`, which needs `libsqlite3.so`). `test/flutter_test_config.dart` points `path_provider` at a temp folder for every test. Real file I/O (e.g. a restore, which writes a safety snapshot) never completes under `testWidgets`' fake clock: wrap it in `tester.runAsync`.
- **Release signing**: `android/app/build.gradle.kts` reads `android/key.properties` (gitignored; keys `storePassword`, `keyPassword`, `keyAlias`, `storeFile`). The keystore is `~/keystores/spendwise-release.jks` (alias `spendwise`, cert SHA-256 `59:D7:2A:CC:…:44:13`) and lives outside the repo. If `key.properties` is missing, release builds fail on purpose. They never fall back to debug signing. Losing the keystore means future APKs can't update existing installs.
- **Always build releases the same way** (split arm64, command above). `--split-per-abi` sets versionCode = ABI offset + build number (arm64 → 2000 + n, armv7 → 1000 + n, x86_64 → 4000 + n), while a universal `flutter build apk` uses n alone. Installing a universal build over a split one is a downgrade, and Android just says "App not installed". Bump `version:` in `pubspec.yaml` for every release you install over an older one.
- **Settings UX rules**: keep the hub short. New options go on the matching sub-page, and the hub row's summary in `settings_screen.dart` should show the new value. No developer or troubleshooting tools in the UI. Hub providers pause while a sub-page covers the hub and resume mid-frame on return, so **don't chain hub FutureProviders on each other** (that throws "setState during build"); combine independent providers in the widget instead.
- **Branding**: the Paydial mark (a P whose bowl is a dial, needle at 1:30, notched rim) is vector source in `tool/branding/mark.svg` (+ `mark_mono.svg` for the themed-icon layer). `python3 tool/branding/render.py` (needs Chrome + ImageMagick) regenerates every launcher mipmap (foreground, monochrome, legacy), the splash `launch_image`s and `assets/images/*`. Edit the SVGs and re-render; never hand-edit the PNGs.
- `*.apk` files are gitignored. `Paydial*.apk` / `SpendWise*.apk` in the root are local build outputs.

## Stack
Flutter (Material 3) · **Riverpod 3** (`flutter_riverpod`, using `Notifier`/`AsyncNotifier`/`FutureProvider`, no codegen) · **Drift** (SQLite, `sqlite3_flutter_libs`) · `flutter_local_notifications` + `timezone` · `local_auth` (biometrics) · `crypto` (SHA-256 PIN) · `share_plus`, `file_picker`, `path_provider` · `intl` · `uuid`. Font: Outfit (static weights 400–800 in `assets/fonts`).

## Layout (feature-sliced, "clean-ish" architecture)
```
lib/
  main.dart                     App root: ProviderScope, lifecycle observer, gating (lock → language → cycle setup → shell)
  app/                          MainNavigationShell (IndexedStack, 4 tabs), FloatingDockNavBar, theme/app_theme.dart (light+dark)
  core/
    database/                   AppDatabase (schemaVersion 6), tables/*, connection (money_tracker.sqlite in app docs dir)
                                app_database.g.dart is GENERATED, never hand-edit
    date/                       BudgetCycle value object + BudgetCycleCalculator (pure)
    money/                      Money (int minor units) + AppCurrency enum, MathExpressionEvaluator (calculator in amount fields)
    localization/               AppLocalizations: hand-written en/ar getters (`isArabic ? '...' : '...'`), access via `context.l10n`
    notifications/              INotificationService / NotificationService (threshold alerts, cycle-start reminder via nextCycleReminderTime, daily evening reminder)
    providers/                  All shared Riverpod providers (db, repos, cycles, transactions, savings, currency, theme, language…)
    security/                   SecurityService (PIN), BiometricService, PinLockScreen
  features/<name>/{data,domain,presentation}/
    bills/        Recurring bills & subscriptions (confirm-first, see below): BillSchedule (pure dates), RecurringBillRepository,
                  BillService, LocalBillReminderScheduler, BillsScreen (from the Budgets app bar), DueBillsCard (dashboard)
    backup/       JSON full-DB export/import (BackupService, BackupData), optional keep-current-PIN on restore
    budgets/      BudgetCycleRepository, BudgetCalculationService (pure), ThresholdMonitor, CycleSummary/CategoryBudget,
                  BudgetsScreen (envelope manager), CycleSummaryScreen, InitialCycleSetupScreen (onboarding: start day + currency)
    categories/   Category model (expense|income), CategoryRepository (seeding, archive, delete, selection-frequency sort)
    dashboard/    DashboardScreen, hero card (balance_hero_card), near-limit / overspent alert cards, cycle switcher
    export/       CsvExportService (UTF-8 BOM for Excel, localized headers/categories)
    onboarding/   LanguageSelectionScreen
    presets/      1-tap transaction presets (TransactionPreset, PresetRepository, management screen)
    reports/      "Insights" tab: cash-flow bar chart, animated category donut chart, cycle-over-cycle (hand-drawn, no chart lib)
    savings/      SavingsVaultRepository (movement ledger), SavingsGoalRepository, SavingsGoalService, SavingsPlanner (pure),
                  SavingsSyncService, cycle closeout card (sweep split), GoalsScreen (from the dashboard vault card)
    settings/     SettingsScreen = short hub (reached from the dashboard header, not a nav tab): backup nudge,
                  rows with live summaries (settings_providers.dart), each opening presentation/pages/*:
                  budget_money, language_appearance, security, smart_detection, reminders, backup_export, about.
                  Shared widgets: SettingsPageScaffold, SettingsNavTile, BackupNudgeCard
    smart_detection/ Bank SMS/notification parsing → pending confirm-first queue (see below)
    transactions/ TransactionModel, TransactionRepository, TransactionsScreen (filters), AddEditTransactionDialog
android/app/src/main/kotlin/com/paydial/app/
    MainActivity.kt                       FlutterFragmentActivity (needed for local_auth), MethodChannel, ACTION_SEND handling
    TransactionNotificationListener.kt    NotificationListenerService: OTP/declined filter → source-app gate → keyword/strict filter
    SourceAppPolicy.kt                    Classifies the posting app (watched / SMS / other) + native strict check
    SmartDetectionStorage.kt              SharedPreferences: alert queue (while Flutter isn't running),
                                          mirrored watched/dismissed apps, suggested apps
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
| `recurring_bills` | title, type, category_id (SET NULL) + denormalized category_name, amount_minor (estimate if `is_variable`), frequency ('weekly'/'monthly'/'yearly'/'every_cycle'), `anchor_date` (first due date; sets the repeating day), `remind_days_before` (null = off), is_active |
| `savings_goals` | name, icon key, `target_minor`, `target_date` (nullable), `monthly_plan_minor` (nullable; what the closeout sweep gives it), `priority` (fill order, lower first), `achieved_at` (set the first time the balance reaches the target) |
| `savings_movements` | **the vault ledger**: signed `amount_minor`, kind ('opening'/'sweep'/'deposit'/'withdraw'/'transfer'), `goal_id` (null = Unassigned; ON DELETE SET NULL, so deleting a goal returns its money to Unassigned), `group_id` (one action's rows, undone together; sweeps use `sweep:<cycleId>`), `cycle_id` for sweeps |
| `bill_occurrences` | handled due dates: (bill_id, due_date) unique, status 'paid'/'skipped', `transaction_id` (ON DELETE CASCADE, so deleting the payment makes the date unpaid again). Due dates without a row are unpaid |

- Dates are stored as ISO strings with ASCII digits. Use `BudgetCycleCalculator.formatDate/parseDate`, which normalize Arabic/Persian digits.
- Migrations go in `AppDatabase.migration.onUpgrade` with `if (from < N)` blocks. Bump `schemaVersion`, then run build_runner. `PRAGMA foreign_keys = ON` and the transaction indexes are applied in `beforeOpen`.
- When changing the schema, also update **BackupService/BackupData** (backup = all tables) and the tests in `test/core/database/`.
- **Restore is verbatim**: never substitute defaults for saved budgets, because past cycles are frozen snapshots. `syncCategoriesForCycle` only *adds* rows for missing categories and never changes existing budgets, including zeros.
- **Restore is undoable**: `BackupService.restoreFromBackup` first saves the current data as a safety snapshot (`SafetySnapshotStore`, app support dir `safety_snapshots/`, last 3 kept) and aborts if that fails. `undoLastRestore` puts the newest snapshot back verbatim (PIN included, `last_backup_at` kept) and deletes it; the Backup page shows "Undo last restore" while one exists. The snapshot is on by default; the restore dialog's "Keep a safety copy" checkbox lets the user opt out (`takeSafetySnapshot: false`), and the warning then says the restore can't be undone.

`app_settings` keys: `last_backup_at` (device-local, kept on restore), `app_language`, `theme_mode`, `primary_currency`, `budget_cycle_start_day`, `pin_enabled`, `pin_hash`, `pin_failed_attempts`, `pin_lockout_until`, `biometrics_enabled`, `daily_reminder_enabled`, `daily_reminder_time`, `category_selection_counts` (JSON map), `savings_vault_*` (last_swept_cycle_id, last_sweep_amount_minor, last_swept_at, swept_cycles, dismissed_cycles), `smart_detection_enabled`, `smart_detection_pending_json`, `smart_detection_seen_refs_json`, `smart_detection_merchant_categories_json`, `smart_detection_watched_apps_json` (list of {packageName,label}), `smart_detection_dismissed_apps_json` (list of package names).

## Core domain rules (don't break these)
- **Money is always int minor units** (`Money.fromMinorUnits`, `inMinorUnits`). Never use doubles for amounts. Max is 999,999,999 major units. `Money.parse` accepts Arabic digits and currency symbols.
  - Separators go through `Money.normalizeSeparators`: 3-digit groups are thousands, a lone comma plus 1–2 digits is a decimal point, and when both appear the last one is the decimal. Ambiguous input is rejected, never guessed.
  - The amount calculator (`MathExpressionEvaluator`) uses exact rationals and rounds once, half away from zero. Don't reintroduce doubles.
- **Currency is global static state**: `Money.applyCurrency()` sets `Money.currentCurrency`/`defaultCurrencySymbol`. It's driven by `primaryCurrencyProvider` (EGP, SAR, AED, USD, EUR, GBP, NONE = plain numbers) and the symbol is localized by language.
- **Budget cycles**: the start day is user-chosen (1–31; it's `null` until onboarding sets it, and then the app shows `InitialCycleSetupScreen`). startDay=1 means calendar month. Otherwise a cycle runs from day N to day N−1 of the next month, **clamped** for short months and leap years. Cycles are created lazily and idempotently by `getOrCreateCycleForDate`, which snapshots each category's `defaultBudget` into `category_budgets`. Past cycles are frozen snapshots. **Cycles never overlap**:
  - `getOrCreateCycleForDate` only returns a cycle that contains the date, and shrinks new cycles to fit gaps.
  - Changing the start day calls `realignCyclesOnStartDayChange`. It keeps earlier cycles, truncates the one that straddles the new start, moves a cycle starting inside the new current cycle onto it (keeping its budgets), and deletes future cycles laid out on the old schedule. Transactions are keyed by date, so none are lost.
  - Its optional `today:` parameter exists for tests.
- **Savings auto-budget**: a "Savings"/"مدخرات" expense category gets budget = `max(0, totalIncome − Σ other budgets)`. `TransactionService` re-syncs it on transaction writes, including the old cycle when income moves cycles or changes type. Budget/category edits must still call `SavingsSyncService.syncSavingsBudgetForCycle` themselves.
- **Daily safe-to-spend** (`todaySpendingSummaryProvider`) excludes the Savings envelope (`isSavingsCategoryName`) and subtracts `committedBills`: unpaid expense bills due by the cycle end, overdue ones included (`BillSchedule.committedUntil`). The hero card's net remaining still includes both.
- **Savings Vault**: the balance is the sum of `savings_movements` (since schema 6; the old `savings_vault_balance_minor` setting is converted to an 'opening' movement by the migration **and** when restoring an older backup, via `migrateLegacyVaultBalance`). Buckets are goals plus Unassigned (goal id null); no bucket may go below zero (withdraw/transfer throw `StateError`, undo returns false). `sweepSurplus`/`undoSweep` are idempotent per cycle (swept ids stay in app_settings) and run in a transaction. When the previous cycle ended with a surplus, `pendingCycleCloseoutProvider` offers a sweep or a dismiss.
- **Savings goals**: all goal/vault money writes go through `SavingsGoalService` (`savingsGoalServiceProvider`), which marks a goal achieved the first time it reaches its target and returns `newlyAchieved` (celebrated in the UI; passing it to `undo`/`undoSweep` reverts it). The closeout's default split is `SavingsPlanner.splitSurplus`: monthly plans in priority order, never overfilling, rest to Unassigned; the user can edit it before sweeping. **Taking money out of savings never writes a transaction or touches the cycle budget.** Forecasts: `averagePerCycle` = sweeps + deposits − withdrawals over the last 3 cycles (transfers are not new saving), `requiredPerCycle` = remaining / closeouts left before the target date, on track if average ≥ required.
- **Threshold alerts**: `BudgetAlertService.reevaluate(cycle, categoryIds?)` wraps `ThresholdMonitor.evaluateAndNotify` (80% and >100%). `TransactionService` calls it for every affected expense category, old and new; budget edits call it for the whole cycle. Call it after anything that changes budgets or spending. Each alert fires once per cycle/category and is recorded in `notification_events`. Dropping back under a threshold clears the record, so the alert can fire again.
- **Recurring bills are confirm-first**: nothing is logged automatically. All bill writes go through `BillService` (`billServiceProvider`): `pay` logs via `TransactionService.add` (note = bill title, date = today) then records the occurrence; a variable bill's paid amount becomes its new estimate. Undo of a payment = `undoPay` (deletes the transaction; the FK cascade clears the occurrence). Resuming a paused bill auto-skips the dates missed while paused. Monthly/yearly dates clamp like cycles; "every cycle" follows the user's start day. Overdue dates are only looked at 366 days back. Each write reschedules reminders (one notification per bill, ids 30000–38999, `billReminderNotificationId`). UI callbacks that outlive their widget (snackbar Undo) must use `ProviderScope.containerOf`, not the widget's `ref`.
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
3. Run `_reconcileLifecycle()` (only once per calendar day on resume): seed default categories (by language), unarchive categories, get/create the current cycle, sync categories into it, sync the savings budget, schedule the cycle-start reminder, reschedule bill reminders, then trigger a refresh. This step is skipped entirely until the cycle start day is configured.

## Smart detection (Android only, confirm-first)
1. `TransactionNotificationListener` (needs notification-access permission) drops the app's own and ongoing notifications and OTP/declined/failed messages. It then **gates by source app** (`SourceAppPolicy`, generic, with no hardcoded bank list):
   - **watched** (apps the user approved in Settings → Bank & Wallet Apps): normal digit + keyword filter.
   - **SMS** (the device's default SMS app plus Google/Samsung/AOSP messaging): must also pass the **strict check**, meaning a currency-tied amount **and** an account/instrument marker (card, account, ref, balance, IPN/InstaPay, wallet, POS/ATM, بطاقة/حساب/مرجع/رصيد/محفظة…).
   - **other** (chat, email, shopping, news…): never queued. If the text looks financial, the app is recorded as a **suggestion** that the user can watch or ignore.
   - Each queued alert carries `sourceKind` (`watched`/`sms`). Rejected notifications are dropped silently: there is **no diagnostic log**. It was removed on purpose, and `purgeLegacyDiagnostics` deletes old data. Don't reintroduce one.
   - If the app is in the foreground, the alert is pushed live via MethodChannel `com.paydial.app/smart_detection` (`onAlertDetected`).
   - Otherwise it's queued in `SmartDetectionStorage` (max 50, with a 30s dedup window).
2. ACTION_SEND text/plain (sharing an SMS to the app) arrives via `onSharedText` / `consumeSharedText`. Users can also paste an SMS manually.
3. Dart side: `SmartDetectionChannel` → `SmartDetectionCoordinator` → `PendingTransactionRepository.ingestMessage`.
   - Parsing uses the offline regex-based `BankMessageParser` (Arabic + English: amount, type, merchant, reference, date).
   - The coordinator passes `strict: true` unless the alert is `watched` **and** its package is still watched. That covers SMS, unknown kinds (alerts queued before gating) and apps unwatched since queuing. Shared and pasted text is always lenient, because the user chose it.
   - **The strict regexes exist twice**: in `BankMessageParser` (`_instrumentPatterns`, currency-anchored `_amountPatterns`) and in `SourceAppPolicy.kt`. Change both together.
   - Watched/dismissed apps live in `app_settings` via `SourceAppRepository` (so they're included in backups). They're pushed to native with `setSourcePolicy` on every `syncFromNative` and every change. Suggestions are native-only (`getSuggestedApps`); `suggestedSourceAppsProvider` filters out watched and dismissed apps.
   - It dedups by signature: the reference number, otherwise type + amount + day + merchant, plus the stated time when the message has one (`ParsedBankMessage.hasExplicitTime`). It suggests a category from the learned merchant→category map.
4. Pending items show in `PendingTransactionsBanner`/`Sheet`. Confirming calls `SmartDetectionCoordinator.confirmPending`, which runs `TransactionService.add` (so alerts and savings apply as for manual entries) and then `PendingTransactionRepository.markConfirmed` (learn merchant, record dedup signature, dequeue). Nothing is auto-inserted.

Method channel methods: `isNotificationAccessEnabled`, `openNotificationAccessSettings`, `setSmartDetectionEnabled`, `consumePendingNativeAlerts`, `consumeSharedText`, `setSourcePolicy`, `getSuggestedApps`.

## Security
- **App lock is an overlay**: `MaterialApp.builder` stacks `_LockOverlay` (its own Navigator plus `PinLockScreen`) above the root Navigator whenever `isAppLockedProvider` is true. Never gate security by swapping `home`: routes, dialogs and sheets pushed earlier would stay on top. While locked, `didPopRoute` swallows the back gesture. Nothing renders until the first PIN check completes, and the app locks on `paused`/`hidden`, not only on resume.
- **PIN hash**: `app_settings.pin_hash` is a self-describing string `pbkdf2-sha256$<iterations>$<b64 salt>$<b64 hash>`:
  - PBKDF2-HMAC-SHA256 with a random 16-byte salt and 100k iterations (`SecurityService.defaultIterations`), compared in constant time.
  - Hashing runs in `Isolate.run`. Widget tests must inject `SecurityService(db, iterations: 1000, runInBackground: false)` via `securityServiceProvider.overrideWithValue`, because isolates never finish under the fake clock.
  - Legacy v1 hashes (hex SHA-256 of `"$pin:money_tracker_salt_v1"`) still verify and are re-hashed on the next successful unlock. Don't remove the legacy path.
- **Rate limiting**: always unlock or verify through `SecurityService.attemptPin`, never raw `verifyPin`, from UI:
  - 5 free attempts, then 30s doubling per failure, capped at 1h.
  - Stored in `pin_failed_attempts` / `pin_lockout_until`, so it survives restarts. The remaining time is clamped against clock rollback.
  - A correct PIN, biometric unlock or `setPin` clears it.
  - "Change PIN" requires the current PIN first. `pinCredentialSettingKeys` lists the keys restore must keep when "keep current PIN" is chosen.
- Biometric unlock goes through `local_auth` and requires `FlutterFragmentActivity`.
- **Recent-apps privacy**: Android 13+ uses `setRecentsScreenshotEnabled(false)` in `MainActivity`. Older versions draw `PrivacyCover` (`core/security/privacy_cover.dart`) whenever the app isn't resumed; the `com.paydial.app/privacy` channel reports which path applies. `FLAG_SECURE` is deliberately not used, so user screenshots still work.
- **No Android backup**: `allowBackup=false` plus `res/xml/data_extraction_rules.xml` excludes everything from cloud backup **and** device transfer (on Android 12+, `allowBackup=false` alone doesn't stop transfer).
- **Encrypted backups**: `BackupCrypto` (`features/backup/data/backup_crypto.dart`) is a JSON envelope with `format: spendwise-encrypted-backup`:
  - AES-256-GCM from `package:cryptography`, with the header as AAD; the key comes from PBKDF2-SHA256 (600k iterations) with a random salt. File iterations are capped at 5M.
  - Export offers an optional password (on by default). Restore detects the envelope (`parseBackupContent`); plain backups still import.
  - A golden v1 envelope test must keep passing.
- **Export files**: write through `ExportFileStore` (a cache `exports/` folder, pruned after 1h, plus a one-time removal of legacy exports in documents). Never write exports to the documents folder.
- **CSV**: free-text cells go through `_escapeText` (prefixes `= + - @ \t \r` with `'`). Never pass numeric cells through it.
- **Detection privacy**: the only notification text the app stores is the queued alert itself. Suggestions carry no text, and there is no diagnostic log.
- **SQL**: use drift expressions or bound variables (e.g. `like(..., escapeChar:)`), never string-built `CustomExpression`s.

## Conventions
- Every user-visible string is a getter in `AppLocalizations` with both `en` and `ar` text. Use `context.l10n.xxx` and never hardcode strings. Remember RTL and Arabic numerals.
- Colors must work in light **and** dark themes. Several tests assert theme-adaptive colors (`*_theme_test.dart`). Theme is "Pine" (`app/theme/app_theme.dart`): one builder (`AppTheme._build`) makes both modes from `AppColors`/`AppColorsDark`, so add new component styling there once. Single accent pine `#0F6B5C`/`#66D1B9` (also income); brick = overspent, amber = warning, steel blue = savings (`context.savingsColor`); neutral surfaces with hairline borders, no gradients, glows or purple. Use `context.xxxColor` getters (incl. `onPrimaryColor`, `onOverspentColor`, `onSavingsColor` for text on filled colours) and `context.chartPalette` for category charts; never hardcode `Color(0x…)`/`Colors.*` in widgets.
- Commits follow Conventional Commits: `feat(scope): …`, `fix(scope): …`, `refactor`, `chore`. Scopes are typically the feature name. Issues are referenced as `(closes #N)`.
- **Split work into focused commits by concern** (e.g. parser + tests, native Android, Dart data layer, UI + l10n, docs). Never put all changed files in one commit.
- Domain services (`BudgetCalculationService`, `BudgetCycleCalculator`, `BankMessageParser`, `Money`) are pure and unit-tested. Keep logic there rather than in widgets.
- Big screen files (reports, budgets, dashboard) still mix UI with some orchestration, such as budget, category and savings-vault edits. Transaction writes are centralized in `TransactionService`. Check the screen before assuming a non-transaction repo method handles every side effect.
- Add or update tests under `test/` mirroring `lib/`. Cross-feature flows are in `test/features/end_to_end_flow_test.dart`, `audit_regression_test.dart`, and `test/widget_test.dart`.
