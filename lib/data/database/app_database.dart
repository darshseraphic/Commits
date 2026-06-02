// lib/data/database/app_database.dart
//
// ══════════════════════════════════════════════════════════════════════════════
// ASRIO — Drift SQLite Database
// ══════════════════════════════════════════════════════════════════════════════
//
// WHY DRIFT instead of raw sqflite?
//
//   sqflite:  You write SQL strings. A typo in 'SELCT * FORM tasks' is found
//             at runtime on a user's phone.
//   Drift:    You write Dart table definitions. The generator produces type-safe
//             query methods. A typo in a column name is a COMPILE ERROR.
//
// Drift also gives us:
//   - Streams: query results that automatically update when the DB changes.
//   - Migrations: a structured, versioned way to evolve the schema.
//   - WAL mode: better concurrent read performance (multiple reads + one write).
//
// CODE GENERATION:
//   Run: flutter pub run build_runner build --delete-conflicting-outputs
//   This generates: app_database.g.dart (the _$AppDatabase mixin).
//   The 'part' directive below links this file to the generated file.
//
// SECURITY:
//   DiaryPages stores ONLY encrypted content. The 'encryptedContent' column
//   holds an AES-256 ciphertext blob, and 'iv' holds the Initialization Vector.
//   Plaintext NEVER touches the database. This is enforced architecturally —
//   only DiaryRepository can write to DiaryPages, and it always encrypts first.
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// This 'part' directive connects this file to the Drift-generated code.
// The file doesn't exist until you run build_runner for the first time.
part 'app_database.g.dart';

// ══════════════════════════════════════════════════════════════════════════════
// TABLE DEFINITIONS
//
// Each class extending 'Table' generates a SQL table.
// Column types: IntColumn, TextColumn, BoolColumn, BlobColumn, DateTimeColumn.
// Drift maps these to SQLite types automatically.
// ══════════════════════════════════════════════════════════════════════════════

/// Stores daily and yearly to-do tasks.
///
/// The 'type' column differentiates daily tasks ('daily') from
/// yearly goals ('yearly'). The UI's dropdown selector filters on this.
@DataClassName('Task') // Names the generated data class 'Task' instead of 'Tasksdata'.
class Tasks extends Table {
  IntColumn  get id          => integer().autoIncrement()();
  TextColumn get title       => text().withLength(min: 1, max: 300)();
  TextColumn get description => text().withDefault(const Constant(''))();
  /// 'daily' or 'yearly'. Using a string (not an enum) for SQLite compatibility.
  TextColumn get type        => text().withDefault(const Constant('daily'))();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt  => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get dueDate    => dateTime().nullable()();
  /// Sort order within a section (for drag-to-reorder, Phase 2).
  IntColumn get sortOrder    => integer().withDefault(const Constant(0))();
}

/// Stores diary pages.
///
/// ⚠ SECURITY CONTRACT:
///   'encryptedContent' MUST always contain AES-256 ciphertext — never plaintext.
///   'iv' MUST always contain the corresponding Initialization Vector.
///   Violating this contract means user diary data is stored unprotected on disk.
///
///   The only class permitted to write to this table is DiaryRepository.
///   DiaryRepository calls EncryptionService BEFORE calling the DAO.
@DataClassName('DiaryPage')
class DiaryPages extends Table {
  IntColumn  get id               => integer().autoIncrement()();
  /// AES-256-CBC ciphertext of the QuillDelta JSON string. Never store plaintext.
  BlobColumn get encryptedContent => blob()();
  /// The 16-byte AES Initialization Vector. Unique per page. Required for decrypt.
  BlobColumn get iv               => blob()();
  /// Which page number within a diary session (1-based: first page = 1).
  IntColumn  get pageNumber       => integer()();
  /// The date this entry belongs to (date only — time is irrelevant for diary).
  DateTimeColumn get entryDate    => dateTime()();
  DateTimeColumn get updatedAt    => dateTime().withDefault(currentDateAndTime)();

  /// Composite constraint: each (entryDate, pageNumber) pair must be unique.
  /// Prevents accidentally creating two "page 1" entries for the same date.
  @override
  List<Set<Column>> get uniqueKeys => [
        {entryDate, pageNumber},
      ];
}

/// Stores habits for the Consistency tab.
///
/// Phase 4 will add: completionLog (separate table), streakCount, frequency.
@DataClassName('Habit')
class Habits extends Table {
  IntColumn  get id         => integer().autoIncrement()();
  TextColumn get title      => text().withLength(min: 1, max: 150)();
  TextColumn get description => text().withDefault(const Constant(''))();
  /// Icon identifier string (e.g., 'star', 'book', 'run').
  /// Mapped to Flutter Icons in the UI layer — not a raw codepoint.
  TextColumn get iconName   => text().withDefault(const Constant('star'))();
  TextColumn get category   => text().withDefault(const Constant('general'))();
  /// Soft-delete: archived habits are hidden from the main view but preserved.
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Logs every time the user opens the app.
///
/// This powers the line chart on the Consistency tab (X = day, Y = time of open).
/// Each cold start of the app inserts one row via [AppDatabase.logAppOpen()].
///
/// Privacy note: this data never leaves the device. It is ASRIO-internal only.
@DataClassName('ActivityEntry')
class ActivityLog extends Table {
  IntColumn  get id       => integer().autoIncrement()();
  DateTimeColumn get openedAt => dateTime().withDefault(currentDateAndTime)();
}

// ══════════════════════════════════════════════════════════════════════════════
// DATABASE CLASS
// ══════════════════════════════════════════════════════════════════════════════

/// The single [AppDatabase] instance for the entire app.
///
/// Access it via [databaseProvider] in Riverpod. Never construct it directly
/// inside a widget — that would create a second DB connection to the same file,
/// which SQLite handles poorly.
@DriftDatabase(tables: [Tasks, DiaryPages, Habits, ActivityLog])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  // ── Schema Version ─────────────────────────────────────────────────────────
  //
  // RULE: Increment schemaVersion EVERY time you change the table structure.
  // A version bump without a migration strategy will corrupt existing databases.
  // See MigrationStrategy.onUpgrade below for how to write migrations.
  @override
  int get schemaVersion => 1;

  // ── Migration Strategy ────────────────────────────────────────────────────
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          // First install: create every table from scratch.
          await m.createAll();
        },

        onUpgrade: (Migrator m, int from, int to) async {
          // Future migration example (do not implement yet — schemaVersion is 1):
          //
          // if (from < 2) {
          //   // Phase 2: Added 'priority' column to tasks.
          //   await m.addColumn(tasks, tasks.priority);
          // }
          // if (from < 3) {
          //   // Phase 4: Added completionLog table for habit streaks.
          //   await m.createTable(completionLog);
          // }
          //
          // Drift runs these in order, so upgrading from 1→3 runs both blocks.
        },

        beforeOpen: (OpeningDetails details) async {
          // WAL (Write-Ahead Logging): allows simultaneous reads during a write.
          // This is especially important for the Consistency tab which reads
          // multiple tables while the diary might be writing concurrently.
          await customStatement('PRAGMA journal_mode=WAL;');

          // SQLite disables foreign keys by default (for legacy compatibility).
          // We enable them explicitly to catch referential integrity violations.
          await customStatement('PRAGMA foreign_keys=ON;');

          if (details.wasCreated) {
            // First-time setup: seed any default data here in future phases.
            // e.g., default habits, onboarding tasks.
          }
        },
      );

  // ── Convenience Methods ───────────────────────────────────────────────────
  //
  // Simple, frequently-used operations can live directly on AppDatabase.
  // Complex queries belong in a DAO class. This boundary keeps AppDatabase clean.

  /// Records a single app-open event for the Consistency tab's line chart.
  ///
  /// Called from main.dart on every cold start. Fire-and-forget.
  Future<void> logAppOpen() => into(activityLog).insert(
        ActivityLogCompanion(openedAt: Value(DateTime.now())),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// DATABASE CONNECTION
// ══════════════════════════════════════════════════════════════════════════════

/// Creates a [LazyDatabase] that opens the SQLite file on first use.
///
/// WHY LazyDatabase?
/// [getApplicationDocumentsDirectory()] is an async call (platform channel).
/// LazyDatabase defers this call until the first actual database operation,
/// so AppDatabase() can be constructed synchronously in main.dart without
/// blocking app startup.
///
/// The database file is stored in the app's private documents directory:
///   Android: /data/data/com.darshvici.asrio/files/asrio.db
///
/// This path is sandboxed — no other app can read it, and it is excluded
/// from Android Auto-Backup when we set android:allowBackup="false".
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'asrio.db'));
    return NativeDatabase.createInBackground(
      file,
      // logStatements: true, // Uncomment to log all SQL queries in debug mode.
    );
  });
}
