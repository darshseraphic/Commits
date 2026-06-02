// lib/core/theme/asrio_colors.dart
//
// ══════════════════════════════════════════════════════════════════════════════
// ASRIO — Monochromatic Design Tokens
// ══════════════════════════════════════════════════════════════════════════════
//
// RULE: Every color in every widget traces back to a constant here.
// No hex literals anywhere else in the codebase.
//
// The palette is intentionally severe: only 7 values between pure black
// and pure white. This is what creates the "high-end vault" feeling.
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

abstract final class AsrioColors {
  // ── Core ──────────────────────────────────────────────────────────────────
  static const black      = Color(0xFF000000); // Dominant cards, FAB, active
  static const white      = Color(0xFFFFFFFF); // Backgrounds, text on black
  static const offWhite   = Color(0xFFF5F5F5); // Card surfaces (light mode)
  static const border     = Color(0xFFE0E0E0); // Dividers, card borders
  static const muted      = Color(0xFFBDBDBD); // Completed tasks, captions
  static const secondary  = Color(0xFF9E9E9E); // Timestamps, subtitles
  static const darkSurf   = Color(0xFF1C1C1C); // Dark mode card surface
  static const darkBg     = Color(0xFF121212); // Dark mode scaffold

  // ── Semantic Aliases ──────────────────────────────────────────────────────
  // Give intent to raw values so widgets read like English.
  static const focusCard        = black;       // The #1 priority "Focus" card
  static const focusCardText    = white;
  static const taskCard         = white;       // Active task cards
  static const taskCardBorder   = border;
  static const completedText    = muted;       // Greyed-out completed tasks
  static const divider          = border;      // Notebook-style lines
  static const heatmapEmpty     = white;       // 0% activity
  static const heatmapLight     = Color(0xFFE8E8E8); // ~25% activity
  static const heatmapMid       = Color(0xFFAAAAAA); // ~50% activity
  static const heatmapDark      = Color(0xFF555555); // ~75% activity
  static const heatmapFull      = black;       // 100% activity
  static const dangerBorder     = Color(0xFFE53935); // "Wipe Data" — only red allowed

  // ── Chart Colors ──────────────────────────────────────────────────────────
  static const chartLine        = black;
  static const chartFillTop     = Color(0x1A000000); // 10% black
  static const chartFillBottom  = Color(0x00000000); // 0% black (transparent)

  // ── Adaptive Helpers ─────────────────────────────────────────────────────
  /// Returns [black] in light mode, [white] in dark mode.
  static Color adaptive(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? white : black;

  /// Returns [white] in light mode, [darkSurf] in dark mode.
  static Color cardSurface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkSurf : white;

  /// Returns [offWhite] in light mode, [darkBg] in dark mode.
  static Color scaffold(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkBg : offWhite;
}
