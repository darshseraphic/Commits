// lib/data/models/app_usage_model.dart
//
// ══════════════════════════════════════════════════════════════════════════════
// AppUsageModel — Domain Model
// ══════════════════════════════════════════════════════════════════════════════
//
// Represents one app's usage entry after processing from UsageStatsManager.
// appName is resolved by PackageManager on the Kotlin side — no hardcoded list.
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';

@immutable
class AppUsageModel {
  const AppUsageModel({
    required this.packageName,
    required this.appName,
    required this.durationMs,
    required this.percentage,
  });

  /// Raw Android package name e.g. "com.instagram.android"
  final String packageName;

  /// Human-readable name resolved by PackageManager e.g. "Instagram"
  final String appName;

  /// Foreground time in milliseconds.
  final int durationMs;

  /// Fraction of total screen time (0.0 → 1.0).
  final double percentage;

  // ── Derived ───────────────────────────────────────────────────────────────

  int get durationMinutes => (durationMs / 60000).round();

  /// Formatted duration string: "1h 23m" or "45m" or "< 1m"
  String get formattedDuration {
    final totalMin = durationMinutes;
    if (totalMin == 0) return '< 1m';
    final hours = totalMin ~/ 60;
    final mins  = totalMin % 60;
    if (hours == 0) return '${mins}m';
    if (mins  == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }

  /// Formatted percentage string: "23%"
  String get formattedPercentage => '${(percentage * 100).round()}%';

  // ── Factory ───────────────────────────────────────────────────────────────

  /// Creates the "Other" bucket from a list of minor apps.
  factory AppUsageModel.other(List<AppUsageModel> minorApps, int totalMs) {
    final sumMs = minorApps.fold<int>(0, (acc, a) => acc + a.durationMs);
    return AppUsageModel(
      packageName: '__other__',
      appName: 'Other',
      durationMs: sumMs,
      percentage: totalMs == 0 ? 0 : sumMs / totalMs,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUsageModel && packageName == other.packageName;

  @override
  int get hashCode => packageName.hashCode;

  @override
  String toString() =>
      'AppUsageModel($appName: $formattedDuration, ${formattedPercentage})';
}
