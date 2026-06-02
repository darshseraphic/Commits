// lib/data/models/task_model.dart
//
// ══════════════════════════════════════════════════════════════════════════════
// TaskModel — Domain Model
// ══════════════════════════════════════════════════════════════════════════════
//
// This is a pure Dart class. It has zero knowledge of Drift, SQLite, or any
// storage mechanism. Widgets, providers, and repositories all speak this type.
//
// The Drift-generated 'Task' data class (in app_database.g.dart) is an
// implementation detail of the data layer. It never crosses the repository
// boundary. TaskRepository maps Task → TaskModel on every read.
//
// IMMUTABILITY: All fields are final. State changes create new instances
// via copyWith(). This makes Riverpod's change detection trivial — it compares
// object references, not field-by-field diffs.
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';

/// The type of task, controlling which section of the To-Do screen it appears in.
enum TaskType {
  /// A task to complete today. Shown in the 'Daily' section.
  daily,

  /// A long-term goal. Shown in the 'Yearly Goals' section.
  yearly,
}

/// The priority level of a task.
enum TaskPriority {
  none,
  low,
  medium,
  high,
}

/// Clean domain representation of a task.
///
/// Created by [TaskRepository] from the Drift-generated [Task] data class.
/// Consumed by [TaskNotifier], widgets, and [NotificationService].
@immutable
class TaskModel {
  const TaskModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.priority,
    required this.isCompleted,
    required this.createdAt,
    required this.sortOrder,
    this.dueDate,
    this.notificationId,
  });

  final int id;
  final String title;
  final String description;
  final TaskType type;
  final TaskPriority priority;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime? dueDate;
  final int sortOrder;

  /// The ID used by [NotificationService] to cancel this task's reminder.
  /// Null if no reminder has been scheduled for this task.
  final int? notificationId;

  // ── Derived Properties ───────────────────────────────────────────────────

  /// True if this task has an active (undelivered) notification scheduled.
  bool get hasReminder => notificationId != null;

  /// True if this task is overdue — has a due date that is in the past
  /// and has not been completed.
  bool get isOverdue {
    if (isCompleted || dueDate == null) return false;
    final now = DateTime.now();
    return dueDate!.isBefore(DateTime(now.year, now.month, now.day));
  }

  // ── Mutation ─────────────────────────────────────────────────────────────

  /// Returns a new [TaskModel] with the specified fields replaced.
  /// All other fields are copied from this instance unchanged.
  TaskModel copyWith({
    int? id,
    String? title,
    String? description,
    TaskType? type,
    TaskPriority? priority,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? dueDate,
    int? sortOrder,
    int? notificationId,
    bool clearNotificationId = false,
    bool clearDueDate = false,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      sortOrder: sortOrder ?? this.sortOrder,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      notificationId: clearNotificationId
          ? null
          : (notificationId ?? this.notificationId),
    );
  }

  // ── Serialization Helpers ─────────────────────────────────────────────────

  static TaskType typeFromString(String value) => switch (value) {
        'yearly' => TaskType.yearly,
        _        => TaskType.daily,
      };

  static String typeToString(TaskType type) => switch (type) {
        TaskType.yearly => 'yearly',
        TaskType.daily  => 'daily',
      };

  static TaskPriority priorityFromString(String value) => switch (value) {
        'low'    => TaskPriority.low,
        'medium' => TaskPriority.medium,
        'high'   => TaskPriority.high,
        _        => TaskPriority.none,
      };

  static String priorityToString(TaskPriority priority) => switch (priority) {
        TaskPriority.low    => 'low',
        TaskPriority.medium => 'medium',
        TaskPriority.high   => 'high',
        TaskPriority.none   => 'none',
      };

  // ── Equality ──────────────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          isCompleted == other.isCompleted &&
          notificationId == other.notificationId;

  @override
  int get hashCode => Object.hash(id, title, isCompleted, notificationId);

  @override
  String toString() =>
      'TaskModel(id: $id, title: "$title", type: $type, '
      'completed: $isCompleted, reminder: $notificationId)';
}
