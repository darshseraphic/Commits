// lib/data/models/habit_model.dart
//
// ══════════════════════════════════════════════════════════════════════════════
// HabitModel & StreakModel — Domain Models
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';

/// A habit the user tracks on the Consistency tab.
@immutable
class HabitModel {
  const HabitModel({
    required this.id,
    required this.title,
    required this.description,
    required this.iconName,
    required this.category,
    required this.isArchived,
    required this.createdAt,
  });

  final int id;
  final String title;
  final String description;

  /// Icon identifier, e.g. 'book', 'run', 'water'.
  /// Mapped to a Flutter [IconData] in the widget layer via an icon registry.
  /// We store the name, not the codepoint, so the mapping can change without
  /// a database migration.
  final String iconName;

  final String category;
  final bool isArchived;
  final DateTime createdAt;

  HabitModel copyWith({
    int? id,
    String? title,
    String? description,
    String? iconName,
    String? category,
    bool? isArchived,
    DateTime? createdAt,
  }) {
    return HabitModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      iconName: iconName ?? this.iconName,
      category: category ?? this.category,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HabitModel && id == other.id && isArchived == other.isArchived;

  @override
  int get hashCode => Object.hash(id, isArchived);

  @override
  String toString() => 'HabitModel(id: $id, title: "$title")';
}

// ══════════════════════════════════════════════════════════════════════════════
// StreakModel
//
// The output of ConsistencyRepository's streak calculation.
// A pure value object — no methods, just data.
// ══════════════════════════════════════════════════════════════════════════════

/// The result of the streak calculation algorithm.
///
/// Produced by [ConsistencyRepository.calculateStreak].
/// Consumed by [ConsistencyProvider] and the Consistency tab widgets.
@immutable
class StreakModel {
  const StreakModel({
    required this.currentStreak,
    required this.longestStreak,
    required this.totalActiveDays,
    required this.activeDates,
    required this.calculatedAt,
  });

  /// Days in the current unbroken streak, using the 'loose' definition:
  /// streak breaks only if BOTH today and yesterday have no activity.
  /// A user who hasn't written yet today does not lose their streak.
  final int currentStreak;

  /// The longest streak ever recorded for this user.
  final int longestStreak;

  /// Total number of unique days with any activity (all time).
  final int totalActiveDays;

  /// The full set of active dates — used to shade the monthly calendar widget.
  /// Key: date-only DateTime. Value: always true (presence = active).
  final Set<DateTime> activeDates;

  /// When this streak was calculated. Used to decide if a cached value is stale.
  final DateTime calculatedAt;

  /// Zero-value sentinel for the loading state.
  static final StreakModel empty = StreakModel(
    currentStreak: 0,
    longestStreak: 0,
    totalActiveDays: 0,
    activeDates: {},
    calculatedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  bool get isEmpty => totalActiveDays == 0;

  /// Whether [date] (day precision) had any recorded activity.
  bool wasActiveOn(DateTime date) {
    return activeDates.contains(
      DateTime(date.year, date.month, date.day),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StreakModel &&
          currentStreak == other.currentStreak &&
          longestStreak == other.longestStreak &&
          totalActiveDays == other.totalActiveDays;

  @override
  int get hashCode =>
      Object.hash(currentStreak, longestStreak, totalActiveDays);

  @override
  String toString() =>
      'StreakModel(current: $currentStreak, longest: $longestStreak, '
      'totalDays: $totalActiveDays)';
}
