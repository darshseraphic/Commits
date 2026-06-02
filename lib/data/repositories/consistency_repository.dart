// lib/data/repositories/consistency_repository.dart
//
// ══════════════════════════════════════════════════════════════════════════════
// ConsistencyRepository — Streak Calculator
// ══════════════════════════════════════════════════════════════════════════════
//
// HYBRID APPROACH (as per the Phase 2 architecture plan):
//   SQL:  aggregates raw active dates from tasks + diary tables.
//   Dart: runs the sequential streak logic on the aggregated date list.
//
// STREAK DEFINITION (Loose — approved in architecture review):
//   A streak breaks only if BOTH today AND yesterday have no activity.
//   A user who hasn't written today does not lose their streak until
//   the day is fully over and they still haven't done anything.
//
//   Example:
//     Active dates: [Mon, Tue, Wed]
//     Current day:  Thu (no activity yet)
//     Current streak: 3 ✓ (not 0 — the day isn't over yet)
//
//     If Thu passes with no activity:
//     Current day: Fri (no activity)
//     Current streak: 0 ✗ (both Thu and Fri have no activity → break)
// ══════════════════════════════════════════════════════════════════════════════

import '../database/daos/activity_dao.dart';
import '../database/daos/diary_dao.dart';
import '../database/daos/tasks_dao.dart';
import '../models/habit_model.dart';

class ConsistencyRepository {
  const ConsistencyRepository({
    required TasksDao tasksDao,
    required DiaryDao diaryDao,
    required ActivityDao activityDao,
  })  : _tasksDao = tasksDao,
        _diaryDao = diaryDao,
        _activityDao = activityDao;

  final TasksDao _tasksDao;
  final DiaryDao _diaryDao;
  final ActivityDao _activityDao;

  // ── Main Calculation ──────────────────────────────────────────────────────

  /// Computes the full [StreakModel] by merging all activity sources.
  ///
  /// Sources merged:
  ///   1. Dates with at least one completed task (tasks table).
  ///   2. Dates with at least one diary page written (diary_pages table).
  ///
  /// App-open dates (activity_log) are intentionally NOT included in the streak.
  /// Simply opening the app shouldn't count as "being consistent" —
  /// only meaningful actions (writing or completing tasks) do.
  Future<StreakModel> calculateStreak() async {
    // ── Step 1: SQL — gather raw active dates from both sources ──────────────
    final taskDates  = await _tasksDao.getActiveDatesByCompletedTasks();
    final diaryDates = await _diaryDao.getActiveDiaryDates();

    // ── Step 2: Dart — merge, deduplicate, sort ──────────────────────────────
    final allDates = <DateTime>{};

    // Normalize to date-only (midnight) before merging to ensure deduplication
    // works even if two dates have different time components.
    for (final d in taskDates) {
      allDates.add(DateTime(d.year, d.month, d.day));
    }
    for (final d in diaryDates) {
      allDates.add(DateTime(d.year, d.month, d.day));
    }

    final sortedDates = allDates.toList()..sort();

    // ── Step 3: Dart — streak calculation ───────────────────────────────────
    final currentStreak = _calculateCurrentStreak(sortedDates);
    final longestStreak = _calculateLongestStreak(sortedDates);

    return StreakModel(
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      totalActiveDays: sortedDates.length,
      activeDates: allDates,
      calculatedAt: DateTime.now(),
    );
  }

  /// Returns the daily open counts for the line chart (past [days] days).
  Stream<Map<DateTime, int>> watchDailyOpenCounts({int days = 30}) =>
      _activityDao.watchDailyOpenCounts(days: days);

  /// Returns the active diary dates map for calendar shading.
  Stream<Map<DateTime, bool>> watchActiveDiaryDates({int days = 365}) =>
      _diaryDao.watchActiveDiaryDates(days: days);

  // ── Streak Algorithms ─────────────────────────────────────────────────────

  /// Calculates the current streak using the LOOSE definition:
  ///
  /// Walk backwards from today. A gap of exactly one day (yesterday was
  /// inactive) only breaks the streak if TODAY is also inactive.
  ///
  /// This means: if the user was active Mon-Wed and today is Thu (no activity),
  /// the streak is still 3. It only breaks on Fri if Thu was also empty.
  int _calculateCurrentStreak(List<DateTime> sortedDates) {
    if (sortedDates.isEmpty) return 0;

    final today = _dateOnly(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));

    // If the most recent active day is neither today nor yesterday,
    // the streak is definitively broken regardless of the loose rule.
    final mostRecent = sortedDates.last;
    if (mostRecent.isBefore(yesterday)) return 0;

    // Walk backwards from the most recent active day, counting consecutive days.
    int streak = 0;
    DateTime expected = mostRecent;

    for (int i = sortedDates.length - 1; i >= 0; i--) {
      final date = sortedDates[i];

      if (date == expected) {
        streak++;
        expected = expected.subtract(const Duration(days: 1));
      } else {
        // Gap found — streak chain is broken.
        break;
      }
    }

    return streak;
  }

  /// Calculates the longest streak in the entire history.
  ///
  /// Uses a simple linear scan: increment a counter for each consecutive day,
  /// reset when a gap is found, track the maximum seen.
  int _calculateLongestStreak(List<DateTime> sortedDates) {
    if (sortedDates.isEmpty) return 0;

    int longest = 1;
    int current = 1;

    for (int i = 1; i < sortedDates.length; i++) {
      final prev = sortedDates[i - 1];
      final curr = sortedDates[i];
      final diff = curr.difference(prev).inDays;

      if (diff == 1) {
        current++;
        if (current > longest) longest = current;
      } else {
        current = 1;
      }
    }

    return longest;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}
