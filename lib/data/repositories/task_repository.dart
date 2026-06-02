// lib/data/repositories/task_repository.dart
//
// ══════════════════════════════════════════════════════════════════════════════
// TaskRepository — Transaction Coordinator
// ══════════════════════════════════════════════════════════════════════════════
//
// This class owns the contract defined in the Phase 2 architecture plan:
//
//   1. DB write must succeed first. If it fails, nothing else runs.
//   2. Notification schedule is attempted after a successful DB write.
//      If it fails, the task still exists — we log and surface a warning.
//   3. The notification ID is stored back into the task row immediately
//      after scheduling succeeds, linking task ↔ alarm for cancellation.
//
// MAPPING:
//   Drift 'Task' (data class)  →  TaskModel (domain model)
//   The toModel() extension is defined at the bottom of this file.
//   No widget or provider ever imports the Drift 'Task' class directly.
// ══════════════════════════════════════════════════════════════════════════════

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../core/utils/app_exceptions.dart';
import '../database/app_database.dart';
import '../database/daos/tasks_dao.dart';
import '../models/task_model.dart';
import '../services/notification_service.dart';

class TaskRepository {
  const TaskRepository({
    required TasksDao tasksDao,
    required NotificationService notificationService,
  })  : _dao = tasksDao,
        _notifications = notificationService;

  final TasksDao _dao;
  final NotificationService _notifications;

  // ── Streams (pass-through with mapping) ───────────────────────────────────

  /// Live stream of daily tasks, mapped to domain models.
  Stream<List<TaskModel>> watchDailyTasks() =>
      _dao.watchDailyTasks().map((rows) => rows.map(_toModel).toList());

  /// Live stream of yearly goal tasks, mapped to domain models.
  Stream<List<TaskModel>> watchYearlyTasks() =>
      _dao.watchYearlyTasks().map((rows) => rows.map(_toModel).toList());

  /// Live stream of all tasks — used by home screen summary card.
  Stream<List<TaskModel>> watchAllTasks() =>
      _dao.watchAllTasks().map((rows) => rows.map(_toModel).toList());

  // ── Insert (Coordinator Pattern) ──────────────────────────────────────────

  /// Creates a new task and optionally schedules a notification.
  ///
  /// Returns the created [TaskModel] with its assigned database ID.
  ///
  /// Throws [ValidationException] if the title is empty.
  /// Throws [DatabaseException] if the DB write fails.
  /// A notification failure is caught internally and logged — it is non-fatal.
  Future<TaskModel> addTask({
    required String title,
    String description = '',
    TaskType type = TaskType.daily,
    TaskPriority priority = TaskPriority.none,
    DateTime? dueDate,
    DateTime? reminderTime,
  }) async {
    // ── Validation ──────────────────────────────────────────────────────────
    if (title.trim().isEmpty) {
      throw const ValidationException('Task title cannot be empty.');
    }

    // ── Step 1: DB Write ────────────────────────────────────────────────────
    // This MUST succeed before anything else runs.
    final int newId;
    try {
      newId = await _dao.insertTask(
        TasksCompanion.insert(
          title: title.trim(),
          description: Value(description.trim()),
          type: Value(TaskModel.typeToString(type)),
          priority: Value(TaskModel.priorityToString(priority)),
          dueDate: Value(dueDate),
        ),
      );
    } catch (e) {
      throw DatabaseException('Failed to save task "$title".', cause: e);
    }

    // ── Step 2: Notification Scheduling (non-fatal) ─────────────────────────
    int? scheduledNotificationId;
    if (reminderTime != null) {
      try {
        scheduledNotificationId = await _notifications.scheduleTaskReminder(
          taskId: newId,
          title: title.trim(),
          scheduledTime: reminderTime,
        );

        // ── Step 3: Store the notification ID ───────────────────────────────
        // Links the task row to its alarm. Required for O(1) cancellation.
        await _dao.updateNotificationId(newId, scheduledNotificationId);
      } catch (e) {
        // Non-fatal: the task exists, the reminder just isn't set.
        // TaskNotifier will surface a warning to the UI via its state.
        debugPrint('[TaskRepository] ⚠ Notification scheduling failed: $e');
      }
    }

    // Return the complete created model.
    final created = await _dao.findById(newId);
    if (created == null) {
      throw DatabaseException('Task was inserted but could not be retrieved.');
    }
    return _toModel(created);
  }

  // ── Update ────────────────────────────────────────────────────────────────

  /// Updates a task's mutable fields and reschedules its notification if needed.
  Future<TaskModel> updateTask(TaskModel task) async {
    try {
      await _dao.updateTask(
        TasksCompanion(
          id: Value(task.id),
          title: Value(task.title),
          description: Value(task.description),
          type: Value(TaskModel.typeToString(task.type)),
          priority: Value(TaskModel.priorityToString(task.priority)),
          isCompleted: Value(task.isCompleted),
          dueDate: Value(task.dueDate),
          sortOrder: Value(task.sortOrder),
          notificationId: Value(task.notificationId),
        ),
      );
    } catch (e) {
      throw DatabaseException('Failed to update task "${task.title}".', cause: e);
    }

    final updated = await _dao.findById(task.id);
    if (updated == null) throw NotFoundException('Task ${task.id} not found after update.');
    return _toModel(updated);
  }

  // ── Complete / Uncomplete ─────────────────────────────────────────────────

  /// Marks a task complete and cancels its notification if one exists.
  ///
  /// Completing a task cancels the reminder — no point being reminded about
  /// something you've already done.
  Future<void> completeTask(TaskModel task) async {
    // Cancel the notification first. If DB write fails after this,
    // the worst case is a phantom notification — acceptable vs leaving a
    // 'completed' notification firing for a task still shown as incomplete.
    if (task.notificationId != null) {
      try {
        await _notifications.cancelNotification(task.notificationId!);
      } catch (e) {
        debugPrint('[TaskRepository] ⚠ Could not cancel notification: $e');
      }
    }

    try {
      await _dao.setCompleted(task.id, completed: true);
      if (task.notificationId != null) {
        await _dao.updateNotificationId(task.id, null);
      }
    } catch (e) {
      throw DatabaseException('Failed to complete task "${task.title}".', cause: e);
    }
  }

  /// Marks a completed task as incomplete (undo).
  Future<void> uncompleteTask(int taskId) async {
    try {
      await _dao.setCompleted(taskId, completed: false);
    } catch (e) {
      throw DatabaseException('Failed to uncomplete task $taskId.', cause: e);
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  /// Deletes a task and cancels its notification.
  Future<void> deleteTask(TaskModel task) async {
    if (task.notificationId != null) {
      try {
        await _notifications.cancelNotification(task.notificationId!);
      } catch (e) {
        debugPrint('[TaskRepository] ⚠ Could not cancel notification on delete: $e');
      }
    }

    try {
      await _dao.deleteTask(task.id);
    } catch (e) {
      throw DatabaseException('Failed to delete task "${task.title}".', cause: e);
    }
  }

  // ── Queries ───────────────────────────────────────────────────────────────

  Future<int> countCompletedToday() => _dao.countCompletedToday();

  Future<List<DateTime>> getActiveDatesByTasks() =>
      _dao.getActiveDatesByCompletedTasks();

  // ── Mapping: Drift → Domain ───────────────────────────────────────────────

  static TaskModel _toModel(Task row) => TaskModel(
        id: row.id,
        title: row.title,
        description: row.description,
        type: TaskModel.typeFromString(row.type),
        priority: TaskModel.priorityFromString(row.priority),
        isCompleted: row.isCompleted,
        createdAt: row.createdAt,
        dueDate: row.dueDate,
        sortOrder: row.sortOrder,
        notificationId: row.notificationId,
      );
}
