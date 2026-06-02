// lib/data/services/notification_scheduler.dart
//
// ══════════════════════════════════════════════════════════════════════════════
// NotificationScheduler — zonedSchedule wrapper
// ══════════════════════════════════════════════════════════════════════════════
//
// flutter_local_notifications v17+ requires zonedSchedule() instead of
// the deprecated schedule(). zonedSchedule() uses the tz package for
// timezone-aware scheduling.
//
// INITIALIZATION:
//   tz.initializeTimeZones() must be called in main.dart before runApp().
//   This is a one-time in-memory operation (~5ms).
//
// REPEAT LOGIC:
//   DateTimeComponents.time → fires at the same HH:mm every day.
//   No manual rescheduling needed after each delivery.
//
// BOOT RESCHEDULING:
//   rescheduleAfterBoot() is called when RECEIVE_BOOT_COMPLETED fires.
//   It reads saved preferences and recreates all scheduled notifications.
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'notification_service.dart';

class NotificationScheduler {
  NotificationScheduler._internal();
  static final NotificationScheduler _instance =
      NotificationScheduler._internal();
  factory NotificationScheduler() => _instance;

  bool _tzInitialized = false;

  // ── Timezone Init ─────────────────────────────────────────────────────────

  /// Must be called once in main.dart before runApp().
  /// Loads the timezone database into memory.
  void initializeTimezones() {
    if (_tzInitialized) return;
    tz.initializeTimeZones();
    _tzInitialized = true;
    debugPrint('[NotificationScheduler] ✓ Timezones initialized.');
  }

  /// Returns the device's local timezone location.
  /// Falls back to UTC if detection fails.
  tz.Location get _localLocation {
    try {
      return tz.local;
    } catch (_) {
      return tz.UTC;
    }
  }

  // ── Next Occurrence Calculator ────────────────────────────────────────────

  /// Returns the next TZDateTime for [time] — today if the time hasn't
  /// passed yet, tomorrow if it has.
  tz.TZDateTime _nextInstanceOf(TimeOfDay time) {
    final now = tz.TZDateTime.now(_localLocation);
    var scheduled = tz.TZDateTime(
      _localLocation,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // If the time has already passed today, schedule for tomorrow.
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }

  // ── Diary Reminder ────────────────────────────────────────────────────────

  static const int _diaryNotificationId = 9000;

  /// Schedules a daily diary reminder at [time].
  /// Replaces any existing diary reminder.
  Future<void> scheduleDailyDiaryReminder(TimeOfDay time) async {
    final plugin = NotificationService().plugin;

    await plugin.cancel(_diaryNotificationId);

    const androidDetails = AndroidNotificationDetails(
      NotificationService.diaryChannelId,
      NotificationService.diaryChannelName,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    final scheduledDate = _nextInstanceOf(time);

    await plugin.zonedSchedule(
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      _diaryNotificationId,
      'Time to write ✍️',
      "Your diary is waiting for today's thoughts.",
      scheduledDate,
      const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      // Repeat at the same time every day — no manual rescheduling needed.
      matchDateTimeComponents: DateTimeComponents.time,
    );

    debugPrint(
      '[NotificationScheduler] Diary reminder scheduled at '
      '${time.hour}:${time.minute.toString().padLeft(2, '0')} daily.',
    );
  }

  /// Cancels the daily diary reminder.
  Future<void> cancelDiaryReminder() async {
    await NotificationService().plugin.cancel(_diaryNotificationId);
    debugPrint('[NotificationScheduler] Diary reminder cancelled.');
  }

  // ── Task Reminder ─────────────────────────────────────────────────────────

  /// Schedules a one-time task reminder at [scheduledTime].
  /// Returns the notification ID for later cancellation.
  Future<int> scheduleTaskReminder({
    required int taskId,
    required String title,
    required DateTime scheduledTime,
  }) async {
    final plugin = NotificationService().plugin;

    const androidDetails = AndroidNotificationDetails(
      NotificationService.todoChannelId,
      NotificationService.todoChannelName,
      importance: Importance.high,
      priority: Priority.high,
    );

    final scheduledTz = tz.TZDateTime.from(scheduledTime, _localLocation);

    await plugin.zonedSchedule(
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      taskId,
      'Task Reminder',
      title,
      scheduledTz,
      const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );

    debugPrint(
      '[NotificationScheduler] Task #$taskId reminder scheduled '
      'for ${scheduledTime.toIso8601String()}.',
    );

    return taskId;
  }

  // ── Boot Rescheduling ─────────────────────────────────────────────────────

  /// Called when RECEIVE_BOOT_COMPLETED fires.
  /// Reads saved notification preferences and recreates all alarms.
  ///
  /// Android clears all scheduled notifications on reboot.
  /// This restores them so reminders survive device restarts.
  Future<void> rescheduleAfterBoot() async {
    final prefs = await SharedPreferences.getInstance();

    final diaryEnabled = prefs.getBool('asrio_diary_reminder_enabled') ?? false;
    if (diaryEnabled) {
      final hour   = prefs.getInt('asrio_diary_reminder_hour')   ?? 21;
      final minute = prefs.getInt('asrio_diary_reminder_minute') ?? 0;
      await scheduleDailyDiaryReminder(TimeOfDay(hour: hour, minute: minute));
    }

    debugPrint('[NotificationScheduler] Boot rescheduling complete.');
  }
}
