// lib/features/settings/settings_screen.dart — Phase 6 (fully wired)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/biometric_service.dart';
import '../../core/theme/asrio_colors.dart';
import '../../core/theme/asrio_text_styles.dart';
import '../../providers/settings_provider.dart';
import '../../providers/database_provider.dart';
import '../shared/widgets/bento_card.dart';
import 'widgets/export_bottom_sheet.dart';
import 'widgets/language_bottom_sheet.dart';
import 'widgets/notification_bottom_sheet.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode  = ref.watch(themeModeProvider);
    final diaryLock  = ref.watch(diaryLockEnabledProvider);
    final isDark     = themeMode == ThemeMode.dark;
    final diaryReminderEnabled = ref.watch(diaryReminderEnabledProvider);
    final diaryHour   = ref.watch(diaryReminderHourProvider);
    final diaryMinute = ref.watch(diaryReminderMinuteProvider);
    final currentLocale = ref.watch(localeCodeProvider);

    // Format time for tile subtitle
    final h12 = diaryHour == 0 ? 12 : (diaryHour > 12 ? diaryHour - 12 : diaryHour);
    final period = diaryHour >= 12 ? 'PM' : 'AM';
    final timeLabel = diaryReminderEnabled
        ? '$h12:${diaryMinute.toString().padLeft(2, '0')} $period'
        : 'Off';

    return Scaffold(
      backgroundColor: AsrioColors.offWhite,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [

            // ── Header ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Settings', style: AsrioText.greeting),
                    const SizedBox(height: 4),
                    Text('Your control center.', style: AsrioText.bodyMuted),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // ── Security Hero Card ─────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: BentoCard.black(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_outlined,
                          color: AsrioColors.white, size: 36),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Privacy Vault',
                                style: AsrioText.cardTitleWhite),
                            const SizedBox(height: 8),
                            _StatusBadge(label: 'AES-256 ACTIVE'),
                            const SizedBox(height: 4),
                            _StatusBadge(label: 'LOCAL STORAGE ONLY'),
                            if (diaryLock) ...[
                              const SizedBox(height: 4),
                              _StatusBadge(label: 'DIARY LOCK ON'),
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

            // ── System Grid ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: BentoCard.white(
                        padding: const EdgeInsets.all(20),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          ref.read(themeModeProvider.notifier).setTheme(
                              isDark ? ThemeMode.light : ThemeMode.dark);
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              isDark
                                  ? Icons.light_mode_outlined
                                  : Icons.dark_mode_outlined,
                              size: 28, color: AsrioColors.black,
                            ),
                            const SizedBox(height: 12),
                            Text('Theme', style: AsrioText.taskTitle),
                            const SizedBox(height: 4),
                            Text(isDark ? 'Dark' : 'Light',
                                style: AsrioText.bodyMuted),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: BentoCard.white(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.vibration_rounded,
                                size: 28, color: AsrioColors.black),
                            const SizedBox(height: 12),
                            Text('Haptics', style: AsrioText.taskTitle),
                            const SizedBox(height: 4),
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
                child: _DiaryLockTile(
                  isEnabled: diaryLock,
                  onToggle: (v) =>
                      _handleDiaryLockToggle(context, ref, v),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // ── Notifications (NOW WIRED) ─────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: BentoCard.white(
                  padding: const EdgeInsets.all(20),
                  onTap: () => showNotificationSheet(context),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_none_rounded,
                          size: 28, color: AsrioColors.black),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Notifications',
                                style: AsrioText.taskTitle),
                            const SizedBox(height: 4),
                            Text(
                              diaryReminderEnabled
                                  ? 'Diary reminder at $timeLabel'
                                  : 'No reminders set',
                              style: AsrioText.bodyMuted,
                            ),
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

            // ── Language (NOW WIRED) ──────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: BentoCard.white(
                  padding: const EdgeInsets.all(20),
                  onTap: () => showLanguageSheet(context),
                  child: Row(
                    children: [
                      const Icon(Icons.language_rounded,
                          size: 28, color: AsrioColors.black),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Language', style: AsrioText.taskTitle),
                            const SizedBox(height: 4),
                            Text(
                              _languageName(currentLocale),
                              style: AsrioText.bodyMuted,
                            ),
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

            // ── Data Management ───────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text('DATA MANAGEMENT', style: AsrioText.label),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 10)),

            // ── Export (NOW WIRED) ────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: BentoCard.white(
                  padding: const EdgeInsets.all(20),
                  onTap: () => showExportSheet(context),
                  child: Row(
                    children: [
                      const Icon(Icons.download_outlined,
                          size: 24, color: AsrioColors.black),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Export Data',
                                style: AsrioText.taskTitle),
                            const SizedBox(height: 4),
                            Text(
                              'Encrypted or plaintext backup',
                              style: AsrioText.bodyMuted,
                            ),
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

            // ── Wipe Data ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GestureDetector(
                  onTap: () => _confirmWipe(context, ref),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AsrioColors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AsrioColors.dangerBorder, width: 1.2),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.delete_forever_outlined,
                            size: 24,
                            color: AsrioColors.dangerBorder),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Wipe Local Data',
                                  style: AsrioText.taskTitle.copyWith(
                                      color: AsrioColors.dangerBorder)),
                              const SizedBox(height: 4),
                              Text(
                                'Permanently delete all tasks, diary, and habits.',
                                style: AsrioText.bodyMuted,
                              ),
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
                padding: const EdgeInsets.fromLTRB(20, 40, 20, 32),
                child: Column(
                  children: [
                    // App logo
                    Image.asset(
                      'assets/Asrio.png',
                      width: 48,
                      height: 48,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.apps_rounded,
                        size: 48,
                        color: AsrioColors.muted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('ASRIO v1.0',
                        style: AsrioText.label
                            .copyWith(color: AsrioColors.black)),
                    const SizedBox(height: 4),
                    Text('Designed by Darshseraphic',
                        style: AsrioText.caption),
                    const SizedBox(height: 4),
                    Text('All data stays on device.',
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

  // ── Helpers ───────────────────────────────────────────────────────────────

  static const _localeNames = {
    'en': 'English', 'de': 'Deutsch', 'fr': 'Français',
    'es': 'Español', 'it': 'Italiano', 'pt': 'Português',
    'hu': 'Magyar', 'ro': 'Română', 'tr': 'Türkçe',
    'ru': 'Русский', 'uk': 'Українська', 'zh': '中文',
    'ja': '日本語', 'ko': '한국어', 'vi': 'Tiếng Việt',
    'ar': 'العربية', 'id': 'Bahasa Indonesia', 'th': 'ภาษาไทย',
    'hi': 'हिन्दी', 'nl': 'Nederlands', 'pl': 'Polski', 'sv': 'Svenska',
  };

  String _languageName(String code) =>
      _localeNames[code] ?? code.toUpperCase();

  Future<void> _handleDiaryLockToggle(
      BuildContext context, WidgetRef ref, bool enable) async {
    if (!enable) {
      await ref.read(diaryLockEnabledProvider.notifier).disable();
      return;
    }
    final canUse = await BiometricService().canUseBiometrics();
    if (!canUse) {
      if (!context.mounted) return;
      _showNoBiometricsDialog(context);
      return;
    }
    final result = await BiometricService()
        .authenticate(lockEnabled: true,
            reason: 'Confirm your identity to enable Diary Lock.');
    if (!context.mounted) return;
    if (result == BiometricResult.success) {
      await ref.read(diaryLockEnabledProvider.notifier).enable();
      HapticFeedback.mediumImpact();
    } else if (result == BiometricResult.unavailable) {
      _showNoBiometricsDialog(context);
    }
  }

  void _showNoBiometricsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AsrioColors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('Biometrics unavailable', style: AsrioText.cardTitle),
        content: Text(
          'Your device does not have biometrics enrolled.\n\n'
          'Go to device Settings → Security to set up fingerprint first.',
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

  Future<void> _confirmWipe(BuildContext context, WidgetRef ref) async {
    HapticFeedback.heavyImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AsrioColors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('Wipe all data?', style: AsrioText.cardTitle),
        content: Text(
          'This will permanently delete your tasks, diary entries, '
          'habits, and mood logs. This action cannot be undone.',
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

    if (confirmed != true || !context.mounted) return;

    // Full data destruction sequence — raw SQL to avoid generated type issues.
    final db = ref.read(databaseProvider);
    await db.customStatement('DELETE FROM tasks');
    await db.customStatement('DELETE FROM diary_pages');
    await db.customStatement('DELETE FROM habits');
    await db.customStatement('DELETE FROM activity_log');
    await db.customStatement('DELETE FROM mood_logs');

    // Reset onboarding so the user sees it again on next launch.
    await ref.read(onboardingDoneProvider.notifier).markDone();
    // Note: We do NOT call EncryptionService.destroyKey() here because
    // the user may want to reinstall and restore from backup.
    // Key destruction is a separate, more drastic action for Phase 7.

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All data has been wiped.'),
          backgroundColor: AsrioColors.black,
        ),
      );
    }
  }
}

// ── Diary Lock Tile ───────────────────────────────────────────────────────────

class _DiaryLockTile extends StatefulWidget {
  const _DiaryLockTile({required this.isEnabled, required this.onToggle});
  final bool isEnabled;
  final Future<void> Function(bool) onToggle;

  @override
  State<_DiaryLockTile> createState() => _DiaryLockTileState();
}

class _DiaryLockTileState extends State<_DiaryLockTile> {
  String _biometricLabel = 'Biometric';
  bool _toggling = false;

  @override
  void initState() {
    super.initState();
    BiometricService().getBiometricTypeLabel().then(
        (l) { if (mounted) setState(() => _biometricLabel = l); });
  }

  @override
  Widget build(BuildContext context) {
    return BentoCard.white(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Icon(
              widget.isEnabled ? Icons.lock_rounded : Icons.lock_open_outlined,
              key: ValueKey(widget.isEnabled),
              size: 28, color: AsrioColors.black,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Diary Lock', style: AsrioText.taskTitle),
                const SizedBox(height: 4),
                Text(
                  widget.isEnabled
                      ? '$_biometricLabel required to open diary'
                      : 'Tap to enable $_biometricLabel protection',
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AsrioColors.white.withAlpha(20),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: AsrioText.caption.copyWith(color: AsrioColors.white)),
      );
}
