// lib/data/database/daos/habits_dao.dart

import 'package:drift/drift.dart';

import '../app_database.dart';

part 'habits_dao.g.dart';

@DriftAccessor(tables: [Habits])
class HabitsDao extends DatabaseAccessor<AppDatabase> with _$HabitsDaoMixin {
  HabitsDao(super.db);

  // ── Streams ───────────────────────────────────────────────────────────────

  /// Streams all non-archived habits, alphabetical by title.
  Stream<List<Habit>> watchActiveHabits() =>
      (select(habits)
            ..where((h) => h.isArchived.equals(false))
            ..orderBy([(h) => OrderingTerm.asc(h.title)]))
          .watch();

  /// Streams all habits including archived ones (Settings screen).
  Stream<List<Habit>> watchAllHabits() =>
      (select(habits)..orderBy([(h) => OrderingTerm.asc(h.title)])).watch();

  // ── One-shot Reads ────────────────────────────────────────────────────────

  Future<Habit?> findById(int id) =>
      (select(habits)..where((h) => h.id.equals(id))).getSingleOrNull();

  // ── Writes ────────────────────────────────────────────────────────────────

  Future<int> insertHabit(HabitsCompanion companion) =>
      into(habits).insert(companion);

  Future<bool> updateHabit(HabitsCompanion companion) =>
      update(habits).replace(companion);

  /// Soft-delete: sets isArchived to true. The row is preserved for
  /// historical streak data but hidden from the active habits list.
  Future<void> archiveHabit(int habitId) =>
      (update(habits)..where((h) => h.id.equals(habitId)))
          .write(const HabitsCompanion(isArchived: Value(true)));

  Future<void> unarchiveHabit(int habitId) =>
      (update(habits)..where((h) => h.id.equals(habitId)))
          .write(const HabitsCompanion(isArchived: Value(false)));

  /// Hard-delete — only called if the user explicitly removes an archived habit.
  Future<int> deleteHabit(int habitId) =>
      (delete(habits)..where((h) => h.id.equals(habitId))).go();
}
