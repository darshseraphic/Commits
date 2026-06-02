# Asrio
<b>update notes will be seen here</b>

Asrio is lightweight and secure app so, I'm treating this as a **Flutter (Dart)** app.

### 1. Logic Map — Step-by-Step Data JourneyHere is the step-by-step journey for each major feature:

**App launch:** `main.dart` initializes Drift DB, loads theme + language from SharedPreferences, registers notification channels, and checks whether `PACKAGE_USAGE_STATS` permission has been granted (this one requires manual user action in Settings — we must handle its absence gracefully on every screen).

**To-Do flow:** User creates/checks a task → `TaskProvider` calls `TaskRepository` → `TasksDao` writes to the `tasks` table in Drift SQLite. A `Stream` from the DAO flows back up through the repository and provider, causing the UI to rebuild reactively — no manual refresh needed.

**Diary write flow:** User types in the rich text editor → on save, the `QuillDelta` is serialized to JSON → `EncryptionService` encrypts it with AES-256 using a key pulled from `flutter_secure_storage` (backed by Android Keystore) → the encrypted blob and its IV are written to the `diary_pages` table. Plaintext is never written to disk.

**Diary read flow:** The inverse — encrypted blob + IV pulled from DB → `EncryptionService` decrypts in memory → `QuillController` loads the delta. Decryption happens only in RAM, never persisted.

**Consistency tab flow:** Two parallel data sources merge here: (1) the Drift `diary_entries` and `tasks` tables are queried for per-day activity to shade the calendar, and (2) `AppUsageService` fires a platform channel call to the Kotlin `UsageStatsPlugin`, which queries `UsageStatsManager` and returns a map of `{packageName: usageMinutes}`. Both streams are combined in a `ConsistencyProvider` before reaching the chart widgets.

**Notification flow:** When the user sets a diary or to-do reminder in Settings, `NotificationService` calls `flutter_local_notifications` to schedule an exact alarm. Because of Android 12+ restrictions, we check `canScheduleExactAlarms()` first and gracefully fall back to inexact if denied. Alarms survive reboot via the `RECEIVE_BOOT_COMPLETED` receivers already in the spec.

### 2. File Structure

```
lib/
│
├── main.dart                        # Bootstrap only: DB init, DI, runApp
├── app.dart                         # MaterialApp, theme, locale, routing
│
├── core/
│   ├── theme/
│   │   ├── app_theme.dart           # Light + dark ThemeData definitions
│   │   └── theme_provider.dart      # ChangeNotifier; reads/writes SharedPrefs
│   ├── localization/
│   │   └── app_localizations.dart   # Already exists in spec (translations)
│   ├── encryption/
│   │   └── encryption_service.dart  # AES-256 encrypt/decrypt; key via Keystore
│   └── utils/
│       ├── date_helpers.dart        # Shared date formatting/comparison logic
│       └── permission_helper.dart   # Centralised runtime permission checks
│
├── data/
│   ├── database/
│   │   ├── app_database.dart        # Drift DB class; table registrations
│   │   ├── tables/
│   │   │   ├── tasks_table.dart
│   │   │   ├── diary_table.dart     # Stores encrypted blob + IV, NOT plaintext
│   │   │   ├── habits_table.dart
│   │   │   └── activity_log_table.dart  # App-open timestamps for the chart
│   │   └── daos/
│   │       ├── tasks_dao.dart
│   │       ├── diary_dao.dart
│   │       ├── habits_dao.dart
│   │       └── activity_dao.dart
│   ├── models/
│   │   ├── task_model.dart
│   │   ├── diary_entry_model.dart   # Holds decrypted QuillDelta in memory only
│   │   └── habit_model.dart
│   ├── repositories/
│   │   ├── task_repository.dart
│   │   ├── diary_repository.dart    # Owns encrypt/decrypt orchestration
│   │   └── habit_repository.dart
│   └── services/
│       ├── notification_service.dart
│       ├── app_usage_service.dart   # Dart side of the platform channel
│       └── preferences_service.dart
│
├── providers/                       # Riverpod — one file per domain
│   ├── task_provider.dart
│   ├── diary_provider.dart
│   ├── habit_provider.dart
│   ├── consistency_provider.dart    # Merges diary activity + app usage
│   └── settings_provider.dart
│
└── features/
    ├── home/
    │   ├── home_screen.dart
    │   └── widgets/
    │       ├── wellbeing_card.dart
    │       ├── tasks_overview_card.dart
    │       └── usage_dropdown_sheet.dart
    ├── todo/
    │   ├── todo_screen.dart
    │   └── widgets/
    │       ├── task_card.dart
    │       └── add_task_sheet.dart
    ├── diary/
    │   ├── diary_screen.dart        # Manages page navigation, hides bottom nav
    │   └── widgets/
    │       ├── diary_page_view.dart  # ViewPager2 equivalent (PageView)
    │       ├── rich_text_toolbar.dart
    │       └── book_close_animation.dart  # Lottie animation wrapper
    ├── consistency/
    │   ├── consistency_screen.dart
    │   └── widgets/
    │       ├── monthly_calendar_widget.dart
    │       ├── usage_pie_chart.dart
    │       └── open_time_line_chart.dart
    └── settings/
        ├── settings_screen.dart
        └── widgets/
            ├── theme_selector_tile.dart
            ├── language_selector_tile.dart
            └── notification_settings_tile.dart

android/app/src/main/
├── kotlin/com/darshvici/asrio/
│   ├── MainActivity.kt              # Registers platform channels
│   └── UsageStatsPlugin.kt          # Kotlin: queries UsageStatsManager
└── AndroidManifest.xml              # Already specced; add PACKAGE_USAGE_STATS
```
### 3. Key Concepts & Patterns

**Repository Pattern** — the UI never touches the database directly. `DiaryRepository` is the single owner of the encrypt/decrypt lifecycle. If you ever change the encryption algorithm, you change it in one class, not across 12 widgets.

**DAO Pattern (Drift)** — Drift gives you type-safe, compile-time-verified SQL in Dart. Every table is a Dart class. Invalid queries fail at build time, not at runtime on a user's phone. This is the right choice over raw `sqflite` for a schema this complex.

**Riverpod for State** — `StreamProvider` watches a Drift `Stream<List<Task>>` from the DAO. When any task changes in the DB, the stream emits, Riverpod rebuilds only the widgets that `watch` that provider. Zero manual `setState`, zero data-out-of-sync bugs between tabs.

**Encrypt-at-Rest** — the diary contains genuinely personal data. AES-256-CBC with a random IV per entry. The 256-bit key is generated once on first launch and stored in `flutter_secure_storage`, which uses the Android Keystore hardware-backed store. The IV is stored alongside the ciphertext in the DB. Plaintext only ever exists in RAM during an active editing session.

**Platform Channel (Kotlin ↔ Dart)** — `UsageStatsManager` is a native Android API with no Flutter wrapper. We write a thin `UsageStatsPlugin.kt` that responds to a `MethodChannel` call from `AppUsageService.dart`. This is a clean, well-established pattern. We request `PACKAGE_USAGE_STATS` permission (which requires the user to navigate to a Settings screen — we handle this with a clear onboarding dialog).

**Service Layer** — `EncryptionService`, `NotificationService`, and `AppUsageService` are stateless injectable classes. They know nothing about UI. This makes them trivially testable and reusable across features.

**Feature-First Folder Structure** — each tab (`diary/`, `todo/`, etc.) owns its screens and widgets. `core/` and `data/` are shared. New features don't pollute existing ones. Scales cleanly as the app grows.

**Animation Architecture** — the diary's "book close" and bottom nav hide/show are driven by `AnimationController` inside the `DiaryScreen`. The nav hide is a `SlideTransition` on a `ValueNotifier<bool>`, so the diary page and the nav bar are decoupled — the diary screen signals, the shell reacts.

### Security Decisions Worth Flagging

The `PACKAGE_USAGE_STATS` permission is **not grantable at runtime** — Android sends the user to a system Settings page. If they deny it, the Home and Consistency tabs must still function (just without usage data). Every usage-stat widget needs a "permission not granted" fallback state.

Diary encryption keys should **never be backed up to Google Drive**. We set `android:allowBackup="false"` in the manifest and configure `flutter_secure_storage` with `encryptedSharedPreferences: true`.

 

# Phase 2 — Technical Architecture Plan

## 1. Data Access: Repository Pattern

No Base Repository. Here's why: a generic `BaseRepository<T>` sounds clean on paper, but our three domains (Tasks, Diary, Habits) have fundamentally different contracts. The Diary repository must encrypt before every write and decrypt after every read — that's not a generic operation. Forcing it into a shared base class means the base either knows about encryption (wrong layer) or the subclass bypasses the base (pointless abstraction). Three focused repositories with clear, explicit APIs are simpler and safer.

**The layering contract:**

> Widget → ref.watch(taskProvider) → TaskRepository → TasksDao (Drift — pure DB queries, no logic) → [optionally] NotificationService (on write operations only)

Each DAO is a pure data accessor. It knows SQL and nothing else. The Repository sits above and orchestrates: it calls the DAO, applies any business rules (encryption, notification sync, streak recalculation), and returns a clean model. The provider sits above the Repository and bridges it into Riverpod's reactive graph.

**DiaryRepository specifically owns the full encrypt/decrypt lifecycle:**

* **Write path:** `DiaryRepository.savePage(plaintext)` → `EncryptionService.encrypt(plaintext)` → returns `(ciphertext, iv)` → `DiaryDao.upsertPage(ciphertext, iv)`
* **Read path:** `DiaryRepository.getPage(date, pageNumber)` → `DiaryDao.fetchPage(date, pageNumber)` → returns `(ciphertext, iv)` → `EncryptionService.decrypt(ciphertext, iv)` → returns `plaintext` → returns `DiaryEntryModel` (plaintext only, never stored)

The `DiaryEntryModel` that reaches the provider and widget layers only ever holds plaintext in RAM. Ciphertext never travels above the Repository boundary.

 

## 2. State Management: AsyncNotifier Design

We'll use `AsyncNotifier` (not `StateNotifier`) for Tasks and Diary because both involve async database streams and need built-in loading/error state handling.

**TaskNotifier — the full state lifecycle:**

```dart
// State machine for every operation:
//
// Initial load:
//   state = AsyncLoading()
//   state = AsyncData(tasks)        ← Drift Stream emits
//   state = AsyncError(e, st)       ← if DB fails
//
// User adds a task:
//   state = AsyncLoading()          ← optimistic: show spinner
//   await TaskRepository.insert()
//   state = AsyncData(newList)      ← Drift stream auto-emits new list
//                                      (we don't manually rebuild — the
//                                       stream does it for us)

```

The key architectural decision here is **Drift Streams as the single source of truth**. Instead of:

1. Insert task into DB
2. Manually update the in-memory list
3. Rebuild the widget

**We do:**

1. Insert task into DB
2. Drift's `watchAllTasks()` stream auto-emits the new list
3. `AsyncNotifier` receives the new emission → widget rebuilds

This means the UI state is always a direct projection of the database. There is no possibility of the UI showing stale data because the list is not stored in the notifier — it flows through it.

> Drift DB → Stream<List> → TaskNotifier.state → TaskListWidget (always live) (AsyncData wrapper)

**Error handling contract:** All repository methods throw typed exceptions — `DatabaseException`, `EncryptionException` — never raw Dart errors. The notifier catches these and sets `AsyncError`. The widget layer reads `state.when(data:, loading:, error:)` and renders accordingly. No try/catch in widgets ever.

 

## 3. Consistency & Streak Calculation

Hybrid approach: SQL aggregation for raw data, Dart for streak logic.

SQL is excellent at aggregating — "give me all dates that have at least one completed task." SQL is terrible at sequential logic — "find the longest unbroken chain of those dates." We use each tool for what it's good at.

**Step 1 — SQL query (in ActivityDao):**

```sql
-- Returns one row per calendar date that has any meaningful activity.
-- "Activity" = completed task OR diary page written.
-- UNION deduplicates: a date with both still counts as one active day.
SELECT DATE(created_at) as active_date
FROM tasks
WHERE is_completed = 1
UNION
SELECT DATE(entry_date) as active_date
FROM diary_pages
ORDER BY active_date ASC

```

This returns a clean `List<DateTime>` of active dates. Fast, indexed, minimal data transfer.

**Step 2 — Dart streak calculation (in ConsistencyRepository):**

```dart
// Input:  [2025-01-01, 2025-01-02, 2025-01-04, 2025-01-05, 2025-01-06]
// Output: currentStreak=3, longestStreak=3, totalActiveDays=5
int calculateCurrentStreak(List<DateTime> activeDates) {
  // Walk backwards from today.
  // Increment streak counter while consecutive days are found.
  // Stop at the first gap.
}

```

**Why not a SQL View or generated column?**
A SQL view for streak calculation requires recursive CTEs (Common Table Expressions). Drift supports custom SQL but recursive CTEs are complex, hard to read, hard to test, and overkill for a dataset that will never exceed ~365 rows per year. The Dart calculation runs in microseconds on that dataset. Simplicity wins here.

Calendar shading data (the monthly calendar grid on the Consistency tab) comes from a second query: `SELECT DATE(entry_date), COUNT(*) FROM diary_pages GROUP BY DATE(entry_date)` — merged with the task completion query in `ConsistencyProvider` using a simple `Map<DateTime, bool>` that the calendar widget reads.

 

## 4. Notification Sync: The Coordinator Pattern

**The problem:** creating a task and scheduling a notification are two separate async operations touching two separate systems. <b>If the DB write succeeds but the notification scheduling fails (permission revoked mid-session, exact alarm denied), we have a task with no reminder.</b>  If the notification schedules but the DB write fails, we have a phantom notification for a task that doesn't exist.

**Solution — the Repository as Transaction Coordinator:**

**TaskRepository.insertWithReminder(task, reminderTime):**

* **Step 1: DB write**
  `await TasksDao.insert(task)`
  → if this throws, stop. No notification scheduled. Clean state.
* **Step 2: Notification schedule**
  `await NotificationService.scheduleTaskReminder(taskId, title, reminderTime)`
  → if this throws, we catch it, log it, but **DO NOT** roll back the task. A task with a failed reminder is better than no task at all. The UI shows a subtle warning: "Reminder could not be set."
* **Step 3: Store the notification ID**
  `await TasksDao.updateNotificationId(taskId, notificationId)`
  → Links the task row to its notification so cancellation works later.

The notification ID link is critical. When a task is deleted or marked complete, we need `NotificationService.cancel(notificationId)`. Without storing the ID, we'd have to cancel all notifications and reschedule the remaining ones — a fragile $O(n)$ operation. With the stored ID, cancellation is a single $O(1)$ call.

The tasks table gains one column: `notificationId INTEGER NULLABLE` — this is a schema change from Phase 1, handled via Drift's `MigrationStrategy.onUpgrade` with `schemaVersion: 2`.

**Notification sync flow diagram:**

> User taps "Save Task" with reminder
> ↓
> TaskNotifier.addTask()
> ↓
> TaskRepository.insertWithReminder()
> ├─ TasksDao.insert() (must succeed first)
> ├─ NotificationService.schedule() (attempt; failure is non-fatal)
> └─ TasksDao.updateNotificationId() (links task ↔ notification)
> ↓
> Drift stream emits new task list
> ↓
> UI rebuilds with new task visible

On task completion: `TaskRepository.complete(taskId)` calls `NotificationService.cancel(task.notificationId)` before marking the task done — no point showing a reminder for something already completed.

## Files Phase 2 Will Produce

**lib/data/**

* **models/**
* `task_model.dart` ← Clean domain model (not Drift's generated class)
* `diary_entry_model.dart` ← Holds plaintext only, never ciphertext
* `habit_model.dart`


* **database/daos/**
* `tasks_dao.dart` ← CRUD + watchAll stream + notification ID update
* `diary_dao.dart` ← Upsert + fetch by date + date range query
* `habits_dao.dart` ← CRUD + archive toggle
* `activity_dao.dart` ← Active dates query + app-open log read


* **repositories/**
* `task_repository.dart` ← Coordinates DAO + NotificationService
* `diary_repository.dart` ← Coordinates DAO + EncryptionService
* `habit_repository.dart` ← Coordinates DAO only (no encryption needed)
* `consistency_repository.dart` ← Merges activity_dao + streak calculation



**lib/core/encryption/**

* `encryption_service.dart` ← AES-256-CBC, key from flutter_secure_storage

**lib/providers/**

* `task_provider.dart` ← AsyncNotifier<List>
* `diary_provider.dart` ← AsyncNotifier<DiaryEntryModel?>
* `habit_provider.dart` ← AsyncNotifier<List>
* `consistency_provider.dart` ← Merges streak data + app usage (stub)

**Schema change:** `schemaVersion` bumps from 1 → 2. The tasks table gains `notificationId`. Migration handled in `app_database.dart`.

## Decisions

**Decision A — Domain Models vs Drift Data Classes.** Drift auto-generates a Task data class from the table definition. I'm proposing we wrap it in a separate `TaskModel` (a plain Dart class). This adds one mapping step but means the UI layer never imports Drift — a clean boundary that lets us swap the database in future without touching a single widget. Agree?

**Decision B — Streak calculation cutoff.** Should "current streak" break if yesterday had no activity, or only if today AND yesterday both have no activity? The first definition (stricter) is what apps like Duolingo use. The second (looser) is more forgiving — a user who hasn't written today yet doesn't lose their streak until tomorrow. The looser definition is better UX for a personal productivity app. Agree?

**Here are my decisions for the build:**

**Decision A:** I agree to use Domain Models to keep a clean boundary between the UI and Drift.

**Decision B:** I agree to Let's go with the 'Looser' Streak definition. It’s much better for user retention if they don't see a broken streak until the day is actually over.

## Phase 3 — What We Actually Built

 

### The Navigation Shell (`main_screen.dart`)

The entire app now lives inside a **`PageView`** — a horizontal scroll container holding all 4 tabs. This replaces the standard Flutter `BottomNavigationBar` behavior where tapping switches screens. Now you **swipe** between them like Instagram.

The bottom nav bar is custom-built — icon only, no labels, thin `#E0E0E0` top border, no Material elevation shadow. When the Diary editor opens, the nav bar **slides down off screen** via a `SlideTransition` animation and the `PageView` is locked with `NeverScrollableScrollPhysics`. When you close the editor, both come back. This is the Zen Mode contract.

 

### Home Screen (`home_screen.dart`)

Four stacked sections in a `CustomScrollView`:

**Greeting header** — time-aware ("Good morning / afternoon / evening"), today's date formatted, and a circular profile icon button.

**Focus Card** — a full-width pure black `BentoCard` that queries the task list and surfaces the first non-completed task. White text, a small "CURRENT FOCUS" label, and a "Top Priority" pill badge.

**Bento Grid** — a two-column asymmetric layout built with `IntrinsicHeight` + `Row`. Left column has a circular progress ring showing today's completion percentage, and a small black card showing the count of tasks completed today. Right column is a taller white card listing up to 4 upcoming tasks as dot-prefixed rows.

**Quick Stats card** — a white card with a 7-day mini line chart from `fl_chart`. Each of the 7 data points is 1.0 (active) or 0.0 (inactive) based on whether that date exists in the streak model's `activeDates` set. Grey gradient fill beneath the line.

 

### To-Do Screen (`todo_screen.dart`)

The task list split into three visual zones:

**Priority One card** — same black Bento treatment as the Home focus card, but this one has a circular checkmark button on the right. Tapping it fires `HapticFeedback.mediumImpact()` and calls `TaskNotifier.completeTask()`.

**Active tasks** — each rendered as a `Dismissible` widget. Swiping left reveals a black background with a white delete icon. On confirm, `HapticFeedback.heavyImpact()` fires and the task is deleted from the database. Each task has a circular empty checkbox — tapping it completes the task with a selection click haptic.

**Completed tasks** — rendered as simple rows, no card border, grey strikethrough text (`taskTitleCompleted` style). They visually "fall away" from the main grid.

**FAB** — a 52px black circle with a white `+`. Tapping opens a `ModalBottomSheet` with a pure white surface, a single `TextField` (autofocused, keyboard pops immediately), and a row of priority selector pills (None / Low / Medium / High) that animate between black-selected and grey-unselected. Submitting calls `TaskNotifier.addTask()`.

 

### Diary Screen (`diary_screen.dart`)

Two completely separate sub-screens wrapped in an `AnimatedSwitcher` with a `SlideTransition`:

**List View** — a white `Scaffold` with no cards. Entries are separated by 0.8px `#E0E0E0` `Divider` lines — a physical notebook. Each row shows the day number (large bold), month abbreviation, weekday name, a one-line preview, and a small `lock_outline` icon to signal AES-256 encryption. A pencil icon button in the top-right opens a new entry for today.

**Zen Mode Editor** — when an entry is tapped, the list slides left and the editor slides in from the right. At this moment `zenModeNotifier.value = true` fires, the nav bar slides out, and the PageView locks. The editor has a minimal top bar (back arrow, date, auto-save spinner, lock icon), then a full-screen `QuillEditor` with wide 1.8 line height and no persistent toolbar.

**Floating format bar** — the Quill toolbar only appears when the user selects text. It floats above the keyboard as a black pill with Bold, Italic, and Bullet icons in white. It disappears when the selection is collapsed.

**Ghost Mode** — the editor registers as an `AppLifecycleObserver`. The moment `AppLifecycleState.paused` fires (app goes to background, recents screen opens), a `BackdropFilter` blur at sigma 24 covers the entire screen immediately. The diary content becomes completely unreadable. A lock icon and "Diary is locked" message sit in the center.

 

### Consistency Screen (`consistency_screen.dart`)

Three data cards stacked vertically:

**Streak Hero** — a black `BentoCard` with the current streak number at 80sp, weight 800, letter-spacing -4. To its right, a `CircularRing` showing the ratio of current streak to longest streak ever. A motivational line below the number changes based on whether the streak is 0 or active.

**Growth Chart** — a white card containing a 30-day `fl_chart` `LineChart`. No grid lines, no border, no axis labels except bottom dates at 7-day intervals. The line is 2.5px black, curved with 0.35 smoothness. The fill gradient animates from 10% black opacity to transparent. The chart itself has a draw-in animation — an `AnimationController` runs on `initState` and drives the fill opacity, giving the impression the chart is being drawn live when the screen loads.

**Month Heatmap** — a white card with a `Wrap` of 28×28px rounded squares for every day of the current month. Empty padding cells fill in for the day-of-week offset. Active days (have a diary entry) are pure black. Today gets a black border with its date number shown. Inactive days are `#E0E0E0`. A two-item legend at the bottom.

**Stats Row** — three equal white cards showing Current Streak, Longest Streak, Total Active Days as large numbers.

 

### Settings Screen (`settings_screen.dart`)

Not a `ListView` — a `CustomScrollView` with deliberately sized cards:

**Privacy Vault card** — black, full width. A shield icon, "Privacy Vault" title, and two white badge pills: "AES-256 ACTIVE" and "LOCAL STORAGE ONLY". This is the first thing the user sees on the Settings tab — it reinforces that the app is a vault.

**System grid** — two equal columns: Theme toggle (tapping calls `ThemeModeNotifier.setTheme()` and the entire app switches instantly because `app.dart` is a `ConsumerWidget`) and a Haptics tile.

**Notification and Language tiles** — full-width white cards with chevron arrows. Tapping does nothing yet — wired in Phase 6.

**Wipe Data button** — the only element in the entire app with a red color (`#E53935` border). Everything else is pure greyscale. Tapping opens an `AlertDialog` with Cancel / Wipe actions.

**Branding footer** — "ASRIO v1.0 / Designed by Darshseraphic / All data stays on device." in small grey caption text.

 

### The Design System (`asrio_colors.dart`, `asrio_text_styles.dart`)

**7 color values** from `#000000` to `#FFFFFF`. Every color in every widget is a named constant — no hex literals anywhere outside `asrio_colors.dart`. The one exception is `dangerBorder = #E53935` which is explicitly documented as "the only non-greyscale value allowed."

**14 named text styles** all using DM Sans. `streakHero` (80sp, weight 800) down to `caption` (11sp, weight 400). Widgets call `AsrioText.cardTitle` — never `TextStyle(fontSize: 18, fontWeight: FontWeight.w700)`.

**`BentoCard`** is the single card component with two named constructors: `BentoCard.black()` and `BentoCard.white()`. Every card in the app is one of these two. Consistent 20px radius, 0.8px borders on white cards, `InkWell` ripple tuned per variant.

**`CircularRing`** is a `CustomPainter` that draws a track circle and a progress arc starting from the top (-π/2). Used on the Home bento grid and the Consistency streak hero.

 

### What Phase 3 Does NOT Do

- The diary does not yet fully round-trip Quill delta JSON (save → close → reopen → content restored) — that's Phase 4.
- The Consistency chart shows app-open counts (from the `activity_log` table), not task completion counts, because the usage stats platform channel is a Phase 5 stub.
- The biometric unlock after Ghost Mode blur is a `Future.delayed` placeholder — real `local_auth` integration is Phase 4.
- No animations on task completion (the card doesn't animate into the completed section yet) — Phase 4 polish.
- The notification tile and language tile in Settings are non-functional — Phase 6.

Before writing a single line of code, here is the full technical plan — same process as every phase.



## Phase 4 — Architecture Plan

### What Phase 4 Covers
From the Phase 3 review, four gaps need closing:

1. **Diary round-trip** — Quill delta JSON correctly saves, reloads, and displays on reopen
2. **Biometric lock** — `local_auth` replaces the `Future.delayed` Ghost Mode placeholder
3. **Task completion animation** — cards animate into the completed section instead of snapping
4. **Diary transitions** — the book-open feel (Lottie or custom Hero transition)

 

### 1. Diary Round-Trip — The Real Problem

Right now the `DefaultJsonConverter` in `diary_screen.dart` is a shim that returns an empty list on decode. This means every time you reopen a diary entry, you get a blank page — the content was saved to the database encrypted, but the read path fails silently when trying to reconstruct the `Document` from the stored delta JSON.

**The fix has three parts:**

**Part A — Correct serialization on save:**
```
User types in QuillEditor
  → _quillController.document.toDelta().toJson()
  → returns List<Map<String, dynamic>>
  → jsonEncode(list)                    ← this is what we store
  → DiaryNotifier.updatePageContent()
  → DiaryRepository.savePage(content)
  → EncryptionService.encrypt(content)  ← encrypts the JSON string
  → DiaryDao.upsertPage(blob, iv)
```

**Part B — Correct deserialization on load:**
```
DiaryDao.watchPagesForDate()
  → DiaryRepository._decryptPage()      ← returns plaintext JSON string
  → DiaryNotifier._initController()
  → jsonDecode(content)                 ← returns List<dynamic>
  → Document.fromJson(list)             ← QuillDelta document
  → QuillController(document: doc)
```

**Part C — The session reload bug:**
Currently `_initController()` runs once in `initState` via `addPostFrameCallback`. If the provider rebuilds (because auto-save wrote to DB and the stream emitted), the controller reinitializes — losing the cursor position. We fix this with an `_initialized` guard flag: the controller only initializes once per editor session, and all subsequent updates come from the user typing, not from the stream.

 

### 2. Biometric Lock — `local_auth` Integration

**The full Ghost Mode lifecycle:**

```
App goes to background (paused/inactive)
  → _isBlurred = true  → blur overlay shows immediately
  → _pendingAuth = true

App returns to foreground (resumed)
  → _pendingAuth is true
  → LocalAuthentication.authenticate() called
      ├─ Success → _isBlurred = false, _pendingAuth = false
      └─ Failure/cancel → app stays blurred, tries again
```

**Key decisions:**

- We use `local_auth` package (`local_auth: ^2.3.0`), added to `pubspec.yaml`
- Biometric auth only triggers when the **editor** is open (`zenModeNotifier.value == true`). Opening the app normally never requires biometrics — only the diary
- If the device has no biometrics enrolled, we fall back to device PIN/pattern (the `biometricOnly: false` parameter)
- If biometrics are completely unavailable, the blur still shows but lifts automatically after a 500ms delay — we never block a user from their own data

**AndroidManifest addition needed:**
```xml
<uses-permission android:name="android.permission.USE_BIOMETRIC"/>
```

 

### 3. Task Completion Animation

Right now completing a task calls `completeTask()` and the task instantly reappears in the grey completed section — no motion. This breaks the "premium" feeling.

**The animation contract:**

```
User taps checkbox
  → HapticFeedback.mediumImpact()
  → AnimatedList removes the item from active section
      (300ms slide + fade out)
  → TaskNotifier.completeTask() called (DB write)
  → AnimatedList adds item to completed section
      (200ms fade in, grey style)
```

**Implementation:** Replace the static `ListView` / `Column` with `AnimatedList` for the active tasks. Each `_TaskCard` wraps in a `SizeTransition` + `FadeTransition`. The completion callback triggers the remove animation first, waits for it to finish, then calls the provider.

**The checkmark animation on the `_FocusBentoCard`:** When the top priority card is completed, the card itself does a short scale-down (`0.95`) and fade before the list updates. This is a `ScaleTransition` controlled by a local `AnimationController` inside the card widget.

 

### 4. Diary Page Transitions

**The book-open transition** when tapping a diary entry:

Instead of the generic `SlideTransition` from Phase 3, we build a custom page route that simulates turning a page:

```
_DiaryListView (entry row tapped)
  → Hero widget wrapping the entry row date
  → Custom PageRouteBuilder
      transitionDuration: 400ms
      pageTransitionsBuilder: _BookPageTransition
        ├─ The list view scales slightly down (0.97) and darkens (dark overlay)
        └─ The editor slides in with a slight perspective tilt (Transform)
```

This is pure Flutter `Transform` — no Lottie needed for this specific transition. Lottie is reserved for the empty state animation on the diary list (a looping "open book" animation for when there are no entries yet).

**Lottie usage plan:**
- `assets/animations/empty_diary.json` — plays on the empty diary list state
- `assets/animations/task_done.json` — a brief checkmark burst when a task is completed (optional, adds delight)

If you don't have Lottie JSON files ready, we use Flutter's own `AnimatedIcon` as a fallback — the structure is the same, just swap the asset later.

 

### Files Phase 4 Will Touch / Create

```
MODIFIED:
  lib/features/diary/diary_screen.dart
    ├─ Fix _initController() with _initialized guard
    ├─ Fix DefaultJsonConverter (real jsonEncode/jsonDecode)
    ├─ Add local_auth biometric unlock flow
    └─ Replace SlideTransition with _BookPageTransition

  lib/features/todo/todo_screen.dart
    ├─ Replace Column with AnimatedList for active tasks
    ├─ Add _TaskCard completion animation (ScaleTransition + FadeTransition)
    └─ Add checkmark burst on FocusBentoCard completion

  pubspec.yaml
    └─ Add local_auth: ^2.3.0

  android/app/src/main/AndroidManifest.xml
    └─ Add USE_BIOMETRIC permission

CREATED:
  lib/core/services/biometric_service.dart
    └─ Wraps local_auth. Single method: authenticate() → bool
       Handles unavailable, not-enrolled, and error cases gracefully.

  lib/features/diary/widgets/book_page_transition.dart
    └─ Custom PageRouteBuilder for the book-open effect

  lib/features/shared/widgets/animated_task_list.dart
    └─ AnimatedList wrapper with insert/remove animation helpers
```

### 1. Biometric — Settings Toggle

Perfect call. The architecture will be:

```
Settings screen
  └─ "Diary Lock" toggle tile
       ├─ OFF (default) → diary opens freely, Ghost Mode still blurs
       └─ ON → biometric prompt required before diary entry opens
                AND when returning from background
```

The toggle state lives in `SharedPreferences` via a new `diaryLockEnabledProvider` in `settings_provider.dart`. The `BiometricService` checks this flag before ever calling `local_auth`. If the flag is off, it returns `true` immediately — no prompt, no friction.

One additional safeguard: when the user turns the toggle **on**, we immediately run a test authentication. If their device has no biometrics enrolled, we show a dialog explaining this and revert the toggle. We never leave the toggle ON on a device that can't actually authenticate — that would be a false sense of security.

 

### 2. Page Animation — Clarifying My Approach

What I'm building is **not** a full-screen skeuomorphic diary-flipping animation. That would feel heavy and slow for a daily-use app.

The approach is **minimal and purposeful** — two layers:

**Layer 1 — The transition itself (instant feel):**
When you tap a diary entry, the date number on that row becomes a `Hero` widget. It flies from the list row into the editor header position. The editor canvas slides in underneath it. Total duration: 380ms. It feels like the page *is* the thing that opened — not a separate animation playing on top.

**Layer 2 — The decryption moment (honest feedback):**
While the `Hero` is flying, decryption is running in parallel. In the editor header, where the date lands, there is a single subtle pulse — the date text briefly fades to 60% opacity and back to 100% over 200ms. That pulse *is* the decryption indicator. No spinner, no loading bar, no "Decrypting..." text. Just a breath.

```
Tap entry row
  ├─ Hero(date number) flies to editor header    ← 380ms
  ├─ EncryptionService.decrypt() runs            ← ~5-15ms on device
  └─ Date pulses once in header                  ← signals "loading done"
```

If decryption takes longer than the transition (which should never happen for a journal entry but is theoretically possible on very old hardware), the editor shows a faint shimmer on the text area until the content is ready. No blank flash, no error.

This is minimal, premium, and honest — it never pretends the data appeared instantly, but it never makes the user wait visibly either.

 

### 3. Option A — Confirmed Trigger Points

Here are the exact three moments biometrics will fire (when the toggle is ON):

```
Trigger 1 — App backgrounded while diary editor is open
  AppLifecycleState.paused → blur immediately
  AppLifecycleState.resumed → authenticate() → lift blur on success

Trigger 2 — App killed and relaunched
  main.dart checks: was diary the last active screen? (stored in prefs)
  If yes AND diary lock is enabled → DiaryScreen starts in locked state
  User must authenticate before diary list is visible

Trigger 3 — Fresh tap to open a diary entry (when toggle is ON)
  _openEditor() calls BiometricService.authenticate() first
  Success → editor opens with Hero transition
  Failure → stays on list, shows a subtle "Authentication required" snackbar
```

Trigger 2 requires one small addition to `main.dart` — saving the last active tab index to `SharedPreferences` on every page change, so on relaunch we know if the diary was open.

 

### The Phase 4 Build Plan (Confirmed)

```
pubspec.yaml              ← add local_auth: ^2.3.0
AndroidManifest.xml       ← add USE_BIOMETRIC permission

lib/core/services/
  biometric_service.dart  ← wraps local_auth, reads diaryLockEnabled flag

lib/providers/
  settings_provider.dart  ← add diaryLockEnabledProvider (SharedPrefs toggle)

lib/features/diary/
  diary_screen.dart       ← fix round-trip, add Hero, add all 3 auth triggers
  widgets/
    diary_page_transition.dart  ← Hero + slide custom route

lib/features/todo/
  todo_screen.dart        ← AnimatedList, ScaleTransition on completion

lib/features/settings/
  settings_screen.dart    ← add "Diary Lock" toggle tile with test-auth guard

main.dart                 ← save last tab index on page change
```

## Phase 5 — Technical Architecture Plan part 1



From the original spec and our Phase 3 gaps review, Phase 5 has one clear domain: **making the Consistency tab fully alive with real data.**

Right now the Consistency screen shows:

- **Streak (real data from Phase 2)**
- **Month heatmap (real data from Phase 2)**
- **Line chart (shows app-open counts — real but limited)**
- **App usage stats (empty map — Phase 5 stub)**
- **Mood correlation (not built yet)**
- **Yearly view / date range switching (not built yet)**



### 1. The Platform Channel — `UsageStatsPlugin.kt`

This is the most technically significant piece of Phase 5. `UsageStatsManager` is a native Android API with no Flutter wrapper. The Kotlin side already exists as a stub from Phase 1 — Phase 5 uncomments and completes it.

**The full data flow:**

```
ConsistencyScreen mounts
  → ref.watch(appUsageStatsProvider)
      → AppUsageService.getTodayUsageStats()
          → MethodChannel('com.darshvici.asrio/usage_stats')
              → UsageStatsPlugin.kt
                  → UsageStatsManager.queryUsageStats(INTERVAL_DAILY, start, end)
                  → filters: totalTimeInForeground > 60_000ms (1 min minimum)
                  → returns Map<String, Long> { packageName: foregroundMs }
              ← Dart receives Map<String, int>
          → AppUsageService maps to List<AppUsageModel>
              (resolves package name → readable app name via a lookup map)
      → appUsageStatsProvider emits AsyncData(list)
  → UsagePieChart widget renders
```

**The permission problem:**
`PACKAGE_USAGE_STATS` is not a runtime permission — it requires the user to manually navigate to `Settings → Special App Access → Usage Access`. We cannot show Android's standard permission dialog for this. We must:

1. Check if permission is already granted via `AppOpsManager`
2. If not, show our own in-app explanation dialog
3. Provide a button that calls `Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)`
4. When the user returns to the app (`AppLifecycleState.resumed`), re-check and reload

This is handled by `AppUsageService` on the Dart side and `UsageStatsPlugin.hasUsagePermission()` on the Kotlin side.

 

### 2. `AppUsageModel` — The Domain Model

The raw data from `UsageStatsManager` is `{ "com.instagram.android": 3600000 }` — a package name and milliseconds. We need to humanize this before it reaches the UI:

```dart
class AppUsageModel {
  final String packageName;    // "com.instagram.android"
  final String appName;        // "Instagram"  ← resolved from package
  final int durationMs;        // 3600000 (raw)
  final double durationMinutes // 60.0  ← derived
  final double percentage;     // 0.23  ← this app / total screen time
}
```

**Package → App name resolution:**
We maintain a static lookup map of ~30 common apps in `AppUsageService`. For apps not in the map, we display the last segment of the package name (`com.instagram.android` → `instagram`). We never make a network call to resolve names — local-first contract must hold.

```dart
static const _knownApps = {
  'com.instagram.android':      'Instagram',
  'com.whatsapp':               'WhatsApp',
  'com.google.android.youtube': 'YouTube',
  'com.twitter.android':        'Twitter / X',
  'com.netflix.mediaclient':    'Netflix',
  'com.spotify.music':          'Spotify',
  // ... ~30 total
};
```

 

### 3. `UsagePieChart` — The Visual

A `fl_chart` `PieChart` in pure greyscale. The chart follows the existing B/W Noir design contract:

```
Top 5 apps + "Other" bucket
  → Sorted by duration descending
  → Colors: 6 shades from #000000 to #E0E0E0
  → Center: total screen time today ("4h 23m")
  → Tap a segment: tooltip shows app name + time + percentage
```

**Data bucketing logic (Dart-side in `ConsistencyRepository`):**
```
Raw list: [Instagram 90min, YouTube 60min, WhatsApp 45min,
           Chrome 30min, Reddit 20min, Maps 10min, ...]

Processed:
  Top 5 by duration → individual slices
  Everything else   → merged into "Other" slice
  Filter: exclude system apps (com.android.*, com.google.android.gms, etc.)
```

The system app filter is critical — without it, `com.android.systemui` and `com.google.android.gms` dominate the chart with usage time the user doesn't think of as "screen time."

 

### 4. Mood Correlation Card

The spec calls for "two thin lines — one solid black, one dotted grey — overlapping" to show mood vs productivity correlation.

**The data sources:**
- Mood: not yet stored anywhere — we need to add a `mood` column to the `diary_pages` table (`schemaVersion: 3`)
- Productivity: tasks completed per day (already queryable from Phase 2)

**The mood scale:**
Rather than complex emoji, we use a simple 1–5 integer scale stored per diary entry. The diary editor gets a subtle 5-dot mood selector (filled vs outline circles) at the bottom of the canvas. No colors — just filled vs hollow circles in black.

```
Mood stored: 1 (worst) → 5 (best)
Rendered: ● ● ● ○ ○  = mood 3
```

**The chart itself:**
A dual `LineChartBarData` in `fl_chart`:
```
Line 1 (solid black, 2.5px):   daily task completion % over 14 days
Line 2 (dashed grey, 1.5px):   daily mood score (normalized to 0–1) over 14 days
```

If mood data is sparse (user hasn't been adding moods), the mood line renders with gaps rather than interpolating fake data. Honesty over aesthetics.

**Schema change:** `schemaVersion: 2 → 3`, adds `mood INTEGER NULLABLE` to `diary_pages`.

 

### 5. Date Range Switcher

Right now the Consistency screen always shows "last 30 days". Phase 5 adds a **segmented control** at the top: `7D | 30D | 3M | Year`. This is a pure Dart-side change — all the queries already support a `days` parameter. The switcher drives a `selectedRange` state that propagates down through `ConsistencyProvider`.

```
_RangeSwitcher: [7D] [30D] [3M] [Year]
  → tapping emits to selectedRangeProvider (simple StateProvider<int>)
  → consistencyStateProvider watches selectedRangeProvider
  → all downstream providers (dailyOpenCounts, streak, usageStats) re-query
    with the new range
```

Visual: a row of 4 pills. Selected = black fill, white text. Unselected = white fill, grey text, thin border. Same pattern as the priority selector in the Add Task sheet.

 

### 6. Yearly Overview (Stretch Goal)

When `Year` is selected in the range switcher, the month heatmap expands to show all 12 months in a compact grid (GitHub-contribution style but greyscale). Each cell is a week, not a day. This is a pure Dart widget with no new queries — the existing `activeDates` set from the streak model contains all the data needed.

 

### Files Phase 5 Will Produce

```
MODIFIED:
  android/app/src/main/kotlin/com/darshvici/asrio/
    MainActivity.kt               ← uncomment UsageStatsPlugin.register()
    UsageStatsPlugin.kt           ← full implementation (was stub)

  lib/data/database/app_database.dart
    ← schemaVersion 2 → 3
    ← mood column added to DiaryPages table

  lib/data/database/daos/diary_dao.dart
    ← updateMood() method added

  lib/data/repositories/diary_repository.dart
    ← saveMood() method added
    ← DiaryEntryModel gains optional mood field

  lib/data/models/diary_entry_model.dart
    ← mood: int? field added

  lib/features/diary/diary_screen.dart
    ← MoodSelector widget added to editor canvas

  lib/features/consistency/consistency_screen.dart
    ← UsagePieChart card added
    ← MoodCorrelationCard added
    ← _RangeSwitcher added
    ← Yearly heatmap view added

  lib/providers/consistency_provider.dart
    ← selectedRangeProvider added
    ← appUsageStatsProvider connected to real AppUsageService

CREATED:
  lib/data/models/app_usage_model.dart
    ← AppUsageModel domain model

  lib/data/services/app_usage_service.dart
    ← Dart side of platform channel
    ← Package → app name resolution
    ← Permission check + Settings intent

  lib/features/consistency/widgets/
    usage_pie_chart.dart          ← fl_chart PieChart, greyscale, tap tooltips
    mood_correlation_card.dart    ← dual-line fl_chart, solid + dashed
    range_switcher.dart           ← 4-pill segmented control
    yearly_heatmap.dart           ← 52-week grid view
```

 

### Two Decisions Before Building

**Decision A — System app filtering threshold.**
I plan to filter out any app with "android" or "google" in the package name that the user likely doesn't think of as screen time (launcher, settings, dialer, etc.). But apps like `com.google.android.youtube` and `com.google.android.gm` (Gmail) ARE meaningful screen time. My approach: maintain a whitelist of `com.google.*` apps to keep, and block everything else in the `com.android.*` namespace. Does this feel right, or do you want to show everything and let the user decide?

Good catch on both. Let me answer before we build anything.

 

## Phase 5 part 2:- On the Visual

A pie chart forces the user to mentally decode arc angles into time. The list in your reference image makes the hierarchy **instantly readable** — biggest number at the top, smallest at the bottom. It also fits the Noir-Bento aesthetic far better. Pie charts feel like a corporate dashboard. A ranked list feels like a personal performance report.

**What I'll build instead:**

```
┌─────────────────────────────────────────────────────┐
│  Screen Time         TODAY                          │
│  4h 23m total                                       │
│  ─────────────────────────────────────────────────  │
│                                                     │
│  Instagram           1h 30m   ████████░░░░  34%    │
│  ─────────────────────────────────────────────────  │
│  YouTube             1h 05m   ██████░░░░░░  25%    │
│  ─────────────────────────────────────────────────  │
│  WhatsApp              45m    █████░░░░░░░  17%    │
│  ─────────────────────────────────────────────────  │
│  Chrome                30m    ███░░░░░░░░░  11%    │
│  ─────────────────────────────────────────────────  │
│  Other               33m      ███░░░░░░░░░  13%    │
└─────────────────────────────────────────────────────┘
```

Thin horizontal dividers between rows — exactly the notebook-line language we established in the Diary screen. The progress bar is a thin 3px black line on a grey track. No colors. Tapping a row is a no-op — the data is read-only.

The time-range selector from your reference image (`W M 4M 6M Y All`) becomes our `7D | 30D | 3M | Year` switcher, sitting at the top of the Consistency screen exactly like the `W M 4M 6M Y All` pill row in the image.

 

### On `AppUsageModel` and the Hardcoded App List 

Here is the honest breakdown:

**Why `AppUsageModel` is still needed:**
The raw data from Android's `UsageStatsManager` gives us two things: a package name string and a number in milliseconds. Nothing else. Before that can reach the UI, something has to:
- Convert `3600000ms` → `"1h 00m"` (human-readable duration)
- Calculate `1h / 4h 23m total = 23%` (percentage for the progress bar)
- Sort apps by duration
- Bucket small apps into the "Other" category

That transformation logic needs to live somewhere. Putting it in a model keeps it out of the widget layer. `AppUsageModel` is just a clean container for that processed data — it is genuinely necessary.

**Why the hardcoded Instagram/WhatsApp/YouTube list is NOT necessary:**

I had planned a static lookup map to convert `com.instagram.android` → `"Instagram"`. That approach is:
- Fragile — app package names change (Twitter became `com.twitter.android` then `com.x.android`)
- Limited — only works for the 30 apps I hardcoded
- Wrong — Android already knows every app's display name

The correct approach is to ask Android directly in the Kotlin plugin using `PackageManager.getApplicationLabel()`:

```kotlin
val appName = try {
    val appInfo = packageManager.getApplicationInfo(packageName, 0)
    packageManager.getApplicationLabel(appInfo).toString()
} catch (e: PackageManager.NameNotFoundException) {
    // App was uninstalled but usage history remains
    packageName.split(".").last().replaceFirstChar { it.uppercase() }
}
```

This returns `"Instagram"`, `"WhatsApp"`, `"YouTube"` — the exact same names the user sees on their home screen. It works for **every app** on the device, not just the 30 I know. No hardcoded list needed.

The Kotlin plugin returns a richer map:
```kotlin
mapOf(
    "packageName" to "com.instagram.android",
    "appName"     to "Instagram",      // ← from PackageManager
    "usageMs"     to 3600000L
)
```

So `AppUsageModel` still exists — but its `appName` field is populated by Android, not by our lookup table.

 

### Revised Phase 5 File Plan

```
UsageStatsPlugin.kt          ← Full implementation + PackageManager name resolution
MainActivity.kt              ← Uncomment plugin registration

app_usage_model.dart         ← Simple model: appName, durationMs, percentage
app_usage_service.dart       ← Dart ↔ Kotlin bridge, system app filter
app_database.dart            ← schemaVersion 2→3 (mood column)
diary_entry_model.dart       ← mood: int? field added

consistency_screen.dart      ← Replace pie chart with ranked list card
                                Add range switcher
                                Add mood correlation card
                                Add yearly heatmap view

diary_screen.dart            ← MoodSelector widget in editor

consistency_provider.dart    ← selectedRangeProvider
                                Real appUsageStatsProvider

widgets/
  usage_list_card.dart       ← The ranked app list (reference image style)
  mood_correlation_card.dart ← Dual-line chart
  range_switcher.dart        ← 7D | 30D | 3M | Year pills
  yearly_heatmap.dart        ← 52-week grid
```

**The approach I'm using — a Blocklist, not a Whitelist:**

Instead of saying "only show these 30 apps," I block the known background processes and allow everything else. This means camera, gallery, clock, calculator, phone, messages, settings — all the daily-use essentials — pass through automatically.

**Blocked (background noise, never meaningful screen time):**
```
android                    ← OS process itself
com.android.systemui       ← Status bar & notification shade
com.google.android.gms     ← Google Play Services (background)
com.google.android.gsf     ← Google Services Framework
com.android.phone          ← Phone radio service
com.android.server.telecom ← Telephony background
*.launcher*                ← Any home screen launcher
*.inputmethod.*            ← Any keyboard
*.wallpaper*               ← Wallpaper service
com.android.packageinstaller
com.google.android.permissioncontroller
```

**Passes through (kept — daily-use essentials):**
```
Camera apps      com.android.camera, com.google.android.GoogleCamera,
                 com.miui.camera, com.sec.android.app.camera
Gallery / Photos com.google.android.apps.photos, com.miui.gallery
Clock            com.google.android.deskclock, com.android.deskclock
Calculator       com.google.android.calculator, com.android.calculator2
Maps             com.google.android.apps.maps
Gmail            com.google.android.gm
Phone (UI)       com.google.android.dialer
Messages         com.google.android.apps.messaging
Calendar         com.google.android.calendar
Files            com.google.android.documentsui
Settings         com.android.settings
Play Store       com.android.vending (when user browses it)
```

The logic is: if user opens it and stares at it, it counts. If Android runs it silently in the background, it doesn't.

## Phase 5:- part 3


### Why Home Screen Mood is Architecturally Superior

**The diary editor placement had a hidden UX flaw I didn't flag clearly enough.**

When the mood selector lives inside the diary editor, the user only records their mood on days they write. If they skip writing for 3 days but still used the app, those days have no mood data — the correlation chart has gaps that aren't really gaps, they're just "didn't open diary." The mood data becomes a function of writing frequency, not actual emotional state.

**The home screen placement fixes this entirely.**

The user sees the mood card every single time they open the app — whether they write, complete tasks, or just check their streak. Mood data collection becomes independent of diary usage. The correlation chart becomes genuinely meaningful: it can now show "you were in a good mood AND productive" vs "you were productive despite low mood" — which is the actual insight the user wants.


### What the Card Should Look Like

Minimal, following the existing Bento language:

```
┌─────────────────────────────────────┐
│  How are you feeling?               │
│                                     │
│    ○  ○  ●  ○  ○                   │
│    1  2  3  4  5                   │
│                                     │
│  Last logged: Today, 9:41 AM        │
└─────────────────────────────────────┘
```

Five hollow circles. Tapping one fills it black instantly with a `HapticFeedback.selectionClick()`. The selected state is persisted immediately. If the user already logged a mood today, the card shows the current selection and allows changing it. If they haven't logged today, the circles are all hollow.

**One important constraint:** The card should only ask once per day — not every time the user opens the app. After logging, the card transitions to a "confirmed" state:

```
┌─────────────────────────────────────┐
│  Mood logged                     ✓  │
│                                     │
│    ○  ○  ●  ○  ○                   │
│                                     │
│  Tap to update                      │
└─────────────────────────────────────┘
```

The `✓` is subtle — not a celebration, just confirmation. The user can still tap a different dot to update. This is the "honest feedback without interruption" philosophy.

 

### The Data Model Implication

This changes where mood lives in the schema. Instead of a `mood` column on `diary_pages` (which is diary-dependent), mood becomes its own table:

```sql
CREATE TABLE mood_log (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  mood        INTEGER NOT NULL,   -- 1 to 5
  logged_at   DATETIME NOT NULL
);
```

One row per mood entry. The streak algorithm in `ConsistencyRepository` can now query this independently of diary activity. The correlation chart compares `mood_log` dates against `tasks` completion dates — clean separation, no coupling.

**Schema change:** `schemaVersion: 3 → 4` (we were going to 3 for mood on diary, now we skip to 4 directly and put mood in its own table).

 

### What This Means for Phase 5 Build

One new file, two modifications:

```
ADDED:
  lib/data/database/tables/    ← MoodLog table in app_database.dart
  lib/data/database/daos/mood_dao.dart
  lib/data/repositories/mood_repository.dart
  lib/providers/mood_provider.dart
  lib/features/home/widgets/mood_card.dart   ← the home screen card

MODIFIED:
  app_database.dart            ← schemaVersion 3→4, MoodLog table added
  home_screen.dart             ← MoodCard inserted between Focus Card and Bento Grid
  consistency_repository.dart  ← mood correlation queries mood_log, not diary_pages
```

The diary editor stays clean. No mood selector there at all. The canvas remains 100% distraction-free.

 

### One Risk to Flag

The home screen will now have **five sections** stacked vertically:

```
1. Greeting header
2. Focus Card (black)
3. Mood Card (white)        ← new
4. Bento Grid
5. Quick Stats
```

That is one card more than before. On small screens (5-inch phones) the user will need to scroll to reach the Bento Grid. This is acceptable — `CustomScrollView` with `BouncingScrollPhysics` already handles this gracefully. But it is worth knowing.

## Phase 5:- Part 4

The insight is that in any theme, the **dominant color = the happiest mood**. In light mode, black is the power color — so black = Happy. In dark mode, white is the power color — so white = Happy. The palette flips, but the emotional hierarchy stays the same. It feels natural because it mirrors how the theme itself works.

**Light theme mood mapping (dark = positive):**

Color | Mood |
 | |
`#000000` | Happy |
`#404040` | Fun |
`#7f7f7f` | Normal |
`#bfbfbf` | Off |
 `#ffffff` | Sad |

**Dark theme mood mapping (light = positive):**

 Color | Mood |
 | |
 `#ffffff` | Happy |
`#bfbfbf` | Fun |
`#7f7f7f` | Normal |
`#404040` | Off |
`#000000` | Sad |

`#7f7f7f` is always Normal — the midpoint is theme-invariant. That is an elegant anchor.

 

### The Circular Selector Visual

Five circles in a horizontal row. Each circle is filled with its mood color. The selected state needs a clear but minimal indicator — I'm thinking a **ring border** that uses the inverse of the circle's own color:

```
Light theme, "Fun" (#404040) selected:

  ○   ○   ○  [●]  ○
             ↑
    dark grey fill
    white outer ring (2px, 3px gap from fill)
```

The ring is separated from the fill by a 3px gap — giving the impression the circle is "lifting" off the surface. This is the "premium feel" you're asking for. No scale animation needed — the ring is enough.

For unselected circles in light theme, white circles (`#ffffff`) need a border so they're visible against the white card background. I'll add a `#E0E0E0` border on unselected circles only when their fill color is too close to the card surface.

 

### The Label Behaviour

Since the mood name changes per theme for the same color, the label must be derived dynamically — not hardcoded per circle position. The label sits below its circle, small caption text, and only shows when that circle is selected or hovered. When nothing is selected, no labels show — just five clean circles.

```
Nothing selected (clean):
  ○   ○   ○   ○   ○

"Fun" selected (light theme):
  ○   ○   ○  [●]  ○
             Fun
```
- **Collapsed after logging** — after selecting a mood, the card shrinks to a single line (`Mood · Normal · Tap to update`) so the home screen doesn't feel tall on small devices
 

### The Data Stored

In the `mood_log` table we store the integer `1–5` representing the circle's position (1 = leftmost, 5 = rightmost). The mood label shown at query time is resolved by the same theme-aware function. This means if a user changes their theme, old mood entries are re - labelled correctly — the stored integer is position-based, not label-based. No data migration needed.

## Phase 6 — Technical Plan

Looking at what remains across all screens, Phase 6 has three distinct jobs:

**Job 1 — Settings functionality** (the tiles that currently do nothing)

**Job 2 — Notification scheduling UI** (the time picker + repeat logic)

**Job 3 — App polish** (splash screen, app icon, onboarding, final touches)


### 1. Settings — Wiring the Dead Tiles

Right now two tiles in Settings are visual-only — tapping them does nothing. Phase 6 brings them to life.

**Notifications tile** opens a bottom sheet with:
- A `CupertinoTimerPicker`-style time picker (but B/W styled — no iOS blue)
- A repeat selector: Daily / Weekdays / Weekends / Custom
- A toggle per notification type: Diary reminder vs Task reminder independently
- Under the hood: `NotificationService.scheduleDailyDiaryReminder()` and `NotificationService.scheduleTaskReminder()` called on save

This connects directly to the `NotificationService` from Phase 1 that already has the channel registrations ready. The scheduling methods were stubbed — Phase 6 completes them with the correct `flutter_local_notifications` v17 API (which changed from `.schedule()` to `.zonedSchedule()` using `tz` package).

**Language tile** opens a bottom sheet listing the 22 supported locales from `AsrioLocalizationsDelegate.supportedLocales`. Tapping one calls `LocaleNotifier.setLocale()` — which already works from Phase 1. The tile just needs a UI.

 

### 2. Notification Scheduling — The Technical Problem

This is the most technically nuanced part of Phase 6. `flutter_local_notifications` v17 replaced `.schedule()` with `.zonedSchedule()` which requires the `timezone` package. We already have `timezone: ^0.9.4` in `pubspec.yaml` from transitive dependencies — we just need to initialize it.

**The full scheduling flow:**

```
User sets diary reminder to 9:00 PM daily
  → NotificationService.scheduleDailyDiaryReminder(TimeOfDay(21, 0))
      → tz.initializeTimeZones()              ← one-time init in main.dart
      → tz.local = tz.getLocation(deviceTz)  ← from device_info or platform
      → _nextInstanceOf(TimeOfDay(21, 0))     ← calculates next occurrence
      → plugin.zonedSchedule(
            id: 9000,
            scheduledDate: nextOccurrence,
            matchDateTimeComponents: DateTimeComponents.time,
            ← this is what makes it REPEAT daily at the same time
          )
```

`DateTimeComponents.time` is the key — it tells the plugin to fire at the same time every day without needing to reschedule after each delivery.

**Boot rescheduling** — the `RECEIVE_BOOT_COMPLETED` receiver already exists in `AndroidManifest.xml` from Phase 1. Phase 6 adds the actual Dart handler that reads the saved notification preferences from `SharedPreferences` and reschedules everything after reboot.

 

### 3. Onboarding Screen

First-time users landing on the home screen with zero tasks, zero diary entries, and zero mood data see nothing meaningful. Phase 6 adds a one-time onboarding flow that:

- Shows 3 swipeable slides (PageView, same as the main nav)
- Slide 1: "ASRIO — your private life OS" + the app's value proposition
- Slide 2: "Everything stays on device" — AES-256 encryption explained simply
- Slide 3: "Start your streak today" — quick task + diary setup prompt

Pure B/W design matching the app. After the last slide, a "Let's go" button marks onboarding complete in `SharedPreferences` and navigates to the main app. If `sharedPrefs.getBool('onboarding_done')` is true, it's skipped entirely.

The onboarding check happens in `main.dart` — we pass the boolean as a ProviderScope override just like the database.

 

### 4. Splash Screen & App Icon

**Splash screen** — Flutter's native splash via `flutter_native_splash` package. Configuration in `pubspec.yaml`:
```yaml
flutter_native_splash:
  color: "#FFFFFF"        # White background
  image: assets/splash/asrio_logo.png
  android_12:
    color: "#FFFFFF"
    icon_background_color: "#FFFFFF"
```


### 5. Export / Backup

The "Export Data" tile in Settings currently does nothing. Phase 6 implements a local-only export:

```
User taps Export
  → ExportService.exportAll()
      → Query all tasks, diary pages (decrypted), habits, mood logs
      → Serialize to JSON
      → Re-encrypt the whole bundle with AES-256
      → Save to device Downloads folder
      → Share sheet opens (share_plus package)
```

The exported file is `asrio_backup_YYYYMMDD.enc` — an AES-256 encrypted JSON blob. The user can save it to Google Drive, email it to themselves, etc. Import is Phase 7 if needed.

**Wipe Data** — the confirmation dialog already exists. Phase 6 wires the "Wipe" button to actually:
1. Delete all Drift tables
2. Call `EncryptionService.destroyKey()` (already written in Phase 2)
3. Clear all `SharedPreferences`
4. Navigate back to onboarding

 

### Files Phase 6 Will Produce

```
NEW:
  lib/features/onboarding/
    onboarding_screen.dart          ← 3-slide B/W intro
  
  lib/data/services/
    export_service.dart             ← JSON serialization + AES export
    notification_scheduler.dart     ← zonedSchedule wrapper + boot handler

  lib/features/settings/widgets/
    notification_bottom_sheet.dart  ← Time picker + repeat selector
    language_bottom_sheet.dart      ← Locale list selector

MODIFIED:
  pubspec.yaml
    ← flutter_native_splash, flutter_launcher_icons, share_plus, timezone
  
  main.dart
    ← tz.initializeTimeZones() + onboarding check
  
  app.dart
    ← Conditional: onboarding vs MainScreen based on prefs
  
  settings_screen.dart
    ← Wire notification tile → NotificationBottomSheet
    ← Wire language tile → LanguageBottomSheet
    ← Wire export tile → ExportService
    ← Wire wipe button → full data destruction

  data/services/notification_service.dart
    ← Replace stub .schedule() with real .zonedSchedule()
    ← Add scheduleDailyDiaryReminder() full implementation
    ← Add rescheduleAfterBoot() for RECEIVE_BOOT_COMPLETED

  providers/settings_provider.dart
    ← notificationTimeProvider (persisted TimeOfDay)
    ← notificationEnabledProvider (per type: diary, tasks)
```

Smart decisions across the board. Let me confirm my understanding before building.

 

### Decision A — Onboarding: Confirmed 

Shown exactly once. The gate is a `SharedPreferences` boolean key `asrio_onboarding_done`. It is:
- Read in `main.dart` before `runApp()`
- If `false` → `app.dart` routes to `OnboardingScreen`
- If `true` → `app.dart` routes directly to `MainScreen`
- Written to `true` only when the user taps "Let's go" on slide 3
- Never reset unless the app is uninstalled (SharedPreferences is cleared on uninstall on Android)

This means even if the user force-quits mid-onboarding, they see it again next launch — which is correct. Only completing the full flow marks it done.

 

### Decision B — Logo Assets: One Question Before Building

I have two files:
- `Asrio.png` — the app icon / splash screen logo
- `Asriofreeze.png` — the freeze/background screen (shown when app is in recents or backgrounded)



- One technical note on the freeze screen: Android's recents/overview screen captures a screenshot the moment the app is backgrounded. The freeze image needs to be applied as an `AppLifecycleState.inactive` override — we show it as a full-screen overlay before Android takes the screenshot, so the screenshot captures your branded image rather than live app content. This is the same technique used by banking apps.


 

### Decision C — Dual Export: Confirmed 

Two distinct export paths from the same "Export Data" tile. When tapped, a bottom sheet appears with two options:

```
┌─────────────────────────────────────────┐
│  Export Your Data                       │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │      Encrypted Export           │    │
│  │  .enc file · AES-256 secured    │    │
│  │  Only readable on this device   │    │
│  └─────────────────────────────────┘    │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │      Plaintext Export           │    │
│  │  .json file · Human readable    │    │
│  │  ⚠ Store this file securely     │    │
│  └─────────────────────────────────┘    │
│                                         │
│  Cancel                                 │
└─────────────────────────────────────────┘
```

Both paths produce a file and open Android's share sheet (`share_plus`). The user decides what to do with it from there — save to Drive, email, AirDrop, etc.

**Encrypted export** → `asrio_backup_20241201.enc`
The JSON is serialized then encrypted with the device's AES-256 key. Only the same device (same Keystore key) can decrypt it. Useful as a local device backup or if you reinstall with a key export.

**Plaintext export** → `asrio_backup_20241201.json`
Raw JSON of all tasks, diary entries (decrypted), habits, moods. Fully portable, human-readable. The share sheet warning is shown before the file is generated — one confirmation tap required.

Understood completely. You're describing the **native splash screen** — the window that Android shows instantly when the app process starts, before Flutter's first frame renders.

 

### What Actually Happens Without a Splash Screen

```
User taps ASRIO icon
  → Android creates the Activity window immediately
  → Shows the window background color (default: white or black)  ← THIS is the ugly flash
  → Flutter engine loads (~300-800ms on cold start)
  → Flutter renders first frame
  → User sees the app
```

That white/black flash between tap and first frame is what you're describing. Professional apps eliminate it by setting the Activity's window background to their branded asset — so the flash IS the logo, not an empty screen.

 

### The Two-Layer Splash Architecture

**Layer 1 — Native splash (the one you're describing):**
This is `flutter_native_splash`. It runs at the OS level before Flutter starts. It sets the Android `launch_background.xml` drawable to show your `Asrio.png` centered on a white background. Zero Flutter code involved — pure Android XML. This eliminates the blank flash entirely.

**Layer 2 — Flutter splash (optional animated handoff):**
After Flutter's first frame renders, some apps show a brief animated screen before navigating to onboarding or home. Given your minimal aesthetic, I'd skip this — the native splash should cut directly to onboarding or the home screen. No animation needed.

 

### What You Need to Do First

Since you haven't designed the assets yet, here is exactly what I need from you when they're ready:

**`Asrio.png`** — the app icon and splash center image.
Recommended: **1024×1024px**, square, transparent background, the logo mark in black. The splash generator will scale it down automatically for all screen densities.

**`Asriofreeze.png`** — the privacy freeze screen shown when the app goes to background.
This is different from the splash. It's a full-screen Flutter widget overlay (not native). It can be any size — the app scales it to fill the screen. Think of it like a "this app is paused" screen. Banks use their logo centered on a brand-color background. You can design this as a full-screen composition if you want, or just center the logo on white — your call.

 

### My Plan for When Assets Are Ready

```
pubspec.yaml
  ← flutter_native_splash: ^2.4.0   (generates native splash)
  ← flutter_launcher_icons: ^0.14.0  (generates all icon sizes)

assets/
  splash/
    Asrio.png              ← center image on splash screen
  icons/
    Asrio.png              ← source for launcher icon generation
  freeze/
    Asriofreeze.png        ← full-screen privacy overlay image

android/app/src/main/res/
  drawable/launch_background.xml    ← generated by flutter_native_splash
  drawable-v21/launch_background.xml
  mipmap-*/                         ← generated by flutter_launcher_icons

lib/features/diary/diary_screen.dart
  ← Replace current blur+lock-icon Ghost Mode with Asriofreeze.png overlay
  ← Same AppLifecycleState.inactive trigger, but now shows your branded image
```

## Phase 7 — Technical Plan

 

### What Phase 7 Is for

Phase 7 is the **ship it** phase. Every previous phase built features. Phase 7 makes those features bulletproof, polishes the rough edges, and produces a signed APK ready for the Play Store. There are also a handful of genuinely unfinished technical pieces from earlier phases that need completing before release.

 

### 1. The Unfinished Technical Pieces

These aren't polish — they're actual incomplete functionality from earlier phases.

**Boot Completed Receiver (Phase 6 gap):**
`notification_scheduler.dart` has `rescheduleAfterBoot()` written and ready. But the Android `BroadcastReceiver` that *calls* it doesn't exist yet. When the device reboots, Android fires `RECEIVE_BOOT_COMPLETED` — without a receiver to handle it, all scheduled diary reminders are silently lost. We need a Kotlin class:

```kotlin
// BootReceiver.kt
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            // Trigger Flutter background isolate to call
            // NotificationScheduler().rescheduleAfterBoot()
        }
    }
}
```

This requires a `FlutterEngine` in headless mode — a `FlutterEngineCache` pattern that initialises Flutter briefly just to run the Dart reschedule logic. This is a non-trivial but well-documented pattern.

**Asriofreeze.png integration:**
Phase 4 built Ghost Mode with a lock icon overlay. Phase 6 deferred `Asriofreeze.png`. Phase 7 integrates it — shown as a full-screen `Image.asset` overlay when the app goes to background *outside* the diary (inside the diary, the lock icon remains as decided). This covers: Home, Tasks, Consistency, Settings tabs going to background.

**Wipe flow fix:**
The current wipe handler in `settings_screen.dart` calls `markDone()` (sets onboarding = true) after wiping, which means the user never sees onboarding again after a wipe. The correct behaviour is `markDone()` should set it to `false` — the `OnboardingNotifier` needs a `reset()` method. Small fix, important for correctness.

**Yearly habit tracking (Phase 2/5 gap):**
The `Habits` table exists. The `HabitRepository` supports add/archive/delete. But there is no UI for tracking habit completions — the circular ring on the Home screen shows task completion percentage, not habit completion. Phase 7 adds a `habit_completions` table (schema v5) and a simple tap-to-complete interaction on habit tiles.

 

### 2. Testing

Three layers, in order of importance for a release:

**Unit tests — Repositories and Services:**
These are the most valuable tests because they catch logic errors in the code the user never sees:

```
test/
  repositories/
    task_repository_test.dart     ← add/complete/delete flow
    diary_repository_test.dart    ← encrypt → save → decrypt round-trip
    consistency_repository_test.dart ← streak algorithm (current + longest)
    mood_repository_test.dart     ← upsert logic, one-per-day constraint
  services/
    encryption_service_test.dart  ← encrypt/decrypt symmetry
    export_service_test.dart      ← JSON structure validation
```

The streak algorithm tests are especially important — the "loose" definition (today not broken unless both today AND yesterday are empty) has edge cases that are easy to get wrong: what happens on January 1st? What if the user has data from 3 years ago?

**Widget tests — Critical screens:**
```
  features/
    onboarding_screen_test.dart   ← 3 slides, markDone fires on "Let's go"
    todo_screen_test.dart         ← add task, swipe delete, complete animation
    diary_screen_test.dart        ← list → editor transition, zen mode lock
```

**Integration test — Core user journey:**
One end-to-end test that runs the full happy path:
```
1. Fresh install → onboarding appears
2. Complete onboarding → Home screen appears
3. Add a task → task appears in list
4. Complete task → moves to completed section
5. Open diary → editor opens
6. Type content → auto-save fires
7. Close diary → content persists on reopen
8. Check Consistency → streak shows 1
```

This is the test that catches the interactions *between* layers that unit tests miss.

 

### 3. Performance

**Drift query optimisation:**
The `watchAllTasks()` stream in `home_screen.dart` fetches every task every time any task changes. On a user with 200+ tasks, this is wasteful. Phase 7 adds database indexes and limits:

```dart
// Instead of fetching all tasks for the home screen summary:
Future<int> countActiveTasksToday()  // returns int, not List<Task>
Future<int> countCompletedTasksToday()
```

**`RepaintBoundary` on heavy widgets:**
The `fl_chart` line charts and the month heatmap rebuild on every parent state change. Wrapping them in `RepaintBoundary` isolates their paint layer so parent rebuilds don't force chart repaints.

**Image caching for `Asrio.png`:**
`Image.asset` in the Settings footer loads from disk on every rebuild. `const` constructor or `precacheImage()` in `main.dart` ensures it's in memory before it's needed.

 

### 4. Accessibility

Two non-negotiable items before any public release:

**Semantic labels:** Every `GestureDetector` and `InkWell` needs a `Tooltip` or `Semantics` wrapper so screen readers can announce what each tap target does. The mood circles currently have no accessibility label — a visually impaired user cannot use them.

**Text scaling:** The app uses hardcoded `fontSize` values throughout `AsrioText`. If a user has system font scale set to 1.5x, text overflows cards. Phase 7 audits every screen at 1.0x, 1.3x, and 1.5x and fixes overflow cases.

 

### 5. Play Store Preparation

**Signing the release build:**
A `key.jks` keystore file must be generated and configured in `android/app/build.gradle`. I'll provide the exact `keytool` command and `signingConfigs` block. This is a one-time setup — the keystore must be kept permanently or the app can never be updated on the Play Store.

**`build.gradle` release configuration:**
```gradle
android {
    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 34
        versionCode 1
        versionName "1.0.0"
    }
    buildTypes {
        release {
            minifyEnabled true       // ProGuard/R8 shrinks the APK
            shrinkResources true
            signingConfig signingConfigs.release
        }
    }
}
```

**Play Store assets (not code — guidance only):**
- Feature graphic: 1024×500px
- Screenshots: at least 2, recommended 4–8
- Short description: 80 characters
- Full description: up to 4,000 characters
- Content rating questionnaire

**Release build command:**
```bash
flutter build apk --release --split-per-abi
# Produces three APKs: armeabi-v7a, arm64-v8a, x86_64
# Upload arm64-v8a for modern Android devices
# Or: flutter build appbundle --release (preferred for Play Store)
```

 

### 6. Final Polish Items

**Empty state animations:**
When the diary has no entries, the Home task list is empty, or the Consistency screen has no data — we show static text right now. Phase 7 adds subtle Lottie animations for these states. The `lottie` package is already in `pubspec.yaml`.

**Haptic feedback audit:**
Every interactive element should have the correct haptic weight:
- `selectionClick` → checkbox taps, toggle switches, nav taps
- `lightImpact` → FAB, sheet opens
- `mediumImpact` → task complete, mood log
- `heavyImpact` → swipe delete, wipe data

A quick audit will find missed interactions.

**`DiaryScreen` content preview:**
Right now the diary list shows "Tap to continue writing..." for every entry regardless of content. Phase 7 decrypts the first 100 characters of each entry on load to show a real preview. This uses a background isolate so the list doesn't lag while decrypting.

## Complete File:-

```
C:\Users\Darshvici\StudioProjects\Asrio\
│
├── pubspec.yaml                                    ← Phase 6 version (REPLACE)
│
├── assets\
│   ├── Asrio.png                                   ← YOUR LOGO FILE (place here)
│   ├── Asriofreeze.png                             ← YOUR FREEZE FILE (place here)
│   ├── fonts\
│   │   ├── DMSans-Regular.ttf                      ← Download DM Sans font
│   │   ├── DMSans-Medium.ttf
│   │   └── DMSans-SemiBold.ttf
│   └── animations\                                 ← Empty for now (Lottie files later)
│
├── android\
│   └── app\
│       └── src\
│           └── main\
│               ├── AndroidManifest.xml             ← Phase 5 version (REPLACE)
│               └── kotlin\
│                   └── com\
│                       └── darshvici\
│                           └── asrio\
│                               ├── MainActivity.kt         ← Phase 5 version (REPLACE)
│                               └── UsageStatsPlugin.kt     ← Phase 5 version (NEW)
│
└── lib\
    │
    ├── main.dart                                   ← Phase 6 version
    ├── app.dart                                    ← Phase 6 version
    │
    ├── core\
    │   ├── theme\
    │   │   ├── app_theme.dart                      ← Phase 1
    │   │   ├── asrio_colors.dart                   ← Phase 3
    │   │   └── asrio_text_styles.dart              ← Phase 3
    │   │
    │   ├── localization\
    │   │   └── app_localizations_delegate.dart     ← Phase 1
    │   │
    │   ├── encryption\
    │   │   └── encryption_service.dart             ← Phase 2
    │   │
    │   ├── utils\
    │   │   └── app_exceptions.dart                 ← Phase 2
    │   │
    │   ├── services\
    │   │   └── biometric_service.dart              ← Phase 4
    │   │
    │   └── router\
    │       └── app_router.dart                     ← Phase 1 (kept for reference)
    │
    ├── data\
    │   ├── database\
    │   │   ├── app_database.dart                   ← Phase 5 version (schema v4)
    │   │   ├── app_database.g.dart                 ← AUTO-GENERATED (build_runner)
    │   │   └── daos\
    │   │       ├── tasks_dao.dart                  ← Phase 2
    │   │       ├── tasks_dao.g.dart                ← AUTO-GENERATED
    │   │       ├── diary_dao.dart                  ← Phase 2
    │   │       ├── diary_dao.g.dart                ← AUTO-GENERATED
    │   │       ├── habits_dao.dart                 ← Phase 2
    │   │       ├── habits_dao.g.dart               ← AUTO-GENERATED
    │   │       ├── activity_dao.dart               ← Phase 2
    │   │       ├── activity_dao.g.dart             ← AUTO-GENERATED
    │   │       ├── mood_dao.dart                   ← Phase 5
    │   │       └── mood_dao.g.dart                 ← AUTO-GENERATED
    │   │
    │   ├── models\
    │   │   ├── task_model.dart                     ← Phase 2
    │   │   ├── diary_entry_model.dart              ← Phase 2
    │   │   ├── habit_model.dart                    ← Phase 2 (contains StreakModel too)
    │   │   ├── mood_model.dart                     ← Phase 5
    │   │   └── app_usage_model.dart                ← Phase 5
    │   │
    │   ├── repositories\
    │   │   ├── task_repository.dart                ← Phase 2
    │   │   ├── diary_repository.dart               ← Phase 2
    │   │   ├── habit_repository.dart               ← Phase 2
    │   │   ├── consistency_repository.dart         ← Phase 2
    │   │   └── mood_repository.dart                ← Phase 5
    │   │
    │   └── services\
    │       ├── notification_service.dart           ← Phase 2 (updated Phase 4)
    │       ├── notification_scheduler.dart         ← Phase 6
    │       ├── app_usage_service.dart              ← Phase 5
    │       └── export_service.dart                 ← Phase 6
    │
    ├── providers\
    │   ├── database_provider.dart                  ← Phase 1
    │   ├── settings_provider.dart                  ← Phase 6 version (all appended)
    │   ├── repository_providers.dart               ← Phase 5 version
    │   ├── task_provider.dart                      ← Phase 2
    │   ├── diary_provider.dart                     ← Phase 2
    │   ├── habit_provider.dart                     ← Phase 2
    │   ├── mood_provider.dart                      ← Phase 5
    │   └── consistency_provider.dart               ← Phase 5 version
    │
    └── features\
        │
        ├── main_screen.dart                        ← Phase 4 version
        │
        ├── onboarding\
        │   └── onboarding_screen.dart              ← Phase 6
        │
        ├── home\
        │   ├── home_screen.dart                    ← Phase 5 version (MoodCard added)
        │   └── widgets\
        │       └── mood_card.dart                  ← Phase 5
        │
        ├── todo\
        │   ├── todo_screen.dart                    ← Phase 4 version
        │   └── widgets\                            ← Empty (widgets inline in screen)
        │
        ├── diary\
        │   ├── diary_screen.dart                   ← Phase 4 version
        │   └── widgets\
        │       └── diary_page_transition.dart      ← Phase 4
        │
        ├── consistency\
        │   ├── consistency_screen.dart             ← Phase 5 version
        │   └── widgets\
        │       ├── range_switcher.dart             ← Phase 5
        │       ├── usage_list_card.dart            ← Phase 5
        │       └── mood_correlation_card.dart      ← Phase 5
        │
        ├── settings\
        │   ├── settings_screen.dart                ← Phase 6 version
        │   └── widgets\
        │       ├── notification_bottom_sheet.dart  ← Phase 6
        │       ├── language_bottom_sheet.dart      ← Phase 6
        │       └── export_bottom_sheet.dart        ← Phase 6
        │
        └── shared\
            └── widgets\
                ├── bento_card.dart                 ← Phase 3
                └── circular_ring.dart              ← Phase 3
```



### Step 4 — Files That Have Multiple Versions (Use the Latest)

These files were updated across phases. Always use the **latest version** listed:

| File | Use Version From |
|---|---|
| `main.dart` | Phase 6 |
| `app.dart` | Phase 6 |
| `app_database.dart` | Phase 5 (schema v4) |
| `settings_provider.dart` | Phase 6 (all content appended) |
| `repository_providers.dart` | Phase 5 (clean rewrite) |
| `consistency_provider.dart` | Phase 5 (clean rewrite) |
| `diary_screen.dart` | Phase 4 (full rewrite) |
| `todo_screen.dart` | Phase 4 (full rewrite) |
| `settings_screen.dart` | Phase 6 (fully wired) |
| `home_screen.dart` | Phase 5 (MoodCard injected) |
| `main_screen.dart` | Phase 4 (last-tab persistence) |
| `MainActivity.kt` | Phase 5 (FlutterFragmentActivity) |
| `UsageStatsPlugin.kt` | Phase 5 (full implementation) |
| `AndroidManifest.xml` | Phase 5 (biometric + usage permissions) |
| `pubspec.yaml` | Phase 6 (all dependencies) |
| `notification_service.dart` | Phase 4 (scheduling methods added) |

