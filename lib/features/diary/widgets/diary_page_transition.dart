// lib/features/diary/widgets/diary_page_transition.dart
//
// ══════════════════════════════════════════════════════════════════════════════
// DiaryPageTransition — Custom Route Builder
// ══════════════════════════════════════════════════════════════════════════════
//
// Produces the "book open" feel without skeuomorphic page-curl effects.
// Pure Flutter: Hero tag on the date, custom route with two layers:
//
//   Layer 1 — Outgoing (list view):
//     Scales down from 1.0 → 0.97 and fades slightly (dark overlay 0→0.15).
//     Feels like the list "recedes" as the new page rises.
//
//   Layer 2 — Incoming (editor):
//     Slides from Offset(0, 0.04) → Offset.zero with a fade-in.
//     Subtle vertical nudge feels like a page lifting from a table.
//
// Duration: 380ms with easeInOutCubic.
//
// The Hero widget is applied externally on the date text in the list row
// and matched in the editor header. Flutter automatically interpolates
// the text style, size, and position between the two endpoints.
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

/// A lightweight custom [PageRoute] that produces the book-open transition.
///
/// Usage:
///   Navigator.of(context).push(
///     DiaryPageRoute(builder: (_) => _DiaryEditor(...)),
///   );
///
/// The list view DOES NOT use Navigator — the AnimatedSwitcher approach
/// in diary_screen.dart handles it. This route is available for future
/// full-screen push navigation if the architecture changes.
class DiaryPageRoute<T> extends PageRouteBuilder<T> {
  DiaryPageRoute({required WidgetBuilder builder})
      : super(
          transitionDuration: const Duration(milliseconds: 380),
          reverseTransitionDuration: const Duration(milliseconds: 320),
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: _buildTransition,
        );

  static Widget _buildTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Incoming editor: slight vertical slide + fade
    final slideIn = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeInOutCubic,
    ));

    final fadeIn = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );

    return FadeTransition(
      opacity: fadeIn,
      child: SlideTransition(position: slideIn, child: child),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DiaryListTransition
//
// Applied to the AnimatedSwitcher in DiaryScreen.
// Wraps the outgoing list view to scale + darken as the editor comes in.
// ══════════════════════════════════════════════════════════════════════════════

/// Applied as the [AnimatedSwitcher.transitionBuilder] on [DiaryScreen].
///
/// [isEntering] should be true when [child] is the incoming widget.
Widget diaryScreenTransitionBuilder(Widget child, Animation<double> anim) {
  // Determine direction from the child's key.
  final isEditor = child.key == const ValueKey('editor');

  if (isEditor) {
    // Incoming editor: slide from right + fade.
    final slide = Tween<Offset>(
      begin: const Offset(0.06, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: anim, curve: Curves.easeInOutCubic));

    final fade = CurvedAnimation(
      parent: anim,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    return FadeTransition(opacity: fade, child: SlideTransition(position: slide, child: child));
  } else {
    // Outgoing list: scale down slightly + dark overlay.
    final scale = Tween<double>(begin: 0.97, end: 1.0)
        .animate(CurvedAnimation(parent: anim, curve: Curves.easeInOutCubic));

    final overlayOpacity = Tween<double>(begin: 0.08, end: 0.0)
        .animate(CurvedAnimation(parent: anim, curve: Curves.easeIn));

    return ScaleTransition(
      scale: scale,
      child: Stack(
        children: [
          child,
          // Dark overlay that fades in as list scales down.
          AnimatedBuilder(
            animation: overlayOpacity,
            builder: (_, __) => Opacity(
              opacity: overlayOpacity.value,
              child: Container(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// HeroDateTag
//
// The Hero tag string for a diary entry date. Ensures uniqueness per date.
// ══════════════════════════════════════════════════════════════════════════════

String heroDateTag(DateTime date) =>
    'diary_date_${date.year}_${date.month}_${date.day}';
