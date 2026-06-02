// lib/data/database/daos/tasks_dao.dart
//
// ══════════════════════════════════════════════════════════════════════════════
// TasksDao — Data Access Object
// ══════════════════════════════════════════════════════════════════════════════
//
// ARCHITECTURE RULE: This class knows SQL and nothing else.
//
// No business logic, no notification scheduling, no encryption.
// Every method is a direct mapping to one SQL operation.
// TaskRepository calls this DAO and adds the orchestration layer on top.
//
// WHY @DriftAccessor(tables: [Tasks])?
// This tells Drift's code generator to include only the Tasks table in the
// generated mixin for this DAO. Smaller generated code, cleaner separation.
// ══════════════════════════════════════════════════════════════════════════════

import 'package:drift/drift.dart';

import '../app_database.dart';

part 'tasks_dao.g.dart';

@DriftAccessor(tables: [Tasks])
class TasksDao extends DatabaseAccessor<AppDatabase> with _$TasksDaoMixin {
  TasksDao(super.db);

  // ── Streams (Live Queries) ────────────────────────────────────────────────
  //
  // Drift Streams are the core of ASRIO's reactivity.
  // Every time a row in the tasks table changes (insert/update/delete),
  // these streams emit a new list. The provider layer watches these streams;
  // the UI never needs to manually refresh.

  /// Streams all non-archived daily tasks, ordered by sort position then creation time.
  Stream<List<Task>> watchDailyTasks() => (select(tasks)
        ..where((t) => t.type.equals('daily'))
        ..orderBy([
          (t) => OrderingTerm.asc(t.sortOrder),
          (t) => OrderingTerm.desc(t.createdAt),
        ]))
      .watch();

  /// Streams all yearly goal tasks.
  Stream<List<Task>> watchYearlyTasks() => (select(tasks)
        ..where((t) => t.type.equals('yearly'))
        ..orderBy([
          (t) => OrderingTerm.asc(t.sortOrder),
          (t) => OrderingTerm.desc(t.createdAt),
        ]))
      .watch();

  /// Streams all tasks regardless of type — used by the home screen summary card.
  Stream<List<Task>> watchAllTasks() =>
      (select(tasks)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();

  // ── One-shot Reads ────────────────────────────────────────────────────────

  /// Fetches a single task by its primary key.
  /// Returns null if no task with [id] exists.
  Future<Task?> findById(int id) =>
      (select(tasks)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Fetches all tasks completed on [date] — used by streak calculation.
  Future<List<Task>> getCompletedOnDate(DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return (select(tasks)
          ..where((t) =>
              t.isCompleted.equals(true) &
              t.createdAt.isBiggerOrEqualValue(dayStart) &
              t.createdAt.isSmallerThanValue(dayEnd)))
        .get();
  }

  // ── Writes ────────────────────────────────────────────────────────────────

  /// Inserts a new task and returns its auto-generated primary key.
  Future<int> insertTask(TasksCompanion companion) =>
      into(tasks).insert(companion);

  /// Replaces a task row entirely. Throws if the id does not exist.
  Future<bool> updateTask(TasksCompanion companion) =>
      update(tasks).replace(companion);

  /// Marks a task as complete or incomplete.
  Future<void> setCompleted(int taskId, {required bool completed}) =>
      (update(tasks)..where((t) => t.id.equals(taskId)))
          .write(TasksCompanion(isCompleted: Value(completed)));

  /// Stores the flutter_local_notifications ID for this task's reminder.
  /// Called by TaskRepository after a notification is successfully scheduled.
  Future<void> updateNotificationId(int taskId, int? notificationId) =>
      (update(tasks)..where((t) => t.id.equals(taskId)))
          .write(TasksCompanion(notificationId: Value(notificationId)));

  /// Updates the sort order for a task (drag-to-reorder in Phase 3 UI).
  Future<void> updateSortOrder(int taskId, int newOrder) =>
      (update(tasks)..where((t) => t.id.equals(taskId)))
          .write(TasksCompanion(sortOrder: Value(newOrder)));

  /// Permanently deletes a task. The caller is responsible for cancelling
  /// any associated notification before calling this.
  Future<int> deleteTask(int taskId) =>
      (delete(tasks)..where((t) => t.id.equals(taskId))).go();

  // ── Aggregates ────────────────────────────────────────────────────────────

  /// Returns the count of tasks completed today. Used in the home screen summary.
  Future<int> countCompletedToday() async {
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final countExpr = tasks.id.count();
    final query = selectOnly(tasks)
      ..addColumns([countExpr])
      ..where(
        tasks.isCompleted.equals(true) &
        tasks.createdAt.isBiggerOrEqualValue(dayStart) &
        tasks.createdAt.isSmallerThanValue(dayEnd),
      );
    final row = await query.getSingle();
    return row.read(countExpr) ?? 0;
  }

  /// Returns all unique dates (day precision) that have at least one
  /// completed task. Used by the streak calculation algorithm.
  Future<List<DateTime>> getActiveDatesByCompletedTasks() async {
    // Raw SQL is the cleanest approach for a DATE() grouping query.
    // Drift's typesafe API doesn't have a built-in DATE() function.
    final result = await customSelect(
      '''
      SELECT DISTINCT DATE(created_at / 1000, 'unixepoch') AS active_date
      FROM tasks
      WHERE is_completed = 1
      ORDER BY active_date ASC
      ''',
      readsFrom: {tasks},
    ).get();

    return result.map((row) {
      final dateStr = row.read<String>('active_date');
      return DateTime.parse(dateStr);
    }).toList();
  }
}
