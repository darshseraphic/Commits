// lib/data/services/notification_service.dart
//
// ══════════════════════════════════════════════════════════════════════════════
// ASRIO Notification Service — Phase 1: Initialization
// ══════════════════════════════════════════════════════════════════════════════
//
// PHASE PLAN:
//   Phase 1 (now):    Initialize plugin, register Android channels.
//   Phase 3 (Settings): Add schedule(), cancel(), rescheduleAfterBoot().
//
// WHY register channels at startup?
//
// Android 8.0 (API 26) introduced notification channels. Every notification
// MUST belong to a channel. If a notification is fired before its channel is
// created, Android silently drops it — no error, no log, just silence.
//
// The RECEIVE_BOOT_COMPLETED receiver in AndroidManifest.xml means our
// notifications can fire immediately after a device reboot, before the user
// opens the app. Channels must therefore be registered before any of that
// can happen — the only safe moment is app startup.
//
// SINGLETON PATTERN:
// NotificationService is a singleton (private constructor + factory).
// This ensures flutter_local_notifications is initialized exactly once,
// no matter how many times NotificationService() is called.
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  // ── Singleton ─────────────────────────────────────────────────────────────
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  // ── Plugin Instance ───────────────────────────────────────────────────────
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ── Channel IDs ───────────────────────────────────────────────────────────
  //
  // Channel IDs are permanent — once created on a device, they persist even
  // if the app is updated. Never change these strings after v0.1.0 ships.
  // If you need different behavior, create a NEW channel with a new ID.
  static const String diaryChannelId   = 'asrio_diary_reminders';
  static const String diaryChannelName = 'Diary Reminders';

  static const String todoChannelId    = 'asrio_todo_reminders';
  static const String todoChannelName  = 'Task Reminders';

  // ── Initialization ────────────────────────────────────────────────────────

  /// Initializes the notification plugin and registers Android channels.
  ///
  /// Must be called in main.dart before runApp().
  /// Safe to call multiple times — subsequent calls are no-ops.
  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      // '@mipmap/ic_launcher' uses the app's launcher icon as the notification icon.
      // For a custom notification icon, add a drawable resource and reference it here.
      '@mipmap/ic_launcher',
    );

    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
      // onDidReceiveBackgroundNotificationResponse handles taps when the app
      // was terminated. Requires a top-level (not class) function. Added in Phase 3.
    );

    await _registerAndroidChannels();

    _initialized = true;
    debugPrint('[NotificationService] ✓ Initialized. Channels registered.');
  }

  // ── Android Channel Registration ─────────────────────────────────────────

  Future<void> _registerAndroidChannels() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) {
      // This branch runs on non-Android platforms. Safe to skip.
      return;
    }

    // ── Diary Channel ──────────────────────────────────────────────────────
    // Importance.defaultImportance: shows in the notification tray with sound.
    // Not Importance.high (which would use heads-up / banner) — diary reminders
    // are gentle nudges, not urgent alerts.
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        diaryChannelId,
        diaryChannelName,
        description:
            'Daily reminder to write in your diary. Scheduled in Settings.',
        importance: Importance.defaultImportance,
        playSound: true,
        enableVibration: true,
      ),
    );

    // ── To-Do Channel ──────────────────────────────────────────────────────
    // Importance.high: tasks are time-sensitive, so a banner notification
    // is appropriate here.
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        todoChannelId,
        todoChannelName,
        description: 'Reminder to complete your daily tasks.',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );
  }

  // ── Notification Tap Handler ──────────────────────────────────────────────

  /// Called when the user taps a notification while the app is in foreground
  /// or background (but not terminated).
  ///
  /// Phase 3: Use [response.payload] to navigate to the relevant screen.
  /// e.g., payload='diary' → context.go(AppRoutes.diary)
  ///
  /// GoRouter navigation requires a BuildContext, which we don't have here.
  /// Phase 3 will use a GlobalKey<NavigatorState> or Riverpod to bridge this.
  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint(
      '[NotificationService] Notification tapped. '
      'ID: ${response.id}, payload: ${response.payload}',
    );
    // Navigation logic added in Phase 3 (Settings & Notifications).
  }

  // ── Accessors ─────────────────────────────────────────────────────────────

  /// Exposes the raw plugin for use in Phase 3 scheduling methods.
  FlutterLocalNotificationsPlugin get plugin => _plugin;
}
