// lib/data/services/app_usage_service.dart
//
// ══════════════════════════════════════════════════════════════════════════════
// AppUsageService — Platform Channel Bridge
// ══════════════════════════════════════════════════════════════════════════════
//
// Dart side of the MethodChannel to UsageStatsPlugin.kt.
// Handles permission check, Settings redirect, and data processing.
//
// SYSTEM APP FILTER:
//   Blocklist approach — blocks known background processes.
//   Camera, Gallery, Clock, Calculator, Maps, Gmail, etc. all pass through.
//   See _isSystemNoise() for the exact filter logic.
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/app_usage_model.dart';

class AppUsageService {
  AppUsageService._internal();
  static final AppUsageService _instance = AppUsageService._internal();
  factory AppUsageService() => _instance;

  static const _channel =
      MethodChannel('com.darshvici.asrio/usage_stats');

  // ── Permission ────────────────────────────────────────────────────────────

  /// Returns true if PACKAGE_USAGE_STATS permission is granted.
  Future<bool> hasPermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasUsagePermission') ?? false;
    } catch (e) {
      debugPrint('[AppUsageService] hasPermission error: $e');
      return false;
    }
  }

  /// Opens the system Usage Access settings page.
  /// The user must manually grant permission there.
  Future<void> openPermissionSettings() async {
    try {
      await _channel.invokeMethod('openUsageAccessSettings');
    } catch (e) {
      debugPrint('[AppUsageService] openPermissionSettings error: $e');
    }
  }

  // ── Data Fetching ─────────────────────────────────────────────────────────

  /// Returns today's app usage, filtered and processed.
  ///
  /// Returns an empty list if permission is not granted.
  /// Never throws — all errors are logged and swallowed.
  Future<List<AppUsageModel>> getTodayUsageStats() async {
    return _getUsageStats(
      start: _todayStart(),
      end: DateTime.now(),
    );
  }

  /// Returns usage stats for the past [days] days.
  Future<List<AppUsageModel>> getUsageStatsForDays(int days) async {
    return _getUsageStats(
      start: DateTime.now().subtract(Duration(days: days)),
      end: DateTime.now(),
    );
  }

  Future<List<AppUsageModel>> _getUsageStats({
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final raw = await _channel.invokeMethod<List>(
        'getUsageStats',
        {
          'startTime': start.millisecondsSinceEpoch,
          'endTime':   end.millisecondsSinceEpoch,
        },
      );

      if (raw == null || raw.isEmpty) return [];

      // Parse raw list from Kotlin: List<Map<String, dynamic>>
      final entries = raw.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return _RawUsage(
          packageName: map['packageName'] as String,
          appName:     map['appName']     as String,
          usageMs:     (map['usageMs']    as num).toInt(),
        );
      }).toList();

      return _process(entries);
    } on PlatformException catch (e) {
      debugPrint('[AppUsageService] PlatformException: ${e.code} ${e.message}');
      return [];
    } catch (e) {
      debugPrint('[AppUsageService] Unexpected error: $e');
      return [];
    }
  }

  // ── Processing ────────────────────────────────────────────────────────────

  /// Filters noise, calculates percentages, sorts by duration, buckets "Other".
  List<AppUsageModel> _process(List<_RawUsage> raw) {
    // 1. Filter system noise and very short sessions (<60s = 60,000ms).
    final meaningful = raw
        .where((e) => !_isSystemNoise(e.packageName) && e.usageMs >= 60000)
        .toList();

    if (meaningful.isEmpty) return [];

    // 2. Calculate total screen time (denominator for percentages).
    final totalMs = meaningful.fold<int>(0, (acc, e) => acc + e.usageMs);
    if (totalMs == 0) return [];

    // 3. Map to domain models with percentages.
    final models = meaningful.map((e) => AppUsageModel(
          packageName: e.packageName,
          appName:     e.appName,
          durationMs:  e.usageMs,
          percentage:  e.usageMs / totalMs,
        )).toList();

    // 4. Sort by duration descending.
    models.sort((a, b) => b.durationMs.compareTo(a.durationMs));

    // 5. Take top 5, bucket the rest into "Other".
    if (models.length <= 5) return models;

    final top5   = models.sublist(0, 5);
    final others = models.sublist(5);
    final otherBucket = AppUsageModel.other(others, totalMs);

    return [...top5, otherBucket];
  }

  // ── System Noise Filter ───────────────────────────────────────────────────
  //
  // Blocklist approach: block known background processes, allow everything else.
  // Camera, Gallery, Clock, Calculator, Phone UI, Messages all pass through.

  static const _blockedPackages = {
    'android',
    'com.android.systemui',
    'com.google.android.gms',
    'com.google.android.gsf',
    'com.google.android.packageinstaller',
    'com.google.android.permissioncontroller',
    'com.android.packageinstaller',
    'com.android.server.telecom',
    'com.android.phone',
    'com.android.providers.media',
    'com.android.providers.contacts',
  };

  static const _blockedSubstrings = [
    '.launcher',
    '.inputmethod',
    '.wallpaper',
    'com.android.systemui',
    'com.google.android.gms',
    '.systemservice',
    '.daemon',
  ];

  static bool _isSystemNoise(String pkg) {
    if (_blockedPackages.contains(pkg)) return true;
    for (final sub in _blockedSubstrings) {
      if (pkg.contains(sub)) return true;
    }
    return false;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static DateTime _todayStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}

class _RawUsage {
  const _RawUsage({
    required this.packageName,
    required this.appName,
    required this.usageMs,
  });
  final String packageName;
  final String appName;
  final int usageMs;
}
