// lib/features/settings/widgets/notification_bottom_sheet.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/asrio_colors.dart';
import '../../../core/theme/asrio_text_styles.dart';
import '../../../data/services/notification_scheduler.dart';
import '../../../providers/settings_provider.dart';

/// Shows the notification settings bottom sheet.
void showNotificationSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _NotificationSheet(),
  );
}

class _NotificationSheet extends ConsumerStatefulWidget {
  const _NotificationSheet();

  @override
  ConsumerState<_NotificationSheet> createState() =>
      _NotificationSheetState();
}

class _NotificationSheetState extends ConsumerState<_NotificationSheet> {
  // Local copies so changes don't fire until "Save" is tapped.
  late bool   _diaryEnabled;
  late int    _diaryHour;
  late int    _diaryMinute;
  late bool   _taskEnabled;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _diaryEnabled = ref.read(diaryReminderEnabledProvider);
    _diaryHour    = ref.read(diaryReminderHourProvider);
    _diaryMinute  = ref.read(diaryReminderMinuteProvider);
    _taskEnabled  = ref.read(taskReminderEnabledProvider);
  }

  String get _formattedTime {
    final h  = _diaryHour;
    final m  = _diaryMinute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$h12:$m $period';
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();

    // Persist to SharedPreferences via notifiers.
    await ref.read(diaryReminderEnabledProvider.notifier).set(_diaryEnabled);
    await ref.read(diaryReminderHourProvider.notifier).set(_diaryHour);
    await ref.read(diaryReminderMinuteProvider.notifier).set(_diaryMinute);
    await ref.read(taskReminderEnabledProvider.notifier).set(_taskEnabled);

    // Schedule or cancel diary reminder.
    final scheduler = NotificationScheduler();
    if (_diaryEnabled) {
      await scheduler.scheduleDailyDiaryReminder(
        TimeOfDay(hour: _diaryHour, minute: _diaryMinute),
      );
    } else {
      await scheduler.cancelDiaryReminder();
    }

    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context);
    }
  }

  void _showTimePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _TimePickerSheet(
        initialHour:   _diaryHour,
        initialMinute: _diaryMinute,
        onConfirm: (h, m) => setState(() {
          _diaryHour   = h;
          _diaryMinute = m;
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AsrioColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36, height: 3,
              decoration: BoxDecoration(
                color: AsrioColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),

          const Text('Notifications', style: AsrioText.cardTitle),
          const SizedBox(height: 24),

          // ── Diary Reminder ────────────────────────────────────────
          const _SectionLabel(label: 'DIARY REMINDER'),
          const SizedBox(height: 10),

          // Diary toggle row
          _ToggleRow(
            icon: Icons.auto_stories_outlined,
            title: 'Daily reminder',
            subtitle: 'Remind me to write each day',
            value: _diaryEnabled,
            onChanged: (v) => setState(() => _diaryEnabled = v),
          ),

          // Time picker row (only visible when enabled)
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOutCubic,
            child: _diaryEnabled
                ? Column(
                    children: [
                      const SizedBox(height: 10),
                      _TimeRow(
                        time: _formattedTime,
                        onTap: _showTimePicker,
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),

          const SizedBox(height: 24),
          const Divider(color: AsrioColors.border, height: 1),
          const SizedBox(height: 24),

          // ── Task Reminders ────────────────────────────────────────
          const _SectionLabel(label: 'TASK REMINDERS'),
          const SizedBox(height: 10),

          _ToggleRow(
            icon: Icons.check_circle_outline_rounded,
            title: 'Task reminders',
            subtitle: 'Allow individual task alarms',
            value: _taskEnabled,
            onChanged: (v) => setState(() => _taskEnabled = v),
          ),

          const SizedBox(height: 32),

          // Save button
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: _saving ? null : _save,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: _saving
                      ? AsrioColors.muted
                      : AsrioColors.black,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: _saving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                          color: AsrioColors.white, strokeWidth: 2),
                      )
                    : Text('Save',
                        style: AsrioText.cardTitleWhite
                            .copyWith(fontSize: 15)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Time Picker Sheet ─────────────────────────────────────────────────────────

class _TimePickerSheet extends StatefulWidget {
  const _TimePickerSheet({
    required this.initialHour,
    required this.initialMinute,
    required this.onConfirm,
  });
  final int initialHour;
  final int initialMinute;
  final void Function(int hour, int minute) onConfirm;

  @override
  State<_TimePickerSheet> createState() => _TimePickerSheetState();
}

class _TimePickerSheetState extends State<_TimePickerSheet> {
  late int _hour;
  late int _minute;

  @override
  void initState() {
    super.initState();
    _hour   = widget.initialHour;
    _minute = widget.initialMinute;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AsrioColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36, height: 3,
              decoration: BoxDecoration(
                color: AsrioColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Set Time', style: AsrioText.cardTitle),
          const SizedBox(height: 8),

          // CupertinoTimerPicker styled B/W
          SizedBox(
            height: 200,
            child: CupertinoTheme(
              data: const CupertinoThemeData(
                textTheme: CupertinoTextThemeData(
                  pickerTextStyle: TextStyle(
                    color: AsrioColors.black,
                    fontSize: 20,
                    fontFamily: 'DM Sans',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                initialDateTime: DateTime(
                  2000, 1, 1, _hour, _minute),
                use24hFormat: false,
                onDateTimeChanged: (dt) {
                  setState(() {
                    _hour   = dt.hour;
                    _minute = dt.minute;
                  });
                },
              ),
            ),
          ),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: () {
                widget.onConfirm(_hour, _minute);
                Navigator.pop(context);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AsrioColors.black,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text('Confirm',
                    style: AsrioText.cardTitleWhite
                        .copyWith(fontSize: 15)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) =>
      Text(label, style: AsrioText.label);
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22, color: AsrioColors.black),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AsrioText.taskTitle),
              Text(subtitle, style: AsrioText.bodyMuted),
            ],
          ),
        ),
        // Custom B/W toggle
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(!value);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 48, height: 28,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: value ? AsrioColors.black : AsrioColors.border,
              borderRadius: BorderRadius.circular(14),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              alignment: value
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Container(
                width: 22, height: 22,
                decoration: const BoxDecoration(
                  color: AsrioColors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({required this.time, required this.onTap});
  final String time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AsrioColors.offWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AsrioColors.border, width: 0.8),
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule_rounded,
                size: 18, color: AsrioColors.black),
            const SizedBox(width: 12),
            const Text('Remind me at', style: AsrioText.taskTitle),
            const Spacer(),
            Text(time,
                style: AsrioText.taskTitle.copyWith(
                    fontWeight: FontWeight.w700)),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AsrioColors.muted),
          ],
        ),
      ),
    );
  }
}
