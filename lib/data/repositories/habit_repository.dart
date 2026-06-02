// lib/data/repositories/habit_repository.dart

import 'package:drift/drift.dart';

import '../../core/utils/app_exceptions.dart';
import '../database/daos/habits_dao.dart';
import '../database/app_database.dart';
import '../models/habit_model.dart';

class HabitRepository {
  const HabitRepository({required HabitsDao habitsDao}) : _dao = habitsDao;

  final HabitsDao _dao;

  // ── Streams ───────────────────────────────────────────────────────────────

  Stream<List<HabitModel>> watchActiveHabits() =>
      _dao.watchActiveHabits().map((rows) => rows.map(_toModel).toList());

  Stream<List<HabitModel>> watchAllHabits() =>
      _dao.watchAllHabits().map((rows) => rows.map(_toModel).toList());

  // ── Writes ────────────────────────────────────────────────────────────────

  Future<HabitModel> addHabit({
    required String title,
    String description = '',
    String iconName = 'star',
    String category = 'general',
  }) async {
    if (title.trim().isEmpty) {
      throw const ValidationException('Habit title cannot be empty.');
    }

    final int id;
    try {
      id = await _dao.insertHabit(
        HabitsCompanion.insert(
          title: title.trim(),
          description: Value(description.trim()),
          iconName: Value(iconName),
          category: Value(category),
        ),
      );
    } catch (e) {
      throw DatabaseException('Failed to save habit "$title".', cause: e);
    }

    final created = await _dao.findById(id);
    if (created == null) throw const DatabaseException('Habit not found after insert.');
    return _toModel(created);
  }

  Future<HabitModel> updateHabit(HabitModel habit) async {
    try {
      await _dao.updateHabit(
        HabitsCompanion(
          id: Value(habit.id),
          title: Value(habit.title),
          description: Value(habit.description),
          iconName: Value(habit.iconName),
          category: Value(habit.category),
          isArchived: Value(habit.isArchived),
        ),
      );
    } catch (e) {
      throw DatabaseException('Failed to update habit "${habit.title}".', cause: e);
    }

    final updated = await _dao.findById(habit.id);
    if (updated == null) throw NotFoundException('Habit ${habit.id} not found after update.');
    return _toModel(updated);
  }

  Future<void> archiveHabit(int habitId) async {
    try {
      await _dao.archiveHabit(habitId);
    } catch (e) {
      throw DatabaseException('Failed to archive habit $habitId.', cause: e);
    }
  }

  Future<void> deleteHabit(int habitId) async {
    try {
      await _dao.deleteHabit(habitId);
    } catch (e) {
      throw DatabaseException('Failed to delete habit $habitId.', cause: e);
    }
  }

  // ── Mapping ───────────────────────────────────────────────────────────────

  static HabitModel _toModel(Habit row) => HabitModel(
        id: row.id,
        title: row.title,
        description: row.description,
        iconName: row.iconName,
        category: row.category,
        isArchived: row.isArchived,
        createdAt: row.createdAt,
      );
}
