// lib/features/shared/widgets/circular_ring.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/asrio_colors.dart';

/// A thin-stroke circular progress ring.
/// Used on habit tiles (B/W) and the streak hero card (white on black).
class CircularRing extends StatelessWidget {
  const CircularRing({
    super.key,
    required this.progress,   // 0.0 → 1.0
    required this.size,
    this.strokeWidth = 2.5,
    this.ringColor,
    this.trackColor,
    this.child,
  });

  final double progress;
  final double size;
  final double strokeWidth;
  final Color? ringColor;
  final Color? trackColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final ring  = ringColor  ?? AsrioColors.black;
    final track = trackColor ?? AsrioColors.border;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress.clamp(0.0, 1.0),
          ringColor: ring,
          trackColor: track,
          strokeWidth: strokeWidth,
        ),
        child: child != null
            ? Center(child: child)
            : null,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.ringColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color ringColor;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - strokeWidth / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = ringColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw full track.
    canvas.drawCircle(center, radius, trackPaint);

    // Draw progress arc starting from the top (-π/2).
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.ringColor != ringColor;
}
