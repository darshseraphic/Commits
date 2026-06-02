// lib/data/repositories/mood_repository.dart

import '../../core/utils/app_exceptions.dart';
import '../database/app_database.dart';
import '../database/daos/mood_dao.dart';
import '../models/mood_model.dart';

class MoodRepository {
  const MoodRepository({required MoodDao moodDao}) : _dao = moodDao;

  final MoodDao _dao;

  // ── Streams ───────────────────────────────────────────────────────────────

  /// Streams today's mood entry, mapped to domain model.
  Stream<MoodEntry?> watchTodayMood() =>
      _dao.watchTodayMood().map((row) => row == null ? null : _toModel(row));

  /// Streams mood history for the past [days] days.
  Stream<List<MoodEntry>> watchMoodHistory({int days = 30}) =>
      _dao.watchMoodHistory(days: days)
          .map((rows) => rows.map(_toModel).toList());

  // ── Writes ────────────────────────────────────────────────────────────────

  /// Logs or updates today's mood.
  /// [position] must be between 1 and 5.
  Future<void> logMood(int position) async {
    if (position < 1 || position > 5) {
      throw const ValidationException(
          'Mood position must be between 1 and 5.');
    }
    try {
      await _dao.upsertTodayMood(position);
    } catch (e) {
      throw DatabaseException('Failed to save mood.', cause: e);
    }
  }

  // ── Queries ───────────────────────────────────────────────────────────────

  Future<List<DateTime>> getMoodActiveDates() => _dao.getMoodActiveDates();

  // ── Mapping ───────────────────────────────────────────────────────────────

  static MoodEntry _toModel(MoodLog row) => MoodEntry(
        id: row.id,
        position: row.position,
        loggedAt: row.loggedAt,
      );
}
