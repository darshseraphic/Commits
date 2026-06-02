// lib/data/models/mood_model.dart
//
// ══════════════════════════════════════════════════════════════════════════════
// MoodModel — Domain Model
// ══════════════════════════════════════════════════════════════════════════════
//
// Mood is stored as a position integer (1–5, leftmost to rightmost).
// The label (Happy/Fun/Normal/Off/Sad) and color are resolved at render time
// based on the active theme. This means old entries re-label correctly if the
// user switches themes — no data migration ever needed.
//
// COLOR CONTRACT:
//   Position 1 = #000000 in light (Happy), #ffffff in dark (Happy)
//   Position 3 = #7f7f7f always (Normal — theme-invariant anchor)
//   Position 5 = #ffffff in light (Sad),   #000000 in dark (Sad)
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

/// A single mood log entry.
class MoodEntry {
  const MoodEntry({
    required this.id,
    required this.position,  // 1–5
    required this.loggedAt,
  });

  final int id;

  /// Circle position: 1 (leftmost) → 5 (rightmost).
  /// Meaning flips per theme — see [MoodPalette].
  final int position;

  final DateTime loggedAt;

  bool get isToday {
    final now = DateTime.now();
    return loggedAt.year == now.year &&
        loggedAt.month == now.month &&
        loggedAt.day == now.day;
  }

  MoodEntry copyWith({int? id, int? position, DateTime? loggedAt}) =>
      MoodEntry(
        id: id ?? this.id,
        position: position ?? this.position,
        loggedAt: loggedAt ?? this.loggedAt,
      );
}

/// Resolves mood color and label from a position (1–5) and theme brightness.
///
/// Light theme: dark = positive (black = happy)
/// Dark theme:  light = positive (white = happy)
abstract final class MoodPalette {
  // The five greyscale values — fixed regardless of theme.
  static const _colors = [
    Color(0xFF000000), // Position 1
    Color(0xFF404040), // Position 2
    Color(0xFF7F7F7F), // Position 3  ← always Normal
    Color(0xFFBFBFBF), // Position 4
    Color(0xFFFFFFFF), // Position 5
  ];

  static const _labelsLight = ['Happy', 'Fun', 'Normal', 'Off', 'Sad'];
  static const _labelsDark  = ['Sad',   'Off', 'Normal', 'Fun', 'Happy'];

  /// Returns the fill color for circle at [position] (1-based).
  static Color colorAt(int position) => _colors[position - 1];

  /// Returns the mood label for [position] given [brightness].
  static String labelAt(int position, Brightness brightness) {
    final labels = brightness == Brightness.light
        ? _labelsLight
        : _labelsDark;
    return labels[position - 1];
  }

  /// Returns all 5 colors in order (position 1→5).
  static List<Color> get allColors => List.unmodifiable(_colors);

  /// The border color for a circle — inverse of its fill.
  static Color borderFor(Color fill) {
    final luminance = fill.computeLuminance();
    return luminance > 0.5 ? const Color(0xFFE0E0E0) : Colors.transparent;
  }

  /// The ring color shown around a selected circle.
  static Color ringFor(Color fill) {
    final luminance = fill.computeLuminance();
    return luminance > 0.5 ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
  }
}
