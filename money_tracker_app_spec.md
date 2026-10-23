# Personal Money Tracker — Product & Implementation Specification

**Document purpose:** This is the source of truth for an IDE coding agent to break the application into implementation tasks and build it.

**Product type:** Personal, single-user Flutter application  
**Platform:** Android first; keep the Flutter codebase portable  
**Language:** English  
**Storage:** Local SQLite database only  
**Currency:** EGP as the initial/default currency  
**Backend / accounts / cloud sync:** None

---

## 1. Product goal

Build a simple personal finance tracker that lets the user:

1. Record one-time income.
2. Record expenses against user-created categories.
3. Define fixed budget amounts for categories.
4. Automatically calculate category spending and remaining budget.
5. Run budget periods from the 25th of one month through the 24th of the next month.
6. Review a completed period's unused budget and overspending on the 25th.
7. View a dashboard and a small set of useful spending reports.

The application must be easy to use for frequent expense entry. Avoid features that are not specified in this document.

## 2. Confirmed product decisions

| Topic | Requirement |
|---|---|
| User model | One personal user; no sign-up or login |
| Income | One-time income transactions only |
| Expenses | One-time expense transactions only |
| Categories | User creates and manages categories |
| Expense fields | Amount, category, date, note |
| Income fields | Amount, category, date, note |
| Budget cycle | 25th through 24th, inclusive |
| Budget setup | User defines category allocation amounts initially |
| Repeating budgets | Reuse the saved allocation amounts for each new cycle |
| Budget adjustments | User can edit a cycle's budget amounts |
| Income changes | Do not automatically change budgets when income differs; user manually decides whether to adjust budgets |
| Accounts / wallets | Not required |
| Transfers | Not required |
| Recurring transactions | Not required |
| Savings / investments | Represent them as ordinary user-created categories with budget amounts and expense transactions, not as separate financial entities |
| Budget carryover | Do not automatically carry unused amounts into the next cycle |
| Overspending | Allowed; remaining budget can be negative |
| Cycle summary | Show both (a) sum of positive remaining amounts and (b) net remaining amount after negative category balances |
| Notifications | Local notification on the 25th; category warning at 80%; over-budget notification |
| Transaction management | Edit, delete, filter by category/date, and search notes |
| Reports | Spending by category; budget vs. actual spending |
| Data | SQLite on device; no cloud sync |
| Language | English |

## 3. Core terminology and date rules

### 3.1 Budget cycle

A budget cycle starts on the 25th of a month and ends on the 24th of the following month, inclusive.

Examples:

- 25 October 2026 – 24 November 2026
- 25 November 2026 – 24 December 2026

A transaction belongs to the cycle determined by its transaction date, not by the date on which it was entered.

### 3.2 Cycle calculation

For a date `d`:

- If `day(d) >= 25`, cycle start is the 25th of `d`'s month.
- Otherwise, cycle start is the 25th of the previous month.
- Cycle end is the day before the next cycle start (the 24th of the next month).

Use calendar-date comparisons, not elapsed-hour calculations. Handle year changes and month lengths correctly.

Store transaction dates as local calendar dates in a consistent format (recommended: ISO `YYYY-MM-DD`). Do not let UTC conversion shift a transaction into the previous or next calendar day.

### 3.3 Current cycle

The current cycle is the cycle containing today's local device date.

The app must derive the current cycle from the device date whenever it opens or resumes. Do not assume that the app was running at midnight or on the 25th.

## 4. Budget allocation model

### 4.1 Allocation templates

The user defines a default allocation amount for each category. These amounts are the default budget for that category in every new cycle.

Example:

| Category | Default allocation |
|---|---:|
| Food | 2,000 EGP |
| Transportation | 1,000 EGP |
| Social life | 500 EGP |
| Gym | 1,000 EGP |
| Savings | 3,000 EGP |
| Investments | 2,000 EGP |

These are category budget amounts. Savings and investments are not special transaction types; if the user wants to record money allocated/spent in those categories, they create ordinary expense transactions under those categories.

### 4.2 Initial setup

On first use, guide the user through:

1. Create one or more categories.
2. Set a default allocation amount for each category.
3. Save the setup.
4. Create the initial budget cycle's category budgets from those amounts.

Allow the user to skip setting an allocation for a category; treat a missing allocation as zero until configured.

### 4.3 Creating each new cycle

When a new cycle begins on the 25th:

1. Detect that the current cycle has no budget-cycle record.
2. Create the cycle.
3. Copy each category's current default allocation amount into a cycle-specific budget record.
4. Do not create income transactions automatically.
5. Do not change budget amounts based on income received.
6. Do not carry unused or overspent amounts forward.
7. Show a local notification reminding the user to review/set the new cycle's budget.

The new cycle must be created idempotently: opening the app multiple times must not create duplicate cycles or duplicate category budgets.

### 4.4 Editing budgets

The user can edit category budget amounts for a specific cycle.

Also provide a clear way to update a category's default allocation amount for future cycles. Changing a default must not silently modify already-created historical cycles or the current cycle.

If the user changes a cycle budget directly, clarify in the UI that this changes only that cycle unless they also update the default allocation.

### 4.5 Categories and budgets

- Each expense must belong to one category.
- Each category may have a default allocation amount.
- A category can have a zero budget and still be used for recording expenses.
- Deactivating a category must not delete its historical transactions or budget history.
- Do not allow deletion of a category that has transactions or historical budgets unless a safe reassignment flow is implemented. Prefer archive/deactivate for used categories.
- Category names should be unique after trimming whitespace and comparing case-insensitively.

## 5. Financial calculations

Use integer minor units for money (for EGP, store piastres as an integer) or another exact decimal-safe representation. Do not use binary floating-point for persisted monetary values or financial calculations.

For each category and cycle:

- `budgeted_amount` = budget amount for that category in that cycle.
- `spent_amount` = sum of expense transactions assigned to that category whose transaction dates fall inside the cycle.
- `remaining_amount` = `budgeted_amount - spent_amount`.
- `usage_percentage` = `spent_amount / budgeted_amount * 100`, when budget is greater than zero.

Rules:

- Negative remaining amounts are valid and must be displayed.
- A zero budget must not cause division-by-zero. Show usage as unavailable or use a clear zero-budget state; still show the amount spent and negative remaining amount if spending exists.
- Income does not reduce category spending and is not automatically allocated.
- Savings and investments category expenses count as expenses in totals, because they are intentionally modelled as ordinary categories.
- Editing or deleting a transaction must immediately update all affected totals and reports.
- A transaction entered later with a date in a previous cycle must update that historical cycle's calculations.

### 5.1 Cycle summary totals

At the end of a cycle, calculate and display:

- `total_budgeted`: sum of all category budgets in the cycle.
- `total_spent`: sum of all expense transactions in the cycle.
- `positive_unused_total`: sum of only positive category remaining amounts.
- `net_remaining_total`: sum of all category remaining amounts, including negative values.
- `overspent_categories_count`: number of categories with negative remaining amounts.

Example:

| Category | Budget | Spent | Remaining |
|---|---:|---:|---:|
| Food | 2,000 | 1,500 | +500 |
| Transport | 1,000 | 700 | +300 |
| Social life | 500 | 700 | -200 |
| Gym | 1,000 | 100 | +900 |
| **Total** | **4,500** | **3,000** | **+1,500 net** |

For this example:

- Positive unused total = 500 + 300 + 900 = 1,700 EGP.
- Net remaining total = 500 + 300 - 200 + 900 = 1,500 EGP.

Show both values with clear labels. Do not label the positive-only total as overall savings or actual cash balance.

### 5.2 Income totals

For a selected cycle, total income is the sum of income transactions whose dates fall inside that cycle.

The dashboard may show income and expenses for the current cycle, but do not infer a bank balance because the app does not track accounts, transfers, or opening balances.

## 6. Transactions

### 6.1 Transaction types

Only two transaction types are required:

- Income
- Expense

No account, wallet, transfer, debt, or recurring transaction model is required.

### 6.2 Expense fields

Required:

- Amount
- Category
- Date

Optional:

- Note

Validation:

- Amount must be greater than zero.
- Category is required.
- Date is required and defaults to today.
- Note may be empty.
- Amount input must support decimal values appropriate for EGP.
- Show a clear validation message for invalid values.

### 6.3 Income fields

Required:

- Amount
- Date

Optional / Supported:

- Category (user can assign an income category or leave uncategorized)
- Note

Validation:

- Amount must be greater than zero.
- Date is required and defaults to today.
- Category may be specified or omitted.
- Note may be empty.

### 6.4 Transaction operations

Implement:

- Add income.
- Add expense.
- View transaction history.
- Edit a transaction.
- Delete a transaction after confirmation.
- Filter by transaction type.
- Filter by category.
- Filter by date range / budget cycle.
- Search transaction notes (case-insensitive substring search is sufficient).

Transaction history should be ordered by transaction date descending, then creation timestamp descending.

### 6.5 Transaction date and cycle assignment

Do not permanently store a cycle ID on a transaction unless there is a compelling implementation reason. The cycle is derivable from the transaction date. If a cycle ID is stored for query performance, keep it consistent when the transaction date is edited.

## 7. Required screens and navigation

Use a simple bottom navigation or similarly clear navigation with these primary areas:

1. Dashboard
2. Transactions
3. Budgets
4. Reports
5. Settings / Categories

A prominent add action should make adding an expense quick. Income can be added from the same add flow.

### 7.1 Dashboard

Show the selected/current cycle and its date range.

Required summary cards:

- Total income in the cycle.
- Total expenses in the cycle.
- Total budgeted amount.
- Net remaining amount across categories.

Also show:

- Category budget progress list.
- Recent transactions.
- A clear indication of categories at/over budget.
- A way to navigate to the cycle summary and full reports.

Do not show a total account balance; accounts are not tracked.

### 7.2 Transactions screen

Show transaction list with:

- Type indicator (income/expense).
- Amount.
- Category for expenses.
- Date.
- Note, when present.

Include filters and note search as described in section 6.4. Provide add, edit, and delete actions.

### 7.3 Budgets screen

Show all categories for the selected cycle, including:

- Category name.
- Budget amount.
- Spent amount.
- Remaining amount.
- Usage percentage / progress bar.

Allow the user to:

- Change the selected cycle.
- Edit the selected cycle's budget amount per category.
- Update a category's default allocation amount for future cycles.
- See negative remaining values clearly.

Do not hide categories with zero budgets.

### 7.4 Reports screen

Only the following reports are required for the first version:

1. **Spending by category:** expense totals grouped by category for a selected cycle.
2. **Budget vs. actual:** category budget amount compared with actual spending for a selected cycle.

Allow switching between cycles. Historical cycle data must remain accessible.

### 7.5 Cycle summary screen

Show the completed cycle's date range and:

- Total income.
- Total expenses.
- Total budgeted.
- Positive unused total.
- Net remaining total, including overspending.
- Overspent category count.
- Per-category budget, spent, and remaining breakdown.

The summary must be reproducible from stored transactions and budgets. Avoid storing calculated totals as the source of truth.

### 7.6 Categories / Settings screen

Allow the user to:

- Create a category.
- Rename a category.
- Change its color/icon if the chosen UI supports it.
- Set or edit its default allocation amount.
- Deactivate/archive a category.
- Review application preferences.

Category color and icon are optional presentation features; category creation, editing, and default allocation are required.

## 8. Notifications and cycle automation

All notifications must be local notifications. No backend or push-notification service.

### 8.1 25th-of-month reminder

Schedule a local notification for the 25th reminding the user to review the new cycle's budgets.

Because Android may restrict exact alarm scheduling, use an appropriate local notification scheduling strategy and document any platform limitations. Request notification permission where required.

The app must also detect and create a missing current cycle on launch/resume. Notifications are reminders, not the mechanism that guarantees cycle creation.

### 8.2 80% budget warning

When a category reaches or exceeds 80% of its cycle budget due to an expense being added or edited, send a local notification.

Avoid repeatedly notifying for every subsequent transaction. Recommended behavior: notify once per category per cycle when crossing from below 80% to at least 80%.

### 8.3 Over-budget warning

When a category crosses from remaining >= 0 to remaining < 0, send a local notification. Notify once per category per cycle for the threshold crossing.

If an edited/deleted transaction moves a category back below a threshold and a later expense crosses it again, define whether to notify again. Recommended simple first-version behavior: persist threshold notification state per category per cycle and do not send duplicates within that cycle.

### 8.4 Notification timing and permissions

- Request notification permission at an appropriate point, with a short explanation.
- If permission is denied, all finance functionality must continue to work.
- Reconcile/reschedule the next 25th reminder when the app opens.
- Avoid scheduling duplicate reminders.

## 9. Data model

Use a relational SQLite schema with foreign keys enabled.

The following is the recommended logical schema. The implementation agent may adjust naming, but must preserve the relationships and behavior.

### 9.1 `categories`

| Column | Type | Notes |
|---|---|---|
| id | TEXT primary key | UUID |
| name | TEXT not null | Unique case-insensitively after trimming |
| color | TEXT nullable | Optional UI color representation |
| icon | TEXT nullable | Optional icon key |
| default_budget_minor | INTEGER not null | Default allocation amount; default 0 |
| is_active | INTEGER not null | Boolean |
| created_at | TEXT not null | ISO timestamp |
| updated_at | TEXT not null | ISO timestamp |

### 9.2 `budget_cycles`

| Column | Type | Notes |
|---|---|---|
| id | TEXT primary key | UUID |
| start_date | TEXT not null unique | ISO calendar date, always day 25 |
| end_date | TEXT not null | ISO calendar date, always day 24 |
| created_at | TEXT not null | ISO timestamp |

Unique constraint on `start_date` guarantees one record per cycle.

### 9.3 `category_budgets`

| Column | Type | Notes |
|---|---|---|
| id | TEXT primary key | UUID |
| cycle_id | TEXT not null | FK to budget_cycles |
| category_id | TEXT not null | FK to categories |
| budget_amount_minor | INTEGER not null | Snapshot for this cycle |
| created_at | TEXT not null | ISO timestamp |
| updated_at | TEXT not null | ISO timestamp |

Constraints:

- Unique `(cycle_id, category_id)`.
- Budget amount must be >= 0.
- Historical budgets must remain unchanged when category defaults change.

### 9.4 `transactions`

| Column | Type | Notes |
|---|---|---|
| id | TEXT primary key | UUID |
| type | TEXT not null | `income` or `expense` |
| amount_minor | INTEGER not null | Must be > 0 |
| category_id | TEXT nullable | Required for expense; optional/supported for income |
| transaction_date | TEXT not null | ISO calendar date |
| note | TEXT nullable | Optional |
| created_at | TEXT not null | ISO timestamp |
| updated_at | TEXT not null | ISO timestamp |

Constraints:

- `type` must be `income` or `expense`.
- Amount must be > 0.
- Expense must have a valid category.
- Income may optionally be assigned a valid category (or remain uncategorized).
- Deleting/archiving a category must not cascade-delete transactions. Use restrictive foreign keys and archive categories instead.

### 9.5 `notification_events` (or equivalent notification state)

Persist enough information to prevent duplicate threshold notifications.

Suggested fields:

| Column | Type | Notes |
|---|---|---|
| id | TEXT primary key | UUID |
| cycle_id | TEXT not null | FK to budget_cycles |
| category_id | TEXT not null | FK to categories |
| event_type | TEXT not null | `reached_80_percent` or `over_budget` |
| created_at | TEXT not null | ISO timestamp |

Unique constraint on `(cycle_id, category_id, event_type)`.

The app may use a separate notification scheduling table if needed for reliable reminder management.

## 10. Technical architecture

### 10.1 Flutter implementation principles

- Use a feature-first folder structure.
- Keep UI widgets separate from business logic and persistence.
- Use a repository layer between state management and SQLite.
- Put budget-cycle calculations and financial calculations in pure, unit-testable domain services.
- Use typed models/entities; avoid passing unstructured maps throughout the app.
- Use database transactions for multi-step writes that must remain consistent.
- Enable SQLite foreign-key enforcement.
- Add database migrations from the first schema version.
- Keep all financial calculations deterministic and testable.

### 10.2 Suggested stack

Use these unless the existing project already has an established equivalent:

- Flutter / Dart.
- `drift` for SQLite access, typed queries, and migrations.
- `flutter_riverpod` for state management and dependency injection.
- `go_router` for navigation, if routing complexity warrants it.
- `flutter_local_notifications` for local notifications.
- `timezone` if required by the notification package for scheduling.
- `uuid` for IDs if not generated by the database.
- `intl` for date and currency formatting.

Do not add a backend, Firebase, authentication, analytics, or cloud dependencies.

### 10.3 Suggested project structure

```text
lib/
  app/
    app.dart
    router.dart
    theme/
  core/
    database/
      app_database.dart
      tables/
      migrations/
    date/
      budget_cycle.dart
      budget_cycle_calculator.dart
    money/
      money.dart
      money_formatter.dart
    notifications/
      notification_service.dart
  features/
    dashboard/
      data/
      domain/
      presentation/
    transactions/
      data/
      domain/
      presentation/
    categories/
      data/
      domain/
      presentation/
    budgets/
      data/
      domain/
      presentation/
    reports/
      data/
      domain/
      presentation/
    settings/
      presentation/
  shared/
    widgets/
    models/
```

The agent may adapt this structure, but must retain separation between UI, domain rules, and data access.

## 11. Important business workflows

### 11.1 First launch

1. Initialize the SQLite database.
2. Check whether initial setup has been completed.
3. If not, show onboarding for category creation and default allocation amounts.
4. Create the current budget cycle.
5. Snapshot the default allocation amounts into category budgets.
6. Open the dashboard.

The user must be able to create, edit, or add categories later.

### 11.2 App launch / resume

1. Read the device's current local calendar date.
2. Calculate the current budget cycle.
3. Check whether that cycle exists.
4. If it does not exist, create it and snapshot current category defaults.
5. Reconcile the 25th reminder.
6. Load dashboard values for the current cycle.

This workflow must be safe to run repeatedly.

### 11.3 Add expense

1. User enters amount, category, date, and optional note.
2. Validate the input.
3. Save the transaction.
4. Recalculate affected category/cycle totals from the database.
5. Evaluate 80% and over-budget threshold crossings.
6. Send eligible local notifications.
7. Refresh dashboard, budgets, transaction list, and reports.

### 11.4 Edit or delete expense

1. Save the edit or delete the transaction.
2. Recalculate totals for the affected cycle/category.
3. If the date or category changed, recalculate both the old and new affected groups.
4. Refresh all relevant screens.
5. Do not leave stale budget totals or notification state.

### 11.5 Start a new cycle

1. On or after the 25th, detect the new cycle on app launch/resume.
2. Create the cycle if missing.
3. Copy active categories' default allocation amounts into its category budgets.
4. Preserve all historical cycle budgets and transactions.
5. Show the user the new cycle.
6. Remind the user to review the new cycle's allocations.

### 11.6 Income differs from expected amount

1. User records the actual one-time income.
2. App updates the cycle's income total.
3. App does not automatically modify any category budget.
4. User may manually adjust category budgets if desired.

## 12. UX requirements

- Prioritize fast expense entry; the add-expense flow should require as few taps as practical.
- Amount input should be prominent and numeric.
- Default transaction date to today.
- Remember the last-used category as a convenience, but do not silently select it if that could cause accidental misclassification.
- Make income and expense visually distinguishable without relying on color alone.
- Display currency consistently as EGP.
- Format dates consistently in English.
- Clearly distinguish:
  - Budgeted
  - Spent
  - Remaining
  - Positive unused total
  - Net remaining
- Negative remaining values must be obvious and readable.
- Confirm destructive actions such as deleting a transaction.
- Support empty states for a new user with no categories, transactions, or budgets.
- Provide loading, error, and validation states.
- Do not make network requests.

## 13. Non-functional requirements

- App must work fully offline.
- User data must persist after closing/restarting the app.
- No financial values may be lost or rounded incorrectly.
- Database writes must preserve referential integrity.
- The app must handle month/year boundaries and leap years.
- Dashboard and reports must update after add/edit/delete operations.
- Historical cycles must remain viewable.
- The app must not create duplicate cycles or category budgets.
- Use database migrations for schema changes.
- Handle database and notification errors gracefully.
- Notification permission denial must not block normal use.

## 14. Out of scope for version 1

Do not implement these unless explicitly requested later:

- User accounts, authentication, or multiple users.
- Cloud backup or synchronization.
- Bank integrations or automatic bank transaction imports.
- Multiple accounts, wallets, or cash balances.
- Transfers.
- Recurring income or expenses.
- Automatic income allocation based on actual received income.
- Automatic carryover of unused budgets.
- Debt tracking.
- Receipt images or attachments.
- Multi-currency support.
- Investment portfolio valuation.
- Financial advice or AI-generated recommendations.
- CSV/Excel export unless added as a later requirement.

## 15. Acceptance criteria

The application is ready for a first usable release when all of the following pass.

### Budget cycle

- [ ] A date on the 24th belongs to the cycle that began on the previous month's 25th.
- [ ] A date on the 25th belongs to a new cycle starting that day.
- [ ] Cycle calculation works across December/January and leap years.
- [ ] Opening the app repeatedly creates no duplicate cycles.
- [ ] A new cycle copies the current category default allocation amounts.
- [ ] Editing a default allocation does not change historical cycle budgets.
- [ ] Editing a current cycle budget does not silently change the default allocation.

### Transactions

- [ ] User can add income with amount, category, date, and optional note.
- [ ] User can add an expense with amount, category, date, and optional note.
- [ ] Zero and negative transaction amounts are rejected.
- [ ] User can edit and delete transactions.
- [ ] User can filter by category, type, date range, and cycle.
- [ ] User can search transaction notes.
- [ ] A transaction dated in a previous cycle affects that historical cycle.
- [ ] Editing a transaction's date/category updates all affected calculations.

### Budget calculations

- [ ] Spent amount equals the sum of expenses for that category in that cycle.
- [ ] Remaining amount equals budget minus spent.
- [ ] Overspending produces a negative remaining amount and is allowed.
- [ ] Zero-budget categories do not cause division-by-zero.
- [ ] Positive unused total ignores negative category balances.
- [ ] Net remaining total includes negative category balances.
- [ ] Income is not automatically distributed or used to modify budgets.
- [ ] Savings/investments categories behave like ordinary expense categories.

### Dashboard and reports

- [ ] Dashboard shows current-cycle income, expenses, total budget, and net remaining.
- [ ] Dashboard shows category budget progress and recent transactions.
- [ ] Spending-by-category report is correct for the selected cycle.
- [ ] Budget-vs-actual report is correct for the selected cycle.
- [ ] Historical cycle summaries remain accessible.
- [ ] Summary shows both positive unused total and net remaining total.

### Notifications

- [ ] Local reminder is scheduled for the 25th.
- [ ] Reminder scheduling does not create duplicates.
- [ ] Crossing 80% can trigger a local notification once per category per cycle.
- [ ] Crossing over budget can trigger a local notification once per category per cycle.
- [ ] Denying notification permission does not break the app.

### Persistence and quality

- [ ] Data remains after app restart.
- [ ] Foreign keys are enforced.
- [ ] Database migrations are in place.
- [ ] Financial arithmetic uses exact integer/decimal-safe values.
- [ ] Core domain logic has automated unit tests.
- [ ] No backend or network dependency is required.

## 16. Required automated tests

At minimum, write tests for:

### Budget-cycle calculator

- 24 October -> cycle starting 25 September.
- 25 October -> cycle starting 25 October.
- 1 January -> cycle starting 25 December of previous year.
- 24 January -> cycle starting 25 December of previous year.
- 25 January -> cycle starting 25 January.
- Leap-year February boundaries.
- Cycle end is always the day before the next cycle start.

### Budget calculations

- Under budget.
- Exactly at budget.
- Over budget.
- Zero budget with no spending.
- Zero budget with spending.
- Positive unused total with a negative category.
- Net remaining total with a negative category.
- Multiple transactions in one category.
- Editing/deleting a transaction updates totals.

### Data and workflows

- Creating a cycle snapshots category defaults.
- Re-running cycle creation does not duplicate records.
- Updating a category default affects future cycles only.
- Editing a cycle budget affects only that cycle.
- A transaction assigned by date to a historical cycle updates that cycle.
- Category archive preserves historical transactions and budgets.

### Notifications

- 80% threshold crossing.
- Over-budget threshold crossing.
- No duplicate event for the same category/cycle/threshold.
- Permission denied behavior.

## 17. Implementation instructions for the IDE agent

1. Treat this document as the authoritative requirements specification.
2. First inspect the existing repository and report its current structure, Flutter/Dart versions, and any existing architecture. Do not overwrite an established project structure without reason.
3. Convert this specification into small, ordered implementation tasks with dependencies and test criteria.
4. Present the proposed task breakdown before implementing, if the IDE workflow supports planning approval.
5. Implement incrementally; do not generate the entire app in one unreviewable change.
6. Implement and test the budget-cycle calculator and money calculations before building dashboard UI.
7. Implement database schema and migrations before feature repositories.
8. Implement transaction and budget domain logic before reports.
9. Add notification behavior after core calculations are stable.
10. Run formatting, static analysis, and tests after each meaningful milestone.
11. Do not invent extra product features. If a requirement is ambiguous or conflicts with another requirement, stop and ask rather than silently choosing behavior.
12. Keep this document updated if an agreed requirement changes.

### Suggested implementation milestones

1. Project inspection, task breakdown, and app foundation.
2. SQLite schema, migrations, repositories, and domain models.
3. Budget-cycle calculation and cycle creation.
4. Category management and allocation defaults.
5. Income/expense transaction CRUD and validation.
6. Budget calculations and budget management UI.
7. Dashboard.
8. Reports and historical cycle summaries.
9. Local notifications and threshold tracking.
10. UX polish, error handling, and full acceptance-test pass.

---

## 18. One explicit interpretation to preserve

The phrase “allocate income” means setting fixed default budget amounts for categories. The app reuses those amounts in each new budget cycle. It does **not** automatically create an income transaction, distribute a newly entered income transaction, or change budgets when actual income changes.

Savings and investments, if used, are categories with budget amounts and ordinary expense transactions. They are not separate account balances or investment records.

This interpretation keeps the first version aligned with the requested simple personal expense tracker.
