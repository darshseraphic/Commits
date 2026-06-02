// lib/providers/mood_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/mood_model.dart';
import 'repository_providers.dart';

// ── Stream Providers ──────────────────────────────────────────────────────────

/// Streams today's mood entry. Null if not yet logged today.
final todayMoodProvider = StreamProvider<MoodEntry?>(
  (ref) => ref.watch(moodRepositoryProvider).watchTodayMood(),
  name: 'todayMoodProvider',
);

/// Streams mood history for the Consistency correlation chart.
final moodHistoryProvider =
    StreamProvider.family<List<MoodEntry>, int>(
  (ref, days) =>
      ref.watch(moodRepositoryProvider).watchMoodHistory(days: days),
  name: 'moodHistoryProvider',
);

// ── Mutation Notifier ─────────────────────────────────────────────────────────

class MoodNotifier extends AsyncNotifier<MoodEntry?> {
  @override
  Future<MoodEntry?> build() async => null;

  Future<void> logMood(int position) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(moodRepositoryProvider).logMood(position);
      return null; // Stream provider picks up the new value.
    });
  }
}

final moodNotifierProvider =
    AsyncNotifierProvider<MoodNotifier, MoodEntry?>(() => MoodNotifier());
