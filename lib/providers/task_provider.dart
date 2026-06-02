// lib/providers/task_provider.dart
//
// ══════════════════════════════════════════════════════════════════════════════
// Task Providers — AsyncNotifier + Stream Providers
// ══════════════════════════════════════════════════════════════════════════════
//
// ARCHITECTURE:
//   We expose TWO kinds of providers for tasks:
//
//   1. StreamProvider (watchDailyTasksProvider, watchYearlyTasksProvider):
//      These connect directly to the Drift stream from TaskRepository.
//      The UI uses these for the main task list — they auto-update whenever
//      the database changes. Zero manual refresh needed.
//
//   2. TaskNotifier (taskNotifierProvider):
//      An AsyncNotifier that handles WRITE operations (add, complete, delete).
//      It holds the state of the last write attempt: loading, success, or error.
//      The UI reads stream providers for display and calls taskNotifierProvider
//      methods for mutations.
//
// WHY SEPARATE READ AND WRITE PROVIDERS?
//   Mixing reads and writes in a single StateNotifier creates a subtle bug:
//   when a write triggers a DB change, the stream emits, which updates state,
//   which can interrupt the UI feedback for the write operation itself.
//   Separating them means: stream = live data, notifier = mutation feedback.
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/app_exceptions.dart';
import '../data/models/task_model.dart';
import 'repository_providers.dart';

// ── Stream Providers (Read) ───────────────────────────────────────────────────

/// Live stream of daily tasks from the database.
///
/// Usage in a widget:
///   final tasks = ref.watch(watchDailyTasksProvider);
///   tasks.when(data: ..., loading: ..., error: ...);
final watchDailyTasksProvider = StreamProvider<List<TaskModel>>(
  (ref) => ref.watch(taskRepositoryProvider).watchDailyTasks(),
  name: 'watchDailyTasksProvider',
);

/// Live stream of yearly goal tasks.
final watchYearlyTasksProvider = StreamProvider<List<TaskModel>>(
  (ref) => ref.watch(taskRepositoryProvider).watchYearlyTasks(),
  name: 'watchYearlyTasksProvider',
);

/// Live stream of ALL tasks (used by home screen summary card).
final watchAllTasksProvider = StreamProvider<List<TaskModel>>(
  (ref) => ref.watch(taskRepositoryProvider).watchAllTasks(),
  name: 'watchAllTasksProvider',
);

// ── Derived Providers ─────────────────────────────────────────────────────────

/// The count of tasks completed today. Derived from the live stream.
///
/// Widgets that only need the count (e.g. a badge) watch this provider
/// instead of the full list — they won't rebuild when task content changes,
/// only when the completed count changes. More efficient rendering.
final completedTodayCountProvider = Provider<int>(
  (ref) {
    final tasks = ref.watch(watchAllTasksProvider).valueOrNull ?? [];
    final today = DateTime.now();
    return tasks.where((t) {
      if (!t.isCompleted) return false;
      final c = t.createdAt;
      return c.year == today.year &&
          c.month == today.month &&
          c.day == today.day;
    }).length;
  },
  name: 'completedTodayCountProvider',
);

/// True if there are any overdue tasks.
final hasOverdueTasksProvider = Provider<bool>(
  (ref) {
    final tasks = ref.watch(watchAllTasksProvider).valueOrNull ?? [];
    return tasks.any((t) => t.isOverdue);
  },
  name: 'hasOverdueTasksProvider',
);

// ── Mutation Notifier (Write) ─────────────────────────────────────────────────

/// Holds the result state of the most recent task write operation.
///
/// State meaning:
///   AsyncData(null)      → idle, no write in progress.
///   AsyncLoading()       → a write operation is in progress.
///   AsyncData(TaskModel) → last write succeeded; value is the affected task.
///   AsyncError(e, st)    → last write failed; e is typed (DatabaseException etc.)
///
/// The UI reads this to show loading spinners, success toasts, and error messages.
/// It does NOT drive the task list display — that comes from the stream providers.
class TaskNotifier extends AsyncNotifier<TaskModel?> {
  @override
  Future<TaskModel?> build() async {
    // Initial state: idle.
    return null;
  }

  TaskRepository get _repo => ref.read(taskRepositoryProvider);

  // ── Add ────────────────────────────────────────────────────────────────────

  /// Creates a new task, optionally scheduling a notification.
  ///
  /// Sets state to AsyncLoading during the operation.
  /// Sets state to AsyncData(createdTask) on success.
  /// Sets state to AsyncError(ValidationException | DatabaseException) on failure.
  Future<void> addTask({
    required String title,
    String description = '',
    TaskType type = TaskType.daily,
    TaskPriority priority = TaskPriority.none,
    DateTime? dueDate,
    DateTime? reminderTime,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.addTask(
          title: title,
          description: description,
          type: type,
          priority: priority,
          dueDate: dueDate,
          reminderTime: reminderTime,
        ));
  }

  // ── Complete ───────────────────────────────────────────────────────────────

  /// Marks [task] as complete and cancels its notification.
  ///
  /// On success, state becomes AsyncData(completedTask).
  Future<void> completeTask(TaskModel task) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repo.completeTask(task);
      return task.copyWith(isCompleted: true, clearNotificationId: true);
    });
  }

  /// Undoes a task completion.
  Future<void> uncompleteTask(TaskModel task) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repo.uncompleteTask(task.id);
      return task.copyWith(isCompleted: false);
    });
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  /// Deletes [task] and cancels its notification.
  Future<void> deleteTask(TaskModel task) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repo.deleteTask(task);
      return null; // No task to return after deletion — idle state.
    });
  }

  // ── Update ─────────────────────────────────────────────────────────────────

  /// Updates a task's mutable fields.
  Future<void> updateTask(TaskModel task) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.updateTask(task));
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Resets the notifier to idle state.
  /// Call this after the UI has consumed an error or success state.
  void reset() => state = const AsyncData(null);

  /// True if the last operation threw a [ValidationException].
  bool get hasValidationError =>
      state.hasError && state.error is ValidationException;

  /// True if the last operation threw a [DatabaseException].
  bool get hasDatabaseError =>
      state.hasError && state.error is DatabaseException;

  /// The error message to show in the UI, or null if no error.
  String? get errorMessage =>
      state.hasError ? (state.error as AsrioException?)?.message : null;
}

final taskNotifierProvider =
    AsyncNotifierProvider<TaskNotifier, TaskModel?>(() => TaskNotifier());
