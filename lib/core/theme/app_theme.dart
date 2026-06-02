// lib/core/theme/app_theme.dart
//
// ══════════════════════════════════════════════════════════════════════════════
// ASRIO Design System — Theme Tokens
// ══════════════════════════════════════════════════════════════════════════════
//
// ARCHITECTURE RULE: Every color, spacing, and typography decision in ASRIO
// must trace back to a token defined in this file.
//
// Widgets NEVER hardcode colors like Color(0xFF6C63FF) or Colors.purple.
// They use Theme.of(context).colorScheme.primary or a custom extension.
//
// When the designer changes the brand color, it changes in ONE place — here.
//
// The class is 'abstract final' which means:
//   - abstract: cannot be instantiated (it's a namespace, not an object).
//   - final: cannot be extended or mixed into other classes.
// This is the modern Dart pattern for utility/token classes.
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

abstract final class AppTheme {
  // ── Brand Palette ─────────────────────────────────────────────────────────
  //
  // These are the ONLY hardcoded hex values allowed in the codebase.
  // Everything else flows from these tokens through ColorScheme.fromSeed().

  /// Primary brand color. Appears on FABs, selected nav items, active states.
  static const _brandPrimary     = Color(0xFF6C63FF);
  /// Lighter variant for dark surfaces — primary was too dark on near-black bg.
  static const _brandPrimaryDark = Color(0xFF9D97FF);
  /// Warm error/danger tone — slightly softer than Material's default red.
  static const _error            = Color(0xFFCF6679);

  // ── Surface Colors ────────────────────────────────────────────────────────
  static const _surfaceLight = Color(0xFFF7F7F9); // Slightly warm white.
  static const _surfaceDark  = Color(0xFF1C1C1E); // iOS-style near-black.
  static const _cardDark     = Color(0xFF2C2C2E); // One step lighter for cards.

  // ── Font Family ───────────────────────────────────────────────────────────
  // DM Sans is declared in pubspec.yaml.
  // The diary handwriting font (Caveat or similar) will be added in Phase 4.
  static const _fontFamily = 'DM Sans';

  // ── Text Themes ───────────────────────────────────────────────────────────
  //
  // We define only the styles our app actively uses. Flutter's Material 3
  // fills in the rest automatically from ColorScheme.fromSeed().

  static TextTheme _textTheme(Color primary, Color secondary) => TextTheme(
        // Used for screen titles and large headings.
        displayLarge: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: primary,
          letterSpacing: -0.5,
        ),
        // Used for section headers inside cards.
        titleLarge: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: primary,
        ),
        // Used for card titles and tab labels.
        titleMedium: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: primary,
        ),
        // Primary reading text.
        bodyLarge: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: primary,
          height: 1.5,
        ),
        // Secondary content, descriptions, hints.
        bodyMedium: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: secondary,
          height: 1.4,
        ),
        // Buttons, chips, labels.
        labelLarge: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: primary,
          letterSpacing: 0.1,
        ),
        // Caption text, timestamps, metadata.
        labelSmall: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: secondary,
          letterSpacing: 0.5,
        ),
      );

  // ── Shared Shape ──────────────────────────────────────────────────────────
  // All interactive surfaces (cards, sheets, dialogs) use 16px rounding.
  static const _defaultRadius = BorderRadius.all(Radius.circular(16));
  static const _cardShape = RoundedRectangleBorder(borderRadius: _defaultRadius);

  // ── Light Theme ───────────────────────────────────────────────────────────

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        fontFamily: _fontFamily,

        colorScheme: ColorScheme.fromSeed(
          seedColor: _brandPrimary,
          brightness: Brightness.light,
          surface: _surfaceLight,
          error: _error,
        ),

        scaffoldBackgroundColor: _surfaceLight,

        textTheme: _textTheme(
          const Color(0xFF1C1C1E), // Primary text: near-black.
          const Color(0xFF6E6E73), // Secondary text: medium gray.
        ),

        // ── Navigation Bar ────────────────────────────────────────────────
        // The bottom nav is one of the most visible design surfaces.
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          indicatorColor: _brandPrimary.withAlpha(26), // 10% opacity pill.
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontFamily: _fontFamily,
              fontSize: 11,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? _brandPrimary : const Color(0xFF6E6E73),
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              color: selected ? _brandPrimary : const Color(0xFF6E6E73),
              size: 24,
            );
          }),
        ),

        // ── AppBar ────────────────────────────────────────────────────────
        appBarTheme: const AppBarTheme(
          backgroundColor: _surfaceLight,
          foregroundColor: Color(0xFF1C1C1E),
          elevation: 0,
          scrolledUnderElevation: 0.5,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: _fontFamily,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1C1C1E),
          ),
        ),

        // ── Cards ─────────────────────────────────────────────────────────
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: _cardShape,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        ),

        // ── Input Fields ──────────────────────────────────────────────────
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF0F0F5),
          border: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: _brandPrimary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),

        // ── Floating Action Button ────────────────────────────────────────
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: _brandPrimary,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      );

  // ── Dark Theme ────────────────────────────────────────────────────────────

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: _fontFamily,

        colorScheme: ColorScheme.fromSeed(
          seedColor: _brandPrimaryDark,
          brightness: Brightness.dark,
          surface: _surfaceDark,
          error: _error,
        ),

        scaffoldBackgroundColor: _surfaceDark,

        textTheme: _textTheme(
          const Color(0xFFF5F5F7), // Primary text: near-white.
          const Color(0xFF8E8E93), // Secondary text: muted gray.
        ),

        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: _cardDark,
          elevation: 0,
          shadowColor: Colors.transparent,
          indicatorColor: _brandPrimaryDark.withAlpha(51), // 20% opacity pill.
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontFamily: _fontFamily,
              fontSize: 11,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? _brandPrimaryDark : const Color(0xFF8E8E93),
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              color: selected ? _brandPrimaryDark : const Color(0xFF8E8E93),
              size: 24,
            );
          }),
        ),

        appBarTheme: const AppBarTheme(
          backgroundColor: _surfaceDark,
          foregroundColor: Color(0xFFF5F5F7),
          elevation: 0,
          scrolledUnderElevation: 0.5,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: _fontFamily,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Color(0xFFF5F5F7),
          ),
        ),

        cardTheme: CardThemeData(
          elevation: 0,
          color: _cardDark,
          surfaceTintColor: Colors.transparent,
          shape: _cardShape,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF3A3A3C),
          border: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: _brandPrimaryDark, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),

        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: _brandPrimaryDark,
          foregroundColor: _surfaceDark,
          elevation: 2,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      );
}
