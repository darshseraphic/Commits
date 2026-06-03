// lib/providers/habit_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/app_exceptions.dart';
import '../data/models/habit_model.dart';
import 'repository_providers.dart';
import '../data/repositories/habit_repository.dart';

// ── Stream Provider (Read) ────────────────────────────────────────────────────

/// Live stream of active (non-archived) habits.
final watchActiveHabitsProvider = StreamProvider<List<HabitModel>>(
      (ref) => ref.watch(habitRepositoryProvider).watchActiveHabits(),
  name: 'watchActiveHabitsProvider',
);

/// Live stream of all habits including archived.
final watchAllHabitsProvider = StreamProvider<List<HabitModel>>(
      (ref) => ref.watch(habitRepositoryProvider).watchAllHabits(),
  name: 'watchAllHabitsProvider',
);

// ── Mutation Notifier (Write) ─────────────────────────────────────────────────

class HabitNotifier extends AsyncNotifier<HabitModel?> {
  @override
  Future<HabitModel?> build() async => null;

  HabitRepository get _repo => ref.read(habitRepositoryProvider);

  Future<void> addHabit({
    required String title,
    String description = '',
    String iconName = 'star',
    String category = 'general',
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.addHabit(
      title: title,
      description: description,
      iconName: iconName,
      category: category,
    ));
  }

  Future<void> updateHabit(HabitModel habit) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.updateHabit(habit));
  }

  Future<void> archiveHabit(int habitId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repo.archiveHabit(habitId);
      return null;
    });
  }

  Future<void> deleteHabit(int habitId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repo.deleteHabit(habitId);
      return null;
    });
  }

  void reset() => state = const AsyncData(null);

  String? get errorMessage =>
      state.hasError ? (state.error as AsrioException?)?.message : null;
}

final habitNotifierProvider =
AsyncNotifierProvider<HabitNotifier, HabitModel?>(() => HabitNotifier());