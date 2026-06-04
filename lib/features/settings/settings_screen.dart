// lib/features/settings/settings_screen.dart — Phase 7 fix
// Wipe invalidates all providers. No marketing copy. Clean layout.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/biometric_service.dart';
import '../../core/theme/asrio_colors.dart';
import '../../core/theme/asrio_text_styles.dart';
import '../../providers/consistency_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/diary_provider.dart';
import '../../providers/habit_provider.dart';
import '../../providers/mood_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/task_provider.dart';
import '../shared/widgets/bento_card.dart';
import 'widgets/export_bottom_sheet.dart';
import 'widgets/language_bottom_sheet.dart';
import 'widgets/notification_bottom_sheet.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode   = ref.watch(themeModeProvider);
    final diaryLock   = ref.watch(diaryLockEnabledProvider);
    final isDark      = themeMode == ThemeMode.dark;
    final diaryOn     = ref.watch(diaryReminderEnabledProvider);
    final diaryHour   = ref.watch(diaryReminderHourProvider);
    final diaryMin    = ref.watch(diaryReminderMinuteProvider);
    final locale      = ref.watch(localeCodeProvider);

    final h12    = diaryHour == 0 ? 12 : (diaryHour > 12 ? diaryHour - 12 : diaryHour);
    final period = diaryHour >= 12 ? 'PM' : 'AM';
    final timeStr = diaryOn
        ? '$h12:${diaryMin.toString().padLeft(2, '0')} $period'
        : 'Off';

    return Scaffold(
      backgroundColor: AsrioColors.offWhite,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [

            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: Text('Settings', style: AsrioText.greeting),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // ── Security hero ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: BentoCard.black(
                  padding: const EdgeInsets.all(22),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_outlined,
                          color: AsrioColors.white, size: 32),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Privacy Vault',
                                style: AsrioText.cardTitleWhite),
                            const SizedBox(height: 6),
                            const _Badge(label: 'AES-256 ACTIVE'),
                            const SizedBox(height: 3),
                            const _Badge(label: 'LOCAL ONLY'),
                            if (diaryLock) ...[
                              const SizedBox(height: 3),
                              const _Badge(label: 'DIARY LOCK ON'),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── System grid ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: BentoCard.white(
                        padding: const EdgeInsets.all(18),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          ref.read(themeModeProvider.notifier).setTheme(
                              isDark ? ThemeMode.light : ThemeMode.dark);
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              isDark ? Icons.light_mode_outlined
                                     : Icons.dark_mode_outlined,
                              size: 26, color: AsrioColors.black,
                            ),
                            const SizedBox(height: 10),
                            const Text('Theme', style: AsrioText.taskTitle),
                            Text(isDark ? 'Dark' : 'Light',
                                style: AsrioText.bodyMuted),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: BentoCard.white(
                        padding: EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.vibration_rounded,
                                size: 26, color: AsrioColors.black),
                            SizedBox(height: 10),
                            Text('Haptics', style: AsrioText.taskTitle),
                            Text('Enabled', style: AsrioText.bodyMuted),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // ── Diary Lock ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _LockTile(
                  isEnabled: diaryLock,
                  onToggle: (v) => _handleLockToggle(context, ref, v),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // ── Notifications ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: BentoCard.white(
                  padding: const EdgeInsets.all(18),
                  onTap: () => showNotificationSheet(context),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_none_rounded,
                          size: 26, color: AsrioColors.black),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Notifications', style: AsrioText.taskTitle),
                            Text(diaryOn
                                ? 'Diary at $timeStr'
                                : 'No reminders set',
                                style: AsrioText.bodyMuted),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: AsrioColors.muted),
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // ── Language ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: BentoCard.white(
                  padding: const EdgeInsets.all(18),
                  onTap: () => showLanguageSheet(context),
                  child: Row(
                    children: [
                      const Icon(Icons.language_rounded,
                          size: 26, color: AsrioColors.black),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Language', style: AsrioText.taskTitle),
                            Text(_langName(locale), style: AsrioText.bodyMuted),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: AsrioColors.muted),
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text('DATA', style: AsrioText.label),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 10)),

            // ── Export ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: BentoCard.white(
                  padding: const EdgeInsets.all(18),
                  onTap: () => showExportSheet(context),
                  child: const Row(
                    children: [
                      Icon(Icons.download_outlined,
                          size: 22, color: AsrioColors.black),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Export Data', style: AsrioText.taskTitle),
                            Text('Encrypted or plaintext backup',
                                style: AsrioText.bodyMuted),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: AsrioColors.muted),
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // ── Wipe ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GestureDetector(
                  onTap: () => _confirmWipe(context, ref),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AsrioColors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AsrioColors.dangerBorder, width: 1.2),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.delete_forever_outlined,
                            size: 22, color: AsrioColors.dangerBorder),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Wipe Local Data',
                                  style: AsrioText.taskTitle.copyWith(
                                      color: AsrioColors.dangerBorder)),
                              const Text('Permanently delete everything.',
                                  style: AsrioText.bodyMuted),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Branding ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 36, 20, 32),
                child: Column(
                  children: [
                    Image.asset('assets/Asrio.png', width: 40, height: 40,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.apps_rounded,
                            size: 40, color: AsrioColors.muted)),
                    const SizedBox(height: 10),
                    Text('ASRIO v1.0',
                        style: AsrioText.label
                            .copyWith(color: AsrioColors.black)),
                    const SizedBox(height: 3),
                    const Text('Designed by Darshseraphic',
                        style: AsrioText.caption),
                    const SizedBox(height: 3),
                    const Text('All data stays on device.',
                        style: AsrioText.caption),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Diary Lock ────────────────────────────────────────────────────────────

  Future<void> _handleLockToggle(
      BuildContext context, WidgetRef ref, bool enable) async {
    if (!enable) {
      await ref.read(diaryLockEnabledProvider.notifier).disable();
      return;
    }
    final canUse = await BiometricService().canUseBiometrics();
    if (!canUse) { if (context.mounted) _noBioDialog(context); return; }
    final r = await BiometricService().authenticate(
        lockEnabled: true,
        reason: 'Confirm your identity to enable Diary Lock.');
    if (!context.mounted) return;
    if (r == BiometricResult.success) {
      await ref.read(diaryLockEnabledProvider.notifier).enable();
      HapticFeedback.mediumImpact();
    } else if (r == BiometricResult.unavailable) {
      _noBioDialog(context);
    }
  }

  void _noBioDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AsrioColors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Biometrics unavailable', style: AsrioText.cardTitle),
        content: const Text(
          'No biometrics enrolled. Go to device Settings → Security.',
          style: AsrioText.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK',
                style: AsrioText.taskTitle
                    .copyWith(color: AsrioColors.black)),
          ),
        ],
      ),
    );
  }

  // ── Wipe — invalidates ALL providers ─────────────────────────────────────

  Future<void> _confirmWipe(BuildContext context, WidgetRef ref) async {
    HapticFeedback.heavyImpact();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AsrioColors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Wipe all data?', style: AsrioText.cardTitle),
        content: const Text(
          'This permanently deletes all tasks, diary, habits, and mood logs.',
          style: AsrioText.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: AsrioText.taskTitle
                    .copyWith(color: AsrioColors.secondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Wipe',
                style: AsrioText.taskTitle
                    .copyWith(color: AsrioColors.dangerBorder)),
          ),
        ],
      ),
    );

    if (ok != true || !context.mounted) return;

    final db = ref.read(databaseProvider);

    // ── Raw SQL deletes — no generated type dependencies ─────────────────
    await db.customStatement('DELETE FROM tasks');
    await db.customStatement('DELETE FROM diary_pages');
    await db.customStatement('DELETE FROM habits');
    await db.customStatement('DELETE FROM activity_log');
    await db.customStatement('DELETE FROM mood_logs');

    // ── Invalidate ALL Riverpod state so UI refreshes cleanly ────────────
    ref.invalidate(watchDailyTasksProvider);
    ref.invalidate(watchYearlyTasksProvider);
    ref.invalidate(watchAllTasksProvider);
    ref.invalidate(activeDiaryDatesProvider);
    ref.invalidate(diaryNotifierProvider);
    ref.invalidate(watchActiveHabitsProvider);
    ref.invalidate(watchAllHabitsProvider);
    ref.invalidate(todayMoodProvider);
    ref.invalidate(streakProvider);
    ref.invalidate(dailyOpenCountsProvider);
    ref.invalidate(diaryActiveDatesProvider);
    ref.invalidate(appUsagePermissionProvider);
    ref.invalidate(appUsageStatsProvider);

    // ── Reset onboarding so user sees it on next launch ──────────────────
    await ref.read(onboardingDoneProvider.notifier).disable();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All data has been wiped.'),
          backgroundColor: AsrioColors.black,
        ),
      );
    }
  }

  static const _localeNames = {
    'en': 'English', 'de': 'Deutsch', 'fr': 'Français',
    'es': 'Español', 'it': 'Italiano', 'pt': 'Português',
    'hu': 'Magyar', 'ro': 'Română', 'tr': 'Türkçe',
    'ru': 'Русский', 'uk': 'Українська', 'zh': '中文',
    'ja': '日本語', 'ko': '한국어', 'vi': 'Tiếng Việt',
    'ar': 'العربية', 'id': 'Bahasa Indonesia', 'th': 'ภาษาไทย',
    'hi': 'हिन्दी', 'nl': 'Nederlands', 'pl': 'Polski', 'sv': 'Svenska',
  };

  String _langName(String code) => _localeNames[code] ?? code.toUpperCase();
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _LockTile extends StatefulWidget {
  const _LockTile({required this.isEnabled, required this.onToggle});
  final bool isEnabled;
  final Future<void> Function(bool) onToggle;

  @override
  State<_LockTile> createState() => _LockTileState();
}

class _LockTileState extends State<_LockTile> {
  String _label = 'Biometric';
  bool _toggling = false;

  @override
  void initState() {
    super.initState();
    BiometricService().getBiometricTypeLabel().then(
        (l) { if (mounted) setState(() => _label = l); });
  }

  @override
  Widget build(BuildContext context) {
    return BentoCard.white(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              widget.isEnabled ? Icons.lock_rounded : Icons.lock_open_outlined,
              key: ValueKey(widget.isEnabled),
              size: 26, color: AsrioColors.black,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Diary Lock', style: AsrioText.taskTitle),
                Text(
                  widget.isEnabled
                      ? '$_label required'
                      : 'Enable $_label protection',
                  style: AsrioText.bodyMuted,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _toggling ? null : () async {
              setState(() => _toggling = true);
              await widget.onToggle(!widget.isEnabled);
              if (mounted) setState(() => _toggling = false);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 48, height: 28,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: widget.isEnabled
                    ? AsrioColors.black : AsrioColors.border,
                borderRadius: BorderRadius.circular(14),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                alignment: widget.isEnabled
                    ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 22, height: 22,
                  decoration: const BoxDecoration(
                    color: AsrioColors.white, shape: BoxShape.circle),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 3),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: AsrioColors.white.withAlpha(20),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: AsrioText.caption.copyWith(color: AsrioColors.white)),
      );
}
