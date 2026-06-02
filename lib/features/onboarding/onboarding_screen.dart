// lib/features/onboarding/onboarding_screen.dart
//
// ══════════════════════════════════════════════════════════════════════════════
// OnboardingScreen — 3 slides, shown once on first install
// ══════════════════════════════════════════════════════════════════════════════
//
// Shown when: sharedPrefs.getBool('asrio_onboarding_done') == false
// Completed when: user taps "Let's go" on slide 3
//   → OnboardingNotifier.markDone() → navigates to MainScreen
//   → Never shown again until app is uninstalled
//
// DESIGN:
//   Pure B/W. Full-screen PageView. Bottom indicator dots.
//   Last slide has a "Let's go" black button.
//   Slides 1–2 have a subtle "Skip" text in top-right corner.
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/asrio_colors.dart';
import '../../core/theme/asrio_text_styles.dart';
import '../../providers/settings_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  static const _slides = [
    _SlideData(
      icon: Icons.grid_view_rounded,
      headline: 'Your private\nlife OS.',
      body:
          'Tasks, diary, and habits — all in one place. No cloud. No ads. No compromises.',
      isLast: false,
    ),
    _SlideData(
      icon: Icons.lock_rounded,
      headline: 'Everything stays\non your device.',
      body:
          'Your diary is encrypted with AES-256. Only you hold the key. Not even we can read it.',
      isLast: false,
    ),
    _SlideData(
      icon: Icons.local_fire_department_rounded,
      headline: "Don't break\nthe chain.",
      body:
          'Build habits one day at a time. ASRIO tracks your streak so you never lose momentum.',
      isLast: true,
    ),
  ];

  Future<void> _complete() async {
    HapticFeedback.mediumImpact();
    await ref.read(onboardingDoneProvider.notifier).markDone();
    // app.dart watches onboardingDoneProvider and rebuilds to MainScreen.
  }

  void _skip() {
    _pageController.animateToPage(
      _slides.length - 1,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AsrioColors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // ── Slides ────────────────────────────────────────────────
            PageView.builder(
              controller: _pageController,
              itemCount: _slides.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (_, i) => _SlideView(slide: _slides[i]),
            ),

            // ── Skip button (top right, hidden on last slide) ─────────
            if (_currentPage < _slides.length - 1)
              Positioned(
                top: 16,
                right: 24,
                child: GestureDetector(
                  onTap: _skip,
                  child: Text('Skip', style: AsrioText.bodyMuted),
                ),
              ),

            // ── Bottom: dots + action ─────────────────────────────────
            Positioned(
              left: 24,
              right: 24,
              bottom: 40,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Page indicator dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slides.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _currentPage ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _currentPage
                              ? AsrioColors.black
                              : AsrioColors.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Next / Let's go button
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _currentPage == _slides.length - 1
                        // Last slide — "Let's go"
                        ? SizedBox(
                            key: const ValueKey('finish'),
                            width: double.infinity,
                            child: GestureDetector(
                              onTap: _complete,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 18),
                                decoration: BoxDecoration(
                                  color: AsrioColors.black,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  "Let's go",
                                  style: AsrioText.cardTitleWhite
                                      .copyWith(fontSize: 16),
                                ),
                              ),
                            ),
                          )
                        // Slides 1–2 — "Next" arrow
                        : Align(
                            key: const ValueKey('next'),
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                _pageController.nextPage(
                                  duration:
                                      const Duration(milliseconds: 380),
                                  curve: Curves.easeInOutCubic,
                                );
                              },
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: const BoxDecoration(
                                  color: AsrioColors.black,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: AsrioColors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Slide View ────────────────────────────────────────────────────────────────

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});
  final _SlideData slide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 80, 32, 160),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon in a black circle
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AsrioColors.black,
              shape: BoxShape.circle,
            ),
            child: Icon(slide.icon, color: AsrioColors.white, size: 32),
          ),

          const SizedBox(height: 48),

          // Headline
          Text(
            slide.headline,
            style: AsrioText.greeting.copyWith(
              fontSize: 36,
              height: 1.15,
              letterSpacing: -1,
            ),
          ),

          const SizedBox(height: 20),

          // Body
          Text(
            slide.body,
            style: AsrioText.body.copyWith(
              color: AsrioColors.secondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _SlideData {
  const _SlideData({
    required this.icon,
    required this.headline,
    required this.body,
    required this.isLast,
  });
  final IconData icon;
  final String headline;
  final String body;
  final bool isLast;
}
