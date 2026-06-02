// lib/features/main_screen.dart
//
// ══════════════════════════════════════════════════════════════════════════════
// MainScreen — PageView Shell
// ══════════════════════════════════════════════════════════════════════════════
//
// This replaces the GoRouter ShellRoute from Phase 1.
// It owns a PageController for the 4 main tabs and exposes a ValueNotifier
// that child screens use to hide/show the bottom nav (Diary Zen Mode).
//
// SWIPE CONTRACT:
//   - All tabs: horizontal swipe changes tab.
//   - Diary editor (Zen Mode): physics set to NeverScrollableScrollPhysics.
//     The editor sets zenModeActive.value = true to lock the PageView.
//   - Bottom nav animates out when zenModeActive is true.
//
// This widget is placed directly in app.dart as the home: of MaterialApp,
// replacing the GoRouter configuration for the main tab flow.
// GoRouter is retained only for deep-links and notification taps.
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/asrio_colors.dart';
import '../providers/settings_provider.dart';
import 'consistency/consistency_screen.dart';
import 'diary/diary_screen.dart';
import 'home/home_screen.dart';
import 'settings/settings_screen.dart';

// ── Global Zen Mode Notifier ──────────────────────────────────────────────────
//
// A ValueNotifier rather than a Riverpod provider because it controls
// a navigation-level UI concern (the shell) and needs zero async overhead.
// Diary editor writes to it; MainScreen reads from it.
final zenModeNotifier = ValueNotifier<bool>(false);

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen>
    with TickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _navAnimController;
  late final Animation<double> _navSlideAnim;

  int _currentIndex = 0;

  // ── Tab Configuration ─────────────────────────────────────────────────────
  static const _tabs = [
    _TabDef(
      screen: HomeScreen(),
      icon: Icons.grid_view_rounded,
      outlineIcon: Icons.grid_view_outlined,
    ),
    _TabDef(
      screen: DiaryScreen(),
      icon: Icons.auto_stories_rounded,
      outlineIcon: Icons.auto_stories_outlined,
    ),
    _TabDef(
      screen: ConsistencyScreen(),
      icon: Icons.bar_chart_rounded,
      outlineIcon: Icons.bar_chart_outlined,
    ),
    _TabDef(
      screen: SettingsScreen(),
      icon: Icons.tune_rounded,
      outlineIcon: Icons.tune_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    _navAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );

    _navSlideAnim = CurvedAnimation(
      parent: _navAnimController,
      curve: Curves.easeInOutCubic,
    );

    _navAnimController.value = 1.0; // Start visible.

    // Listen to zen mode changes to animate the nav bar.
    zenModeNotifier.addListener(_onZenModeChanged);
  }

  @override
  void dispose() {
    zenModeNotifier.removeListener(_onZenModeChanged);
    _pageController.dispose();
    _navAnimController.dispose();
    super.dispose();
  }

  void _onZenModeChanged() {
    if (zenModeNotifier.value) {
      _navAnimController.reverse(); // Slide nav out.
    } else {
      _navAnimController.forward(); // Slide nav in.
    }
  }

  void _onNavTap(int index) {
    if (_currentIndex == index) return;
    HapticFeedback.selectionClick();
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
    // Persist last active tab for relaunch-auth check in DiaryScreen.
    ref.read(lastActiveTabProvider.notifier).setTab(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AsrioColors.offWhite,
      body: ValueListenableBuilder<bool>(
        valueListenable: zenModeNotifier,
        builder: (context, isZen, _) {
          return PageView(
            controller: _pageController,
            // Lock the PageView during Diary Zen Mode.
            physics: isZen
                ? const NeverScrollableScrollPhysics()
                : const _SnapPagePhysics(),
            onPageChanged: (i) {
              setState(() => _currentIndex = i);
              ref.read(lastActiveTabProvider.notifier).setTab(i);
            },
            children: _tabs.map((t) => t.screen).toList(),
          );
        },
      ),
      bottomNavigationBar: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(_navSlideAnim),
        child: _NoirBottomNav(
          currentIndex: _currentIndex,
          tabs: _tabs,
          onTap: _onNavTap,
        ),
      ),
    );
  }
}

// ── Custom Bottom Navigation ──────────────────────────────────────────────────

class _NoirBottomNav extends StatelessWidget {
  const _NoirBottomNav({
    required this.currentIndex,
    required this.tabs,
    required this.onTap,
  });

  final int currentIndex;
  final List<_TabDef> tabs;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AsrioColors.white,
        border: Border(
          top: BorderSide(color: AsrioColors.border, width: 0.8),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(tabs.length, (i) {
              final selected = i == currentIndex;
              return GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 60,
                  height: 56,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      selected ? tabs[i].icon : tabs[i].outlineIcon,
                      key: ValueKey(selected),
                      color: selected ? AsrioColors.black : AsrioColors.muted,
                      size: 24,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ── Tab Definition ────────────────────────────────────────────────────────────

class _TabDef {
  const _TabDef({
    required this.screen,
    required this.icon,
    required this.outlineIcon,
  });
  final Widget screen;
  final IconData icon;
  final IconData outlineIcon;
}

// ── Custom Page Physics ───────────────────────────────────────────────────────
// Snaps cleanly between pages with a slight resistance feel.

class _SnapPagePhysics extends PageScrollPhysics {
  const _SnapPagePhysics() : super(parent: const ClampingScrollPhysics());

  @override
  _SnapPagePhysics applyTo(ScrollPhysics? ancestor) =>
      const _SnapPagePhysics();

  @override
  SpringDescription get spring =>
      const SpringDescription(mass: 80, stiffness: 100, damping: 1);
}
