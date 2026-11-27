<div align="center">

<img src="assets/images/logo.png" alt="Paydial Logo" width="380"/>

### **Private, Offline-First Personal Finance & Cycle Budgeting for Mobile**

[![Flutter](https://img.shields.io/badge/Flutter-3.10+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Architecture](https://img.shields.io/badge/Architecture-Clean%20%2F%20Offline--First-0F5132)](https://github.com)
[![Database](https://img.shields.io/badge/SQLite-Drift%20ORM-003B57?logo=sqlite&logoColor=white)](https://drift.simonbinder.eu)
[![Tests](https://img.shields.io/badge/Tests-391%20Passing%20(100%25)-16A34A?logo=checkmarx&logoColor=white)](test/)
[![Security](https://img.shields.io/badge/Security-PBKDF2%20%2B%20AES--256--GCM%20%2B%20Biometrics-darkgreen)](lib/core/security/)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

---

**Paydial** is a privacy-centric personal finance management application engineered for modern budgeting habits. Unlike conventional trackers tied to standard calendar months, Paydial aligns directly with real-world income schedules (such as 25th-of-the-month paydays) with automated month-end clamping, exact integer financial arithmetic, dynamic surplus sweeping, and bank-grade biometric protection.

</div>

---

## 🌟 Key Highlights

### 🔒 100% Offline & Private
- **Zero Cloud Dependency**: Operates entirely offline with a local SQLite database via [Drift](https://drift.simonbinder.eu). App data is excluded from Android cloud backup and device-to-device transfer.
- **No Telemetry or Tracking**: Your financial data never leaves your device unless you export it. No analytics, no ads, no external servers, no internet permission.
- **Biometric & PIN Lock**: PIN stored as a salted PBKDF2-HMAC-SHA256 hash, with device biometric (fingerprint / face) unlock. The lock covers every open screen, and after 5 wrong PINs an escalating lockout (30s doubling up to 1h) applies that survives app restarts.
- **Private App Switcher**: Balances are hidden from the recent-apps preview while your own screenshots keep working.

### 📅 Discrete Budget Cycle Engine
- **Payday Alignment**: Configure custom cycle start days (e.g., the 25th) or traditional calendar months (the 1st).
- **Intelligent Calendar Transitions**: Automatic clamping for variable month lengths (28, 29, 30, and 31 days) with leap year awareness (e.g., February 29 vs 28).
- **Immutable Historical Cycles**: Past budget cycles remain frozen snapshots unaffected by future budget changes.

### 💰 Exact Financial Precision
- **Zero Floating-Point Drift**: All monetary operations use minor units (piastres / cents) as 64-bit integers, completely eliminating IEEE-754 precision bugs.
- **Embedded Calculator**: Mathematical expression evaluator (`BODMAS` / `PEMDAS`) built right into amount fields, using exact rational arithmetic and rounding only once.
- **Unambiguous Amount Parsing**: `1,250` is one thousand two hundred fifty and `12,5` is twelve and a half. Input that could mean either is rejected instead of guessed.
- **Bilingual Numerals**: Native support for Western Arabic (`0-9`), Eastern Arabic (`٠-٩`), and Persian (`۰-۹`) numerals and separators.

### 🏦 Savings Vault & Goals
- **Savings Goals**: Split your vault into goals like Eid, a car or an emergency fund, each with a target, an optional date and a plan per cycle. Whatever isn't given to a goal stays Unassigned.
- **Surplus Sweeping**: At the end of each cycle, Paydial offers to sweep what's left into the vault. Goals get their monthly plan first, in the order you drag them into, and the rest goes to Unassigned. You can change the split before sweeping, and undo it.
- **On Track or Behind**: Each goal shows its progress, what it needs per cycle to hit its date, and when you'll reach it at your recent pace.
- **Full History**: Every amount added, taken out or moved is recorded, with Undo, and nothing can go below zero.
- **Outside Your Budget**: Spending saved money doesn't count against the current cycle, because it was saved in earlier ones.
- **Unallocated Income Rebalancing**: Automatically allocates unbudgeted income straight to your Savings category.

### ⚡ Speed & Daily Workflow
- **Daily Safe-to-Spend**: The dashboard shows how much you can spend today to finish the cycle on budget, with a pace gauge that warns when you are spending faster than planned. The Savings envelope is left out so it is never treated as spending money.
- **1-Tap Quick Presets**: Pin frequent expenses and income sources (e.g., "Coffee", "Salary", "Metro") for rapid 1-tap logging directly from the dashboard.
- **Instant SnackBar Undo**: Deleted transactions and preset logs can be instantly restored in a single tap.
- **Proactive Threshold Alerts**: Local Android notifications when a category reaches 80% and 100% of its budget. Alerts are re-checked whenever a budget is edited, and fire again if spending drops back under a threshold and crosses it later.
- **Reminders**: An optional daily evening reminder to log the day's spending, and a reminder on your cycle start day.

### 🧾 Bills & Subscriptions
- **Recurring Bills and Income**: Rent, subscriptions, phone and internet, or your salary, repeating weekly, monthly, yearly, or **every cycle** on your payday.
- **Confirm-First**: Bills due this week appear on the dashboard with **Paid** and **Skip**. Nothing is logged without your tap, and every payment can be undone.
- **Variable Amounts**: Electricity or mobile bills ask for the amount when you pay, pre-filled with last time's.
- **Safe to Spend After Bills**: Unpaid bills due before the cycle ends are set aside from your daily safe-to-spend, so money already promised is never shown as free.
- **Reminders**: A notification on the due date or 1, 3 or 7 days before, plus a monthly total of what your bills cost.

### 📩 Smart Bank Message Detection (Android)
- **Confirm-First**: Bank SMS and banking-app notifications become pending transactions you confirm or dismiss. Nothing is added without your tap.
- **Egypt & GCC Banks**: An offline parser reads Arabic and English messages from InstaPay/IPN, CIB, NBE, Banque Misr, AAIB, QNB and mobile wallets: amount, type, merchant, reference and date.
- **You Choose the Sources**: Only apps you approve are read normally. SMS must pass a strict check (a currency amount plus a card, account or reference marker), and chat, email and shopping apps are never read. Apps that look financial are suggested for you to approve or ignore.
- **Learns Your Categories**: Confirmed merchants are remembered and suggested next time, and duplicate messages are detected by reference number or amount, day and merchant.
- **Share or Paste**: Share an SMS to Paydial or paste it in by hand. No message text is stored beyond the pending queue.

### 📊 Insights
- **Cash Flow**: Income vs. expenses across the last six cycles.
- **Category Breakdown**: An animated donut chart of where the money went.
- **Cycle Over Cycle**: Compare each category against the previous cycle. All charts are drawn by the app, with no chart library.

### 🌍 Comprehensive Localization (العربية / English)
- Complete bilingual UI with right-to-left (RTL) support and locale-aware typography.
- Multi-currency: EGP, SAR, AED, USD, EUR, GBP, or plain numbers, with the symbol localized (`EGP` in English, `ج.م` in Arabic).
- Pre-seeded starter categories customized by selected language.

### 💾 Open Data Portability
- **Password-Protected Backups**: Full database snapshot export and restore, encrypted with AES-256-GCM (PBKDF2-derived key) when you set a password, with schema validation and PIN preservation options.
- **Backup Reminder**: Settings shows when you last backed up and nudges you when a backup is overdue.
- **CSV Spreadsheets**: Export clean transaction ledgers and category cycle breakdowns formatted for spreadsheet analysis (Excel, Google Sheets).

### 🎛️ Look & Settings
- **Light & Dark Themes**: Quiet neutral surfaces with a single pine accent, in a soft off-white light mode and a soft charcoal dark mode, following the system or set by hand.
- **Settings at a Glance**: A short settings hub where each row shows its current value (cycle start and currency, language and theme, lock, smart detection, reminders, last backup), with details on focused sub-pages.

---

## 🏗️ Architecture & Technology Stack

Paydial is structured following **Clean Architecture** and **Domain-Driven Design (DDD)** principles:

```text
lib/
├── app/                  # Main navigation shell, route scaffolding, and theme system
├── core/                 # Shared foundation across all feature modules
│   ├── database/         # SQLite tables, connection layer, and Drift migrations (v1-v6)
│   ├── date/             # BudgetCycle value object and cyclic calendar calculation engine
│   ├── localization/     # Bilingual AppLocalizations dictionary (English & Arabic RTL)
│   ├── money/            # Exact Money value object and BODMAS math expression parser
│   ├── notifications/    # Local notification service and periodic cycle alarms
│   ├── providers/        # Core Riverpod state management and lifecycle hooks
│   └── security/         # PBKDF2 PIN hashing, lockout, biometrics and app-switcher privacy cover
└── features/             # Independent, domain-isolated feature slices
    ├── backup/           # JSON database export/import and schema validation
    ├── bills/            # Recurring bills & subscriptions, reminders, and the due-soon card
    ├── budgets/          # Category budget tracking, cycle summaries, and threshold monitoring
    ├── categories/       # Category domain model, icon/color customization, and starter seeds
    ├── dashboard/        # Dashboard overview, cycle progress, and 1-tap preset bar
    ├── export/           # Spreadsheet-ready CSV export engine
    ├── onboarding/       # Language selection, welcome tour, and initial cycle wizard
    ├── presets/          # User-defined transaction shortcuts with category cascades
    ├── reports/          # Month-over-Month Cash Flow comparisons and category distribution
    ├── savings/          # Savings vault ledger, goals, surplus closeout split, and income rebalancing
    ├── settings/         # Settings hub with live summaries and grouped sub-pages
    ├── smart_detection/  # Bank SMS / notification parsing and the confirm-first queue
    └── transactions/     # Transaction ledger, date-grouped filtering, and add/edit modals
```

### Core Libraries
- **Framework**: [Flutter](https://flutter.dev) (Material 3)
- **State Management**: [Riverpod](https://riverpod.dev) (`flutter_riverpod`)
- **Database & Persistence**: [Drift](https://drift.simonbinder.eu) (SQLite) with `sqlite3_flutter_libs`
- **Security**: [crypto](https://pub.dev/packages/crypto) (PBKDF2-HMAC-SHA256), [cryptography](https://pub.dev/packages/cryptography) (AES-256-GCM backups) & [local_auth](https://pub.dev/packages/local_auth)
- **Notifications**: [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications)
- **Internationalization**: [intl](https://pub.dev/packages/intl) & `flutter_localizations`

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`^3.10.4` or newer)
- [Dart SDK](https://dart.dev/get-dart) (`^3.0.0`)
- [Java Development Kit](https://openjdk.org) (JDK 17 recommended for Android Gradle builds)
- Android Studio / VS Code with Flutter extension

### Installation

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd money_tracker
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run code generation** *(if modifying Drift database schemas)*:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. **Launch the application**:
   ```bash
   flutter run
   ```

---

## 🧪 Testing & Quality Assurance

Paydial includes a comprehensive automated test suite covering unit math, database integrity, edge cases, cycle transitions, and end-to-end user workflows:

```bash
# Run all unit, widget, and integration tests
flutter test

# Run static analysis
flutter analyze
```

### Test Coverage Highlights:
- **Financial Math**: `Money` minor-unit precision, arithmetic operations, and Eastern Arabic parsing.
- **Cycle Engine**: Short month clamping, leap year boundaries, and discrete date range containment.
- **Data Integrity**: Foreign key constraints, cascade safety on category deletion/rename, and idempotent cycle initialization.
- **Threshold Monitor**: Proactive 80% & 100% notification dispatch and obsolete event pruning.
- **End-to-End**: Multi-cycle workflows, surplus sweeping, backup roundtripping, and biometric lockouts.

---

## 📦 Building Production Release Binaries

To produce optimized, tree-shaken, and obfuscated release APKs:

### 1. Universal Release APK
```bash
flutter build apk --release --obfuscate --split-debug-info=build/symbols
```
*Output: `build/app/outputs/flutter-apk/app-release.apk` (~62 MB)*

### 2. ARM64 Optimized Split APK
```bash
flutter build apk --release --target-platform android-arm64 --split-per-abi --obfuscate --split-debug-info=build/symbols
```
*Output: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (~23 MB)*

Or run the same build through the release script, which also saves a named copy in the project root:
```bash
tool/build_release.sh
```
*Output: `Paydial-<version>-arm64.apk`, e.g. `Paydial-2.2.0+10-arm64.apk`*

---

## 🎨 Brand Identity

<img src="assets/images/logo_emblem.png" alt="Paydial emblem" width="96"/>

The **Paydial** mark is a "P" whose bowl is a dial. Its gauge needle sits at half past one, creeping toward payday, and the notch at the top of the thin outer rim marks the start of each budget cycle. It is drawn from flat shapes only, so it stays legible at 24 px and works in a single colour. The Arabic name is «باي دايل».

- **Pine**: `#0F6B5C` light / `#66D1B9` dark (the one accent: buttons, selection, income, cycle progress); `#0D5A4E` icon tile
- **Neutrals**: off-white `#F6F6F3` / white cards in light mode, charcoal `#1A1D20` / `#23272B` in dark mode, near-black `#15171A` ink
- **Meaning colours**: brick `#BF3A2C` for overspending, amber `#9E5700` for warnings, steel blue `#2D5F8A` for savings. No purple, no gradients or glows

The launcher icon is an Android adaptive icon with a monochrome layer for Android 13+ themed icons. Every icon, splash and logo PNG is rendered from the SVG sources in [`tool/branding/`](tool/branding/):

```bash
python3 tool/branding/render.py   # needs Google Chrome and ImageMagick
```

---

## 📄 License & Attribution

Copyright © 2026 Hosam. All rights reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the [LICENSE](LICENSE) file for the full text.
