// lib/data/database/daos/mood_dao.dart

import 'package:drift/drift.dart';
import '../app_database.dart';

part 'mood_dao.g.dart';

@DriftAccessor(tables: [MoodLogs])
class MoodDao extends DatabaseAccessor<AppDatabase> with _$MoodDaoMixin {
  MoodDao(super.db);

  // ── Streams ───────────────────────────────────────────────────────────────

  /// Streams today's mood entry (null if not yet logged today).
  Stream<MoodLog?> watchTodayMood() {
    final now      = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    final dayEnd   = dayStart.add(const Duration(days: 1));

    return (select(moodLogs)
          ..where((m) =>
              m.loggedAt.isBiggerOrEqualValue(dayStart) &
              m.loggedAt.isSmallerThanValue(dayEnd))
          ..orderBy([(m) => OrderingTerm.desc(m.loggedAt)])
          ..limit(1))
        .watchSingleOrNull();
  }

  /// Streams mood logs for the past [days] days.
  /// Used by the correlation chart on the Consistency screen.
  Stream<List<MoodLog>> watchMoodHistory({int days = 30}) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return (select(moodLogs)
          ..where((m) => m.loggedAt.isBiggerOrEqualValue(cutoff))
          ..orderBy([(m) => OrderingTerm.asc(m.loggedAt)]))
        .watch();
  }

  // ── Writes ────────────────────────────────────────────────────────────────

  /// Inserts or replaces today's mood.
  /// Only one mood entry per calendar day is allowed (UNIQUE on date).
  Future<void> upsertTodayMood(int position) async {
    final now      = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    final dayEnd   = dayStart.add(const Duration(days: 1));

    // Delete today's existing entry first (simplest upsert for datetime key).
    await (delete(moodLogs)
          ..where((m) =>
              m.loggedAt.isBiggerOrEqualValue(dayStart) &
              m.loggedAt.isSmallerThanValue(dayEnd)))
        .go();

    await into(moodLogs).insert(
      MoodLogsCompanion.insert(
        moodValue: position,
        loggedAt: Value(DateTime.now()),
      ),
    );
  }

  // ── Queries ───────────────────────────────────────────────────────────────

  /// Returns all unique dates that have a mood entry.
  /// Merged with task/diary dates for streak calculation.
  Future<List<DateTime>> getMoodActiveDates() async {
    final result = await customSelect(
      '''
      SELECT DISTINCT DATE(logged_at / 1000, 'unixepoch') AS mood_date
      FROM mood_logs
      ORDER BY mood_date ASC
      ''',
      readsFrom: {moodLogs},
    ).get();

    return result
        .map((r) => DateTime.parse(r.read<String>('mood_date')))
        .toList();
  }
}
