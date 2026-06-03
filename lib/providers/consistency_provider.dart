// lib/providers/consistency_provider.dart — Phase 5 (clean rewrite)

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/app_usage_model.dart';
import '../data/models/habit_model.dart';
import '../data/models/mood_model.dart';
import 'database_provider.dart';
import 'repository_providers.dart';

// ── Range Switcher ────────────────────────────────────────────────────────────

/// Selected day range for Consistency charts: 7 | 30 | 90 | 365
final selectedRangeProvider = StateProvider<int>(
  (ref) => 30,
  name: 'selectedRangeProvider',
);

// ── Streak ────────────────────────────────────────────────────────────────────

final streakProvider = FutureProvider<StreakModel>(
  (ref) => ref.watch(consistencyRepositoryProvider).calculateStreak(),
  name: 'streakProvider',
);

// ── Daily Open Counts ─────────────────────────────────────────────────────────

final dailyOpenCountsProvider = StreamProvider<Map<DateTime, int>>(
  (ref) {
    final days = ref.watch(selectedRangeProvider);
    return ref
        .watch(consistencyRepositoryProvider)
        .watchDailyOpenCounts(days: days);
  },
  name: 'dailyOpenCountsProvider',
);

// ── Diary Active Dates ────────────────────────────────────────────────────────

final diaryActiveDatesProvider = StreamProvider<Map<DateTime, bool>>(
  (ref) => ref
      .watch(consistencyRepositoryProvider)
      .watchActiveDiaryDates(days: 365),
  name: 'diaryActiveDatesProvider',
);

// ── App Usage Permission ──────────────────────────────────────────────────────

final appUsagePermissionProvider = FutureProvider<bool>(
  (ref) => ref.watch(appUsageServiceProvider).hasPermission(),
  name: 'appUsagePermissionProvider',
);

// ── App Usage Stats ───────────────────────────────────────────────────────────

final appUsageStatsProvider = FutureProvider<List<AppUsageModel>>(
  (ref) async {
    final hasPermission =
        await ref.watch(appUsagePermissionProvider.future);
    if (!hasPermission) return [];
    return ref.watch(appUsageServiceProvider).getTodayUsageStats();
  },
  name: 'appUsageStatsProvider',
);

// ── Mood History (for correlation chart) ─────────────────────────────────────

final moodHistoryForChartProvider = StreamProvider<List<MoodEntry>>(
  (ref) {
    final days = ref.watch(selectedRangeProvider);
    return ref
        .watch(databaseProvider)
        .moodDao
        .watchMoodHistory(days: days)
        .map((rows) => rows
            .map((r) => MoodEntry(
                  id: r.id,
                  position: r.moodValue,   // Drift column name
                  loggedAt: r.loggedAt,
                ))
            .toList());
  },
  name: 'moodHistoryForChartProvider',
);

// ── Combined State ────────────────────────────────────────────────────────────

final consistencyStateProvider = Provider<ConsistencyState>(
  (ref) => ConsistencyState(
    streak:             ref.watch(streakProvider),
    dailyOpenCounts:    ref.watch(dailyOpenCountsProvider),
    activeDiaryDates:   ref.watch(diaryActiveDatesProvider),
    appUsageStats:      ref.watch(appUsageStatsProvider),
    hasUsagePermission: ref.watch(appUsagePermissionProvider),
    moodHistory:        ref.watch(moodHistoryForChartProvider),
    selectedRange:      ref.watch(selectedRangeProvider),
  ),
  name: 'consistencyStateProvider',
);

// ── ConsistencyState value object ─────────────────────────────────────────────

class ConsistencyState {
  const ConsistencyState({
    required this.streak,
    required this.dailyOpenCounts,
    required this.activeDiaryDates,
    required this.appUsageStats,
    required this.hasUsagePermission,
    required this.moodHistory,
    required this.selectedRange,
  });

  final AsyncValue<StreakModel>           streak;
  final AsyncValue<Map<DateTime, int>>    dailyOpenCounts;
  final AsyncValue<Map<DateTime, bool>>   activeDiaryDates;
  final AsyncValue<List<AppUsageModel>>   appUsageStats;
  final AsyncValue<bool>                  hasUsagePermission;
  final AsyncValue<List<MoodEntry>>       moodHistory;
  final int                               selectedRange;

  bool get isLoading  => streak.isLoading || dailyOpenCounts.isLoading;
  bool get hasError   => streak.hasError   || dailyOpenCounts.hasError;

  int  get currentStreak   => streak.valueOrNull?.currentStreak   ?? 0;
  int  get longestStreak   => streak.valueOrNull?.longestStreak   ?? 0;
  int  get totalActiveDays => streak.valueOrNull?.totalActiveDays ?? 0;

  bool wasActiveOn(DateTime date) =>
      streak.valueOrNull?.wasActiveOn(date) ?? false;

  bool get canShowUsage =>
      hasUsagePermission.valueOrNull == true &&
      (appUsageStats.valueOrNull?.isNotEmpty ?? false);

  bool get needsUsagePermission =>
      hasUsagePermission.valueOrNull == false;
}
