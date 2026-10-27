<div align="center">

<img src="assets/images/logo.png" alt="SpendWise Logo" width="380"/>

### **Private, Offline-First Personal Finance & Cycle Budgeting for Mobile**

[![Flutter](https://img.shields.io/badge/Flutter-3.10+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Architecture](https://img.shields.io/badge/Architecture-Clean%20%2F%20Offline--First-0F5132)](https://github.com)
[![Database](https://img.shields.io/badge/SQLite-Drift%20ORM-003B57?logo=sqlite&logoColor=white)](https://drift.simonbinder.eu)
[![Tests](https://img.shields.io/badge/Tests-165%20Passing%20(100%25)-16A34A?logo=checkmarx&logoColor=white)](test/)
[![Security](https://img.shields.io/badge/Security-SHA--256%20%2B%20Biometrics-darkgreen)](lib/core/security/)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

---

**SpendWise** is a privacy-centric personal finance management application engineered for modern budgeting habits. Unlike conventional trackers tied to standard calendar months, SpendWise aligns directly with real-world income schedules (such as 25th-of-the-month paydays) with automated month-end clamping, exact integer financial arithmetic, dynamic surplus sweeping, and bank-grade biometric protection.

</div>

---

## 🌟 Key Highlights

### 🔒 100% Offline & Private
- **Zero Cloud Dependency**: Operates entirely offline with a local, hardened SQLite database via [Drift](https://drift.simonbinder.eu).
- **No Telemetry or Tracking**: Your financial data never leaves your device. No analytics, no ads, no external servers.
- **Biometric & PIN Lock**: Encrypted SHA-256 salted PIN protection with device biometric (fingerprint / face) unlock and automatic 30-second lockout throttling after repeated failures.

### 📅 Discrete Budget Cycle Engine
- **Payday Alignment**: Configure custom cycle start days (e.g., the 25th) or traditional calendar months (the 1st).
- **Intelligent Calendar Transitions**: Automatic clamping for variable month lengths (28, 29, 30, and 31 days) with leap year awareness (e.g., February 29 vs 28).
- **Immutable Historical Cycles**: Past budget cycles remain frozen snapshots unaffected by future budget changes.

### 💰 Exact Financial Precision
- **Zero Floating-Point Drift**: All monetary operations use minor units (piastres / cents) as 64-bit integers, completely eliminating IEEE-754 precision bugs.
- **Embedded Calculator**: Dynamic mathematical expression evaluator (`BODMAS` / `PEMDAS`) built right into transaction input fields.
- **Bilingual Numerals**: Native support for Western Arabic (`0-9`), Eastern Arabic (`٠-٩`), and Persian (`۰-۹`) numerals and separators.

### 🏦 Dynamic Savings Vault
- **Surplus Sweeping**: Automatically calculates leftover funds at the end of each cycle and offers a 1-tap sweep into a persistent Savings Vault with soft undo.
- **Unallocated Income Rebalancing**: Automatically allocates unbudgeted income straight to your Savings category.
- **Manual Deposits & Withdrawals**: Track manual contributions and emergency withdrawals with overdraft protection.

### ⚡ Speed & Daily Workflow
- **1-Tap Quick Presets**: Pin frequent expenses and income sources (e.g., "Coffee", "Salary", "Metro") for rapid 1-tap logging directly from the dashboard.
- **Instant SnackBar Undo**: Deleted transactions and preset logs can be instantly restored in a single tap.
- **Proactive Threshold Alerts**: Real-time local Android notifications when category spending hits 80% and 100% of budgeted limits.

### 🌍 Comprehensive Localization (العربية / English)
- Complete bilingual UI with right-to-left (RTL) support and locale-aware typography.
- Dynamic currency formatting (`EGP` in English, `ج.م` in Arabic).
- Pre-seeded starter categories customized by selected language.

### 💾 Open Data Portability
- **Encrypted JSON Backups**: Full database snapshot export and restore with schema validation and PIN preservation options.
- **CSV Spreadsheets**: Export clean transaction ledgers and category cycle breakdowns formatted for spreadsheet analysis (Excel, Google Sheets).

---

## 🏗️ Architecture & Technology Stack

SpendWise is structured following **Clean Architecture** and **Domain-Driven Design (DDD)** principles:

```text
lib/
├── app/                  # Main navigation shell, route scaffolding, and theme system
├── core/                 # Shared foundation across all feature modules
│   ├── database/         # SQLite tables, connection layer, and Drift migrations (v1-v4)
│   ├── date/             # BudgetCycle value object and cyclic calendar calculation engine
│   ├── localization/     # Bilingual AppLocalizations dictionary (English & Arabic RTL)
│   ├── money/            # Exact Money value object and BODMAS math expression parser
│   ├── notifications/    # Local notification service and periodic cycle alarms
│   ├── providers/        # Core Riverpod state management and lifecycle hooks
│   └── security/         # SHA-256 PIN security and biometric authentication service
└── features/             # Independent, domain-isolated feature slices
    ├── backup/           # JSON database export/import and schema validation
    ├── budgets/          # Category budget tracking, cycle summaries, and threshold monitoring
    ├── categories/       # Category domain model, icon/color customization, and starter seeds
    ├── dashboard/        # Dashboard overview, cycle progress, and 1-tap preset bar
    ├── export/           # Spreadsheet-ready CSV export engine
    ├── onboarding/       # Language selection, welcome tour, and initial cycle wizard
    ├── presets/          # User-defined transaction shortcuts with category cascades
    ├── reports/          # Month-over-Month Cash Flow comparisons and category distribution
    ├── savings/          # Savings vault repository, surplus closeout, and income rebalancing
    ├── settings/         # App preferences, security toggles, and data export
    └── transactions/     # Transaction ledger, date-grouped filtering, and add/edit modals
```

### Core Libraries
- **Framework**: [Flutter](https://flutter.dev) (Material 3)
- **State Management**: [Riverpod](https://riverpod.dev) (`flutter_riverpod`)
- **Database & Persistence**: [Drift](https://drift.simonbinder.eu) (SQLite) with `sqlite3_flutter_libs`
- **Security**: [crypto](https://pub.dev/packages/crypto) (SHA-256) & [local_auth](https://pub.dev/packages/local_auth)
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

SpendWise includes a comprehensive automated test suite covering unit math, database integrity, edge cases, cycle transitions, and end-to-end user workflows:

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
*Output: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (~22.7 MB)*

---

## 🎨 Brand Identity

The official **SpendWise "Luxury Vault & Velvet Titanium"** brand identity features **The Luxury Vault Wheel** in a symmetrical `'X'` spoke configuration crafted in brushed Champagne Gold with a minimal Velvet Crimson ruby center core—symbolizing private offline wealth protection and precision cyclic budgeting.

- **Obsidian Matte Black**: `#0B0B0E` (Vault Foundation & Elevated Titanium Surfaces `#14141B`)
- **Champagne Gold**: `#E5C158` / `#B38A24` (Primary Brand Accent & Pace Ring Gauge)
- **Velvet Crimson & Porcelain White**: `#7B1123` (Ruby Core & Ambient Hero Mesh) / `#F8FAFC` (Clarity & Readability)

The logo is optically aligned across all standard and adaptive Android icon densities (`mdpi`, `hdpi`, `xhdpi`, `xxhdpi`, `xxxhdpi`) and provides instant native launch branding with zero white splash flicker.

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
