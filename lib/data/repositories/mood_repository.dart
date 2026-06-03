// lib/data/repositories/mood_repository.dart
//
// HARDCORE FIX: Maps from QueryRow (raw SQL result) instead of
// Drift-generated MoodLog. No MoodLog type used anywhere.

import 'package:drift/drift.dart';

import '../../core/utils/app_exceptions.dart';
import '../database/daos/mood_dao.dart';
import '../models/mood_model.dart';

class MoodRepository {
  const MoodRepository({required MoodDao moodDao}) : _dao = moodDao;

  final MoodDao _dao;

  // ── Streams ───────────────────────────────────────────────────────────────

  /// Streams today's mood entry. Null if not yet logged today.
  Stream<MoodEntry?> watchTodayMood() =>
      _dao.watchTodayMood().map((row) =>
          row == null ? null : _fromRow(row));

  /// Streams mood history for the past [days] days.
  Stream<List<MoodEntry>> watchMoodHistory({int days = 30}) =>
      _dao.watchMoodHistory(days: days)
          .map((rows) => rows.map(_fromRow).toList());

  // ── Writes ────────────────────────────────────────────────────────────────

  /// Logs or updates today's mood. [position] must be 1–5.
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

  Future<List<DateTime>> getMoodActiveDates() =>
      _dao.getMoodActiveDates();

  // ── Mapping ───────────────────────────────────────────────────────────────

  /// Maps a raw Drift [QueryRow] to a [MoodEntry] domain model.
  /// Uses the extension getters defined in mood_dao.dart.
  static MoodEntry _fromRow(QueryRow row) => MoodEntry(
        id:       row.idField,
        position: row.moodValueField,
        loggedAt: row.loggedAtField,
      );
}
