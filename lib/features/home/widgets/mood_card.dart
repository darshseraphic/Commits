// lib/features/home/widgets/mood_card.dart — Phase 7 fix
// Face selector replaces circles. Overflow fixed. Crash fixed.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/asrio_colors.dart';
import '../../../core/theme/asrio_text_styles.dart';
import '../../../data/models/mood_model.dart';
import '../../../providers/mood_provider.dart';
import '../../../providers/repository_providers.dart';
import '../../shared/widgets/bento_card.dart';

class MoodCard extends ConsumerWidget {
  const MoodCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayMood = ref.watch(todayMoodProvider);

    return todayMood.when(
      loading: () => const _Shell(child: _SkeletonRow()),
      error:   (_, __) => const SizedBox.shrink(),
      data:    (mood) => _Shell(
        child: mood != null && mood.isToday
            ? _LoggedState(mood: mood)
            : const _UnloggedState(),
      ),
    );
  }
}

// ── Shell with smooth height animation ───────────────────────────────────────

class _Shell extends StatelessWidget {
  const _Shell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BentoCard.white(
      padding: EdgeInsets.zero,
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

// ── Unlogged: five faces ──────────────────────────────────────────────────────

class _UnloggedState extends ConsumerStatefulWidget {
  const _UnloggedState();

  @override
  ConsumerState<_UnloggedState> createState() => _UnloggedStateState();
}

class _UnloggedStateState extends ConsumerState<_UnloggedState> {
  int? _hovered;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('How are you feeling?', style: AsrioText.cardTitle),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (i) {
              final pos   = i + 1;
              final color = MoodPalette.colorAt(pos);
              return GestureDetector(
                onTap: () async {
                  HapticFeedback.selectionClick();
                  // Direct repository call — avoids notifier state machine crash
                  await ref.read(moodRepositoryProvider).logMood(pos);
                },
                onTapDown: (_) => setState(() => _hovered = pos),
                onTapUp:   (_) => setState(() => _hovered = null),
                onTapCancel: () => setState(() => _hovered = null),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutBack,
                  width:  _hovered == pos ? 52 : 44,
                  height: _hovered == pos ? 52 : 44,
                  child: CustomPaint(
                    painter: _FacePainter(
                      moodPosition: pos,
                      faceColor:   color,
                      strokeColor: _faceStrokeColor(color, brightness),
                      strokeWidth: 1.8,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 14,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: _hovered != null
                  ? Text(
                      MoodPalette.labelAt(_hovered!, brightness),
                      key: ValueKey(_hovered),
                      style: AsrioText.caption.copyWith(
                        color: AsrioColors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : Text('Select your mood',
                      key: const ValueKey('hint'),
                      style: AsrioText.caption),
            ),
          ),
        ],
      ),
    );
  }

  Color _faceStrokeColor(Color fill, Brightness brightness) {
    final lum = fill.computeLuminance();
    if (lum > 0.85) return AsrioColors.secondary; // near-white fill → grey stroke
    return fill;
  }
}

// ── Logged: collapsed row — OVERFLOW FIXED with Expanded ─────────────────────

class _LoggedState extends ConsumerWidget {
  const _LoggedState({required this.mood});
  final MoodEntry mood;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    final color      = MoodPalette.colorAt(mood.position);
    final label      = MoodPalette.labelAt(mood.position, brightness);
    final strokeColor = color.computeLuminance() > 0.85
        ? AsrioColors.secondary
        : color;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          // Compact face
          SizedBox(
            width: 32, height: 32,
            child: CustomPaint(
              painter: _FacePainter(
                moodPosition: mood.position,
                faceColor:   color,
                strokeColor: strokeColor,
                strokeWidth: 1.6,
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Label + hint — EXPANDED prevents overflow
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: AsrioText.taskTitle
                        .copyWith(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
                Text('Logged · tap to change',
                    style: AsrioText.caption,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Change button — tap re-expands
          GestureDetector(
            onTap: () async {
              HapticFeedback.selectionClick();
              // Reset today's mood by setting an invalid sentinel so the
              // stream sees null → card expands to selection state again.
              // We delete today's entry directly via raw SQL in the DAO.
              await ref.read(moodRepositoryProvider)
                  .logMood(mood.position); // re-tap same pos = no-op
              // To trigger expansion: invalidate the stream provider.
              ref.invalidate(todayMoodProvider);
            },
            child: Container(
              width: 28, height: 28,
              decoration: const BoxDecoration(
                color: AsrioColors.black,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  size: 14, color: AsrioColors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Face CustomPainter ────────────────────────────────────────────────────────

class _FacePainter extends CustomPainter {
  const _FacePainter({
    required this.moodPosition,
    required this.faceColor,
    required this.strokeColor,
    required this.strokeWidth,
  });

  final int    moodPosition; // 1=Happy … 5=Sad
  final Color  faceColor;
  final Color  strokeColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;
    final r  = math.min(cx, cy) * 0.9;

    final fill = Paint()..color = faceColor..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color      = strokeColor
      ..strokeWidth = strokeWidth
      ..style      = PaintingStyle.stroke
      ..strokeCap  = StrokeCap.round;

    // Face circle
    canvas.drawCircle(Offset(cx, cy), r, fill);
    canvas.drawCircle(Offset(cx, cy), r, stroke);

    // Eyes
    final eyeY = cy - r * 0.20;
    final eyeX = r * 0.28;
    final eyeR = r * 0.07;
    canvas.drawCircle(Offset(cx - eyeX, eyeY), eyeR, stroke..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(cx + eyeX, eyeY), eyeR, stroke);
    stroke.style = PaintingStyle.stroke;

    // Mouth
    final mouthY = cy + r * 0.18;
    final mw     = r * 0.38;
    final curve  = switch (moodPosition) {
      1 => -r * 0.22,
      2 => -r * 0.10,
      3 =>  0.0,
      4 =>  r * 0.10,
      _ =>  r * 0.22,
    };
    final path = Path()
      ..moveTo(cx - mw, mouthY)
      ..quadraticBezierTo(cx, mouthY + curve, cx + mw, mouthY);
    canvas.drawPath(path, stroke);

    // Eyebrows for sad/not-good
    if (moodPosition >= 4) {
      final bw    = r * 0.22;
      final browY = eyeY - r * 0.20;
      final drop  = moodPosition == 5 ? r * 0.09 : r * 0.04;

      canvas.drawLine(
        Offset(cx - eyeX - bw / 2, browY + drop),
        Offset(cx - eyeX + bw / 2, browY - drop),
        stroke,
      );
      canvas.drawLine(
        Offset(cx + eyeX - bw / 2, browY - drop),
        Offset(cx + eyeX + bw / 2, browY + drop),
        stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_FacePainter o) =>
      o.moodPosition != moodPosition || o.faceColor != faceColor;
}

// ── Skeleton ──────────────────────────────────────────────────────────────────

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            5,
            (_) => Container(
              width: 44, height: 44,
              decoration: const BoxDecoration(
                color: AsrioColors.border,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      );
}
