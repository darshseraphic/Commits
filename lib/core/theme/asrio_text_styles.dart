// lib/core/theme/asrio_text_styles.dart
//
// All typography in one place. Widgets import this, never hardcode fontSize.

import 'package:flutter/material.dart';
import 'asrio_colors.dart';

abstract final class AsrioText {
  static const _family = 'DM Sans';

  // ── Display ───────────────────────────────────────────────────────────────
  /// The massive streak number on the Consistency screen.
  static const streakHero = TextStyle(
    fontFamily: _family,
    fontSize: 80,
    fontWeight: FontWeight.w800,
    color: AsrioColors.white,
    height: 1.0,
    letterSpacing: -4,
  );

  /// Screen-level greeting: "Good morning, Darsh"
  static const greeting = TextStyle(
    fontFamily: _family,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AsrioColors.black,
    letterSpacing: -0.5,
    height: 1.2,
  );

  /// Section headings inside cards.
  static const cardTitle = TextStyle(
    fontFamily: _family,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AsrioColors.black,
    letterSpacing: -0.3,
  );

  static const cardTitleWhite = TextStyle(
    fontFamily: _family,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AsrioColors.white,
    letterSpacing: -0.3,
  );

  // ── Body ──────────────────────────────────────────────────────────────────
  static const body = TextStyle(
    fontFamily: _family,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AsrioColors.black,
    height: 1.5,
  );

  static const bodyWhite = TextStyle(
    fontFamily: _family,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AsrioColors.white,
    height: 1.5,
  );

  static const bodyMuted = TextStyle(
    fontFamily: _family,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AsrioColors.secondary,
    height: 1.4,
  );

  // ── Labels ────────────────────────────────────────────────────────────────
  static const label = TextStyle(
    fontFamily: _family,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AsrioColors.secondary,
    letterSpacing: 0.8,
  );

  static const labelWhite = TextStyle(
    fontFamily: _family,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AsrioColors.muted,
    letterSpacing: 0.8,
  );

  static const caption = TextStyle(
    fontFamily: _family,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AsrioColors.muted,
    letterSpacing: 0.3,
  );

  // ── Diary ─────────────────────────────────────────────────────────────────
  /// Date header on a diary entry row.
  static const diaryDate = TextStyle(
    fontFamily: _family,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AsrioColors.black,
    letterSpacing: -0.2,
  );

  /// One-line preview text on a diary entry row.
  static const diaryPreview = TextStyle(
    fontFamily: _family,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AsrioColors.secondary,
    height: 1.4,
  );

  /// The writing font inside the diary canvas.
  static const diaryBody = TextStyle(
    fontFamily: _family,
    fontSize: 17,
    fontWeight: FontWeight.w400,
    color: AsrioColors.black,
    height: 1.8, // Wide line spacing — feels like a quality journal.
    letterSpacing: 0.1,
  );

  // ── Tasks ─────────────────────────────────────────────────────────────────
  static const taskTitle = TextStyle(
    fontFamily: _family,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AsrioColors.black,
    height: 1.3,
  );

  static const taskTitleCompleted = TextStyle(
    fontFamily: _family,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AsrioColors.muted,
    height: 1.3,
    decoration: TextDecoration.lineThrough,
    decorationColor: AsrioColors.muted,
  );

  static const taskTitleWhite = TextStyle(
    fontFamily: _family,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AsrioColors.white,
    height: 1.3,
  );
}
