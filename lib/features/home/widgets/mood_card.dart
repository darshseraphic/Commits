// lib/features/home/widgets/mood_card.dart
//
// ══════════════════════════════════════════════════════════════════════════════
// MoodCard — Home Screen Circular Mood Selector
// ══════════════════════════════════════════════════════════════════════════════
//
// STATES:
//   Unlogged  — 5 hollow circles, "How are you feeling?" prompt.
//   Logged    — Collapses to single row with selected circle + label.
//               Smooth AnimatedContainer height transition.
//
// COLOR CONTRACT (MoodPalette):
//   Light theme: #000000=Happy → #404040=Fun → #7f7f7f=Normal
//                             → #bfbfbf=Off → #ffffff=Sad
//   Dark theme:  inverse (white=Happy, black=Sad)
//   #7f7f7f always = Normal (theme-invariant anchor)
//
// SELECTION INDICATOR:
//   A 2px ring separated by 3px gap — "lifting" premium feel.
//   Ring color = inverse of circle fill.
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/asrio_colors.dart';
import '../../../core/theme/asrio_text_styles.dart';
import '../../../data/models/mood_model.dart';
import '../../../providers/mood_provider.dart';
import '../../shared/widgets/bento_card.dart';

class MoodCard extends ConsumerWidget {
  const MoodCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayMood = ref.watch(todayMoodProvider);

    return todayMood.when(
      loading: () => const _MoodCardShell(child: _LoadingRow()),
      error:   (_, __) => const SizedBox.shrink(),
      data:    (mood) => _MoodCardShell(
        child: mood != null && mood.isToday
            ? _LoggedState(mood: mood)
            : const _UnloggedState(),
      ),
    );
  }
}

// ── Shell with animated height ────────────────────────────────────────────────

class _MoodCardShell extends StatelessWidget {
  const _MoodCardShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BentoCard.white(
      padding: const EdgeInsets.all(0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeInOutCubic,
          child: child,
        ),
      ),
    );
  }
}

// ── Unlogged State ────────────────────────────────────────────────────────────

class _UnloggedState extends ConsumerStatefulWidget {
  const _UnloggedState();

  @override
  ConsumerState<_UnloggedState> createState() => _UnloggedStateState();
}

class _UnloggedStateState extends ConsumerState<_UnloggedState> {
  int? _hoveredPosition;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text('How are you feeling?', style: AsrioText.cardTitle),
            ],
          ),
          const SizedBox(height: 20),

          // Circles row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (i) {
              final position  = i + 1;
              final fillColor = MoodPalette.colorAt(position);
              final isHovered = _hoveredPosition == position;

              return GestureDetector(
                onTap: () async {
                  HapticFeedback.selectionClick();
                  await ref
                      .read(moodNotifierProvider.notifier)
                      .logMood(position);
                },
                onTapDown: (_) =>
                    setState(() => _hoveredPosition = position),
                onTapUp: (_) =>
                    setState(() => _hoveredPosition = null),
                onTapCancel: () =>
                    setState(() => _hoveredPosition = null),
                child: _MoodCircle(
                  fillColor: fillColor,
                  isSelected: false,
                  isHovered: isHovered,
                  label: null, // No label in unlogged state.
                ),
              );
            }),
          ),

          const SizedBox(height: 14),

          // Mood label row — shows on hover only
          SizedBox(
            height: 16,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: _hoveredPosition != null
                  ? Text(
                      MoodPalette.labelAt(_hoveredPosition!, brightness),
                      key: ValueKey(_hoveredPosition),
                      style: AsrioText.caption.copyWith(
                        color: AsrioColors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : Text('Tap to log',
                      key: const ValueKey('tap'),
                      style: AsrioText.caption),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Logged State (collapsed) ──────────────────────────────────────────────────

class _LoggedState extends ConsumerWidget {
  const _LoggedState({required this.mood});
  final MoodEntry mood;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    final fillColor  = MoodPalette.colorAt(mood.position);
    final label      = MoodPalette.labelAt(mood.position, brightness);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // Small selected circle
          _MoodCircle(
            fillColor: fillColor,
            isSelected: true,
            isHovered: false,
            label: null,
            size: 28,
            ringWidth: 1.5,
            ringGap: 2,
          ),

          const SizedBox(width: 14),

          // Label + logged message
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AsrioText.taskTitle.copyWith(
                        fontWeight: FontWeight.w700)),
                Text('Mood logged · tap to update',
                    style: AsrioText.caption),
              ],
            ),
          ),

          // Checkmark
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AsrioColors.black,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded,
                size: 14, color: AsrioColors.white),
          ),
        ],
      ),
    );
  }
}

// ── Mood Circle ───────────────────────────────────────────────────────────────

class _MoodCircle extends StatelessWidget {
  const _MoodCircle({
    required this.fillColor,
    required this.isSelected,
    required this.isHovered,
    required this.label,
    this.size = 48,
    this.ringWidth = 2.0,
    this.ringGap = 3.0,
  });

  final Color fillColor;
  final bool isSelected;
  final bool isHovered;
  final String? label;
  final double size;
  final double ringWidth;
  final double ringGap;

  @override
  Widget build(BuildContext context) {
    final borderColor  = MoodPalette.borderFor(fillColor);
    final ringColor    = MoodPalette.ringFor(fillColor);
    final showRing     = isSelected || isHovered;

    // Total widget size = circle + ring gap + ring width (on each side)
    final outerSize = showRing
        ? size + (ringGap + ringWidth) * 2
        : size;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutBack,
      width: outerSize,
      height: outerSize,
      decoration: showRing
          ? BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ringColor, width: ringWidth),
            )
          : null,
      child: Padding(
        padding: EdgeInsets.all(showRing ? ringGap : 0),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fillColor,
            border: borderColor != Colors.transparent
                ? Border.all(color: borderColor, width: 1.0)
                : null,
          ),
        ),
      ),
    );
  }
}

class _LoadingRow extends StatelessWidget {
  const _LoadingRow();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _SkeletonCircle(),
            _SkeletonCircle(),
            _SkeletonCircle(),
            _SkeletonCircle(),
            _SkeletonCircle(),
          ],
        ),
      );
}

class _SkeletonCircle extends StatelessWidget {
  const _SkeletonCircle();

  @override
  Widget build(BuildContext context) => Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: AsrioColors.border,
          shape: BoxShape.circle,
        ),
      );
}
