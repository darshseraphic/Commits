// lib/data/database/app_database.dart
//
// ══════════════════════════════════════════════════════════════════════════════
// ASRIO — Drift SQLite Database
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// DAO Imports (Ensure these match your file structure)
import 'daos/tasks_dao.dart';
import 'daos/diary_dao.dart';
import 'daos/habits_dao.dart';
import 'daos/activity_dao.dart';
import 'daos/mood_dao.dart';

part 'app_database.g.dart';

// ══════════════════════════════════════════════════════════════════════════════
// TABLE DEFINITIONS
// ══════════════════════════════════════════════════════════════════════════════

@DataClassName('Task')
class Tasks extends Table {
  IntColumn  get id          => integer().autoIncrement()();
  TextColumn get title       => text().withLength(min: 1, max: 300)();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get type        => text().withDefault(const Constant('daily'))();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt  => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get dueDate    => dateTime().nullable()();
  IntColumn get sortOrder    => integer().withDefault(const Constant(0))();

  // Newly added columns for Phase 6 Notifications & Priority
  IntColumn get notificationId => integer().nullable()();
  TextColumn get priority      => text().withDefault(const Constant('low'))();
}

@DataClassName('DiaryPage')
class DiaryPages extends Table {
  IntColumn  get id               => integer().autoIncrement()();
  BlobColumn get encryptedContent => blob()();
  BlobColumn get iv               => blob()();
  IntColumn  get pageNumber       => integer()();
  DateTimeColumn get entryDate    => dateTime()();
  DateTimeColumn get updatedAt    => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {entryDate, pageNumber},
  ];
}

@DataClassName('Habit')
class Habits extends Table {
  IntColumn  get id         => integer().autoIncrement()();
  TextColumn get title      => text().withLength(min: 1, max: 150)();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get iconName   => text().withDefault(const Constant('star'))();
  TextColumn get category   => text().withDefault(const Constant('general'))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('ActivityEntry')
class ActivityLog extends Table {
  IntColumn  get id       => integer().autoIncrement()();
  DateTimeColumn get openedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('MoodLog')
class MoodLogs extends Table {
  IntColumn  get id       => integer().autoIncrement()();
  IntColumn  get rating   => integer()();
  TextColumn get note     => text().withDefault(const Constant(''))();
  DateTimeColumn get loggedAt => dateTime().withDefault(currentDateAndTime)();
}

// ══════════════════════════════════════════════════════════════════════════════
// DATABASE CLASS
// ══════════════════════════════════════════════════════════════════════════════

@DriftDatabase(
  tables: [
    Tasks,
    DiaryPages,
    Habits,
    ActivityLog,
    MoodLogs,
  ],
  daos: [
    TasksDao,
    DiaryDao,
    HabitsDao,
    ActivityDao,
    MoodDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      // Migrations will go here in the future
    },
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA journal_mode=WAL;');
      await customStatement('PRAGMA foreign_keys=ON;');
    },
  );

  Future<void> logAppOpen() => into(activityLog).insert(
    ActivityLogCompanion(openedAt: Value(DateTime.now())),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// DATABASE CONNECTION
// ══════════════════════════════════════════════════════════════════════════════

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'asrio.db'));
    return NativeDatabase.createInBackground(
      file,
    );
  });
}