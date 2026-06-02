// lib/data/database/daos/activity_dao.dart
//
// Reads the activity_log table populated by AppDatabase.logAppOpen() in main.dart.
// Used by ConsistencyRepository to build the line chart (X=day, Y=open count).

import 'package:drift/drift.dart';

import '../app_database.dart';

part 'activity_dao.g.dart';

@DriftAccessor(tables: [ActivityLog])
class ActivityDao extends DatabaseAccessor<AppDatabase>
    with _$ActivityDaoMixin {
  ActivityDao(super.db);

  // ── Streams ───────────────────────────────────────────────────────────────

  /// Streams a map of {dateOnly → openCount} for the past [days] days.
  /// Powers the line chart on the Consistency tab.
  Stream<Map<DateTime, int>> watchDailyOpenCounts({int days = 30}) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return (select(activityLog)
          ..where((a) => a.openedAt.isBiggerOrEqualValue(cutoff))
          ..orderBy([(a) => OrderingTerm.asc(a.openedAt)]))
        .watch()
        .map((entries) {
      final Map<DateTime, int> counts = {};
      for (final entry in entries) {
        final d = entry.openedAt;
        final key = DateTime(d.year, d.month, d.day);
        counts[key] = (counts[key] ?? 0) + 1;
      }
      return counts;
    });
  }

  // ── One-shot Reads ────────────────────────────────────────────────────────

  /// Returns all unique dates on which the app was opened.
  /// Merged with task/diary dates by ConsistencyRepository for streak calc.
  Future<List<DateTime>> getAppOpenDates() async {
    final result = await customSelect(
      '''
      SELECT DISTINCT DATE(opened_at / 1000, 'unixepoch') AS open_date
      FROM activity_log
      ORDER BY open_date ASC
      ''',
      readsFrom: {activityLog},
    ).get();

    return result.map((row) {
      return DateTime.parse(row.read<String>('open_date'));
    }).toList();
  }

  /// Returns the total number of app opens (all time).
  Future<int> getTotalOpenCount() async {
    final countExpr = activityLog.id.count();
    final query = selectOnly(activityLog)..addColumns([countExpr]);
    final row = await query.getSingle();
    return row.read(countExpr) ?? 0;
  }
}
