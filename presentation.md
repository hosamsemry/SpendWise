# SpendWise — Official Presentation Deck

> **Presentation Resources**:
> - 🌐 **[presentation.html](file:///home/hosam/Desktop/projects/money_tracker/presentation.html)** (Interactive Web Slide Deck with Arrow Key Navigation)
> - 📊 **[SpendWise_Presentation.pptx](file:///home/hosam/Desktop/projects/money_tracker/SpendWise_Presentation.pptx)** (Microsoft PowerPoint / Google Slides / LibreOffice Impress)
> - 📄 **[SpendWise_Presentation.pdf](file:///home/hosam/Desktop/projects/money_tracker/SpendWise_Presentation.pdf)** (Printable PDF Document)
> - 🐙 **[GitHub Repository](https://github.com/hosamsemry/SpendWise)** (Open Source under Apache License 2.0)

---

## 10-Slide Outline & Detailed Speaker Notes

### Slide 1: Welcome to SpendWise
* **Title**: SpendWise — Private, Payday-Aligned Personal Finance
* **Tagline**: Master your daily spending with zero cloud friction, instant 1-tap presets, and real-life 25th-to-24th salary cycles.
* **Key Metrics**:
  - **100% Offline & Private**: Local Drift SQLite, zero telemetry, zero analytics.
  - **Payday-Aligned Cycles**: 25th-to-24th salary tracking or traditional calendar month.
  - **< 1s 1-Tap Presets**: Instant ledger logging with 3-second soft undo.
  - **162 / 162 Automated Tests**: 100% green verification across unit, database, and integration suites.
  - **Apache License 2.0**: Fully open-source on GitHub (`hosamsemry/SpendWise`).

---

### Slide 2: Why Traditional Budgeting Apps Fail
* **The 3 Critical Friction Points**:
  1. **The "1st of the Month" Fallacy**: Forcing budgets into standard calendar months when salaries arrive on the 25th creates artificial deficits and month-end confusion.
  2. **High Entry Friction**: Requiring 4–5 screens, dropdowns, and date pickers for a single coffee causes users to abandon tracking within two weeks.
  3. **Cloud Bloat & Privacy Liabilities**: Forced accounts, third-party analytics SDKs, 150MB+ app sizes, and bank credential sharing compromise personal financial privacy.

---

### Slide 3: The SpendWise Solution & Architecture
* **Four Foundational Pillars**:
  - **Discrete Payday Cycles**: Automatic clamping for February and short months (28/29/30/31 days) with leap year awareness. Past cycles remain immutable snapshots.
  - **100% On-Device SQLite**: Local persistence via Drift ORM. Instant cold boot, works in airplane mode with zero external server dependencies.
  - **Exact Minor-Unit Arithmetic**: 64-bit integer calculations (piastres / cents) eliminating IEEE-754 floating-point drift, with an embedded BODMAS expression calculator.
  - **Dynamic Savings Vault**: Automatically reconciles unspent money and routes surplus straight to savings.

---

### Slide 4: 1-Tap Daily Quick Presets & Soft Undo
* **Frictionless Daily Logging**:
  - Direct recording from home screen preset chips (e.g., `Espresso • 45.00 EGP`, `Lunch • 120.00 EGP`, `Metro • 12.00 EGP`).
  - Non-intrusive floating SnackBar with a 3-second **Undo** action for effortless recovery from accidental taps.
  - Tactile haptic feedback on preset taps.
  - Real-time budget threshold evaluation on every tap to prevent accidental overspending.

---

### Slide 5: Daily Spending Clarity & Dynamic Safe Pace
* **Real-Time Financial Awareness**:
  - **Today's Spending Card**: Instant anchor showing today's total spent amount and transaction count.
  - **Dynamic Safe Pace Algorithm**:
    $$\text{Safe Daily Pace} = \frac{\text{Net Remaining Budget in Cycle}}{\text{Days Remaining until Next Payday}}$$
  - **DST-Immune Calculations**: Computed using normalized `DateTime.utc` arithmetic to eliminate 1-day rounding errors during daylight saving time shifts.
  - **Chronological Day Headers**: Grouped transactions under clean date headers (`Today`, `Yesterday`, `22 Oct`) with daily spend totals.

---

### Slide 6: The Savings Vault & Surplus Sweeper
* **Automated Wealth Accumulation**:
  - **End-of-Cycle Surplus Sweeper**: Prominent dashboard banner appears when a cycle finishes with surplus, allowing a 1-tap sweep into the vault.
  - **Persistent Vault Ledger**: Tracks accumulated savings across all historical cycles; tracks manual deposits and emergency withdrawals with overdraft protection.
  - **Unallocated Income Auto-Rebalancing**: If income exceeds category budget limits, the unallocated difference automatically rebalances into a dedicated Savings category.

---

### Slide 7: Native Bilingual Experience (العربية / English)
* **First-Class Arabic & RTL**:
  - Full right-to-left (RTL) layout symmetry across all screens, charts, and navigation bars.
  - Clean language selector with clear bilingual cards (`English` / `العربية`).
  - Automatic currency symbol formatting (`EGP` in English, `ج.م` in Arabic).
  - Native parsing of Eastern Arabic (`٠١٢٣٤٥٦٧٨٩`) and Persian (`۰۱۲۳۴۵۶۷۸۹`) numerals and decimal separators (`٫`).
  - Pre-seeded localized starter categories based on selected language.

---

### Slide 8: Bank-Grade Security & Open Portability
* **Hardware-Backed Privacy & Zero Lock-In**:
  - **SHA-256 Salted PIN Lock**: Cryptographically hashed; raw PIN is never stored.
  - **Biometric Integration**: Instant fingerprint and face unlock via `local_auth`.
  - **Lifecycle-Aware State Protection**:
    - *Swiping status bar / control center (`inactive`)*: Remains unlocked without annoying interruptions.
    - *Leaving app or locking screen (`paused`)*: Immediately locks session, requiring authentication upon return.
  - **Offline JSON Backup & Restore**: Export complete SQLite state to JSON with schema versioning and optional PIN preservation.
  - **Clean Decimal CSV Export**: Unformatted numbers (`1250.00`) without comma separators for seamless Excel and Google Sheets import.

---

### Slide 9: Technical Architecture & 162 Automated Tests
* **Production Stack**:
  - **Framework**: Flutter 3.x / Dart 3.x
  - **State Management**: Riverpod 2 (Notifier architecture with unidirectional data flow)
  - **Database**: Drift (Type-safe SQLite ORM with migrations v1–v4)
  - **Code Quality**: `flutter analyze` $\to$ **0 issues found**
  - **Verification**: **162 / 162 automated tests passing** (financial math, date engine, multi-cycle sweep, category cascades, threshold pruning, and biometric lockouts)
  - **Binary Sizes**: **22.7 MB** (ARM64 release APK) / **62.1 MB** (Universal release APK)

---

### Slide 10: Open Source & Product Roadmap
* **Production-Ready v1.0.0**:
  - Licensed under **Apache License 2.0**.
  - Public repository: [github.com/hosamsemry/SpendWise](https://github.com/hosamsemry/SpendWise).
* **Future Horizons (v1.1+)**:
  - **Auto-Recurring Fixed Bills**: Automatic scheduling for monthly rent or utilities on specific cycle days.
  - **Multi-Currency Selector**: Expanding beyond EGP to support USD, SAR, AED, and EUR.
  - **Interactive Donut Charts**: Drilldown category spending visualizations in Reports.
  - **Receipt Attachments**: Local storage of receipt and invoice images.
