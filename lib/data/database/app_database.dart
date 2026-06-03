// lib/data/database/app_database.dart — Schema Version 4
//
// CHANGELOG:
//   v1 → v2: notificationId + priority columns on Tasks.
//   v2 → v3: (skipped — mood moved off diary_pages into own table)
//   v3 → v4: MoodLog table added (mood_log).

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'daos/activity_dao.dart';
import 'daos/diary_dao.dart';
import 'daos/habits_dao.dart';
import 'daos/mood_dao.dart';
import 'daos/tasks_dao.dart';

part 'app_database.g.dart';

// ── Tables ────────────────────────────────────────────────────────────────────

@DataClassName('Task')
class Tasks extends Table {
  IntColumn    get id             => integer().autoIncrement()();
  TextColumn   get title          => text().withLength(min: 1, max: 300)();
  TextColumn   get description    => text().withDefault(const Constant(''))();
  TextColumn   get type           => text().withDefault(const Constant('daily'))();
  TextColumn   get priority       => text().withDefault(const Constant('none'))();
  BoolColumn   get isCompleted    => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt    => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get dueDate      => dateTime().nullable()();
  IntColumn    get sortOrder      => integer().withDefault(const Constant(0))();
  IntColumn    get notificationId => integer().nullable()();
}

@DataClassName('DiaryPage')
class DiaryPages extends Table {
  IntColumn    get id               => integer().autoIncrement()();
  BlobColumn   get encryptedContent => blob()();
  BlobColumn   get iv               => blob()();
  IntColumn    get pageNumber       => integer()();
  DateTimeColumn get entryDate      => dateTime()();
  DateTimeColumn get updatedAt      => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [{entryDate, pageNumber}];
}

@DataClassName('Habit')
class Habits extends Table {
  IntColumn    get id          => integer().autoIncrement()();
  TextColumn   get title       => text().withLength(min: 1, max: 150)();
  TextColumn   get description => text().withDefault(const Constant(''))();
  TextColumn   get iconName    => text().withDefault(const Constant('star'))();
  TextColumn   get category    => text().withDefault(const Constant('general'))();
  BoolColumn   get isArchived  => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('ActivityEntry')
class ActivityLog extends Table {
  IntColumn    get id       => integer().autoIncrement()();
  DateTimeColumn get openedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Stores daily mood entries from the home screen mood card.
///
/// position: 1 (leftmost circle) → 5 (rightmost circle).
/// Label resolved at render time from position + active theme.
/// One row per day — upsert on the date key ensures no duplicates.
@DataClassName('MoodLog')
class MoodLogs extends Table {
  IntColumn    get id        => integer().autoIncrement()();
  IntColumn    get moodValue => integer()();   // 1–5 (renamed from position — Drift reserved word)
  DateTimeColumn get loggedAt => dateTime().withDefault(currentDateAndTime)();

  // Unique on date — only one mood per calendar day.
  @override
  List<Set<Column>> get uniqueKeys => [{loggedAt}];
}

// ── Database ──────────────────────────────────────────────────────────────────

@DriftDatabase(
  tables: [Tasks, DiaryPages, Habits, ActivityLog, MoodLogs],
  daos: [TasksDao, DiaryDao, HabitsDao, ActivityDao, MoodDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async => m.createAll(),

        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(tasks, tasks.notificationId);
            await m.addColumn(tasks, tasks.priority);
          }
          // v2→v3 was skipped (mood redesigned to own table).
          if (from < 4) {
            await m.createTable(moodLogs);
          }
        },

        beforeOpen: (details) async {
          await customStatement('PRAGMA journal_mode=WAL;');
          await customStatement('PRAGMA foreign_keys=ON;');
        },
      );

  Future<void> logAppOpen() => into(activityLog)
      .insert(ActivityLogCompanion(openedAt: Value(DateTime.now())));
}

// ── Connection ────────────────────────────────────────────────────────────────

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir  = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'asrio.db'));
    return NativeDatabase.createInBackground(file);
  });
}
