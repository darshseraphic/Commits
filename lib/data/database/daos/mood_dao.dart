// lib/data/database/daos/mood_dao.dart
//
// HARDCORE FIX: Uses raw SQL via customSelect/customStatement.
// No dependency on Drift-generated MoodLog type whatsoever.
// Completely immune to code generation field naming issues.

import 'package:drift/drift.dart';

import '../app_database.dart';

part 'mood_dao.g.dart';

@DriftAccessor(tables: [MoodLogs])
class MoodDao extends DatabaseAccessor<AppDatabase> with _$MoodDaoMixin {
  MoodDao(super.db);

  // ── SQL Column Names (Drift converts camelCase → snake_case) ──────────────
  // MoodLogs table:
  //   id        → id
  //   moodValue → mood_value
  //   loggedAt  → logged_at  (stored as milliseconds since epoch in Drift 2.x)

  static const _tbl      = 'mood_logs';
  static const _colId    = 'id';
  static const _colVal   = 'mood_value';
  static const _colAt    = 'logged_at';

  // ── Streams ───────────────────────────────────────────────────────────────

  /// Streams today's mood row as a raw [QueryRow].
  /// Returns null if no mood has been logged today.
  Stream<QueryRow?> watchTodayMood() {
    final range = _todayRange();
    return customSelect(
      'SELECT * FROM $_tbl '
      'WHERE $_colAt >= ? AND $_colAt < ? '
      'ORDER BY $_colAt DESC LIMIT 1',
      variables: [Variable(range.$1), Variable(range.$2)],
      readsFrom: {moodLogs},
    ).watchSingleOrNull();
  }

  /// Streams mood rows for the past [days] days.
  Stream<List<QueryRow>> watchMoodHistory({int days = 30}) {
    final cutoff = DateTime.now()
        .subtract(Duration(days: days))
        .millisecondsSinceEpoch;
    return customSelect(
      'SELECT * FROM $_tbl WHERE $_colAt >= ? ORDER BY $_colAt ASC',
      variables: [Variable(cutoff)],
      readsFrom: {moodLogs},
    ).watch();
  }

  // ── Writes ────────────────────────────────────────────────────────────────

  /// Inserts or replaces today's mood. One entry per calendar day.
  Future<void> upsertTodayMood(int value) async {
    final range = _todayRange();

    // Delete today's existing entry.
    await customStatement(
      'DELETE FROM $_tbl WHERE $_colAt >= ? AND $_colAt < ?',
      [range.$1, range.$2],
    );

    // Insert fresh entry.
    await customStatement(
      'INSERT INTO $_tbl ($_colVal, $_colAt) VALUES (?, ?)',
      [value, DateTime.now().millisecondsSinceEpoch],
    );
  }

  // ── Queries ───────────────────────────────────────────────────────────────

  /// Returns all unique calendar dates that have a mood entry.
  Future<List<DateTime>> getMoodActiveDates() async {
    // logged_at is stored as milliseconds → divide by 1000 for unixepoch.
    final rows = await customSelect(
      "SELECT DISTINCT DATE($_colAt / 1000, 'unixepoch') AS mood_date "
      "FROM $_tbl ORDER BY mood_date ASC",
      readsFrom: {moodLogs},
    ).get();

    return rows
        .map((r) => DateTime.parse(r.read<String>('mood_date')))
        .toList();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Returns (dayStartMs, dayEndMs) for the current calendar day.
  static (int, int) _todayRange() {
    final now      = DateTime.now();
    final start    = DateTime(now.year, now.month, now.day)
        .millisecondsSinceEpoch;
    final end      = start + const Duration(days: 1).inMilliseconds;
    return (start, end);
  }
}

// ── QueryRow Helpers (used by MoodRepository) ─────────────────────────────────

extension MoodQueryRow on QueryRow {
  /// The stored mood value (1–5).
  int get moodValueField => read<int>('mood_value');

  /// The log timestamp, decoded from milliseconds.
  DateTime get loggedAtField =>
      DateTime.fromMillisecondsSinceEpoch(read<int>('logged_at'));

  int get idField => read<int>('id');
}
