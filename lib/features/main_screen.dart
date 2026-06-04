// lib/features/main_screen.dart — Phase 7 fix
// 5 tabs, smooth animated transitions, minimalist icons, no emojis

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/asrio_colors.dart';
import '../core/theme/asrio_text_styles.dart';
import '../providers/settings_provider.dart';
import 'consistency/consistency_screen.dart';
import 'diary/diary_screen.dart';
import 'home/home_screen.dart';
import 'settings/settings_screen.dart';
import 'todo/todo_screen.dart';

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

  static const _tabs = [
    _TabDef(screen: HomeScreen(),        icon: Icons.home_outlined,              activeIcon: Icons.home_rounded),
    _TabDef(screen: TodoScreen(),        icon: Icons.check_box_outline_blank,    activeIcon: Icons.check_box_rounded),
    _TabDef(screen: DiaryScreen(),       icon: Icons.chrome_reader_mode_outlined,activeIcon: Icons.chrome_reader_mode_rounded),
    _TabDef(screen: ConsistencyScreen(), icon: Icons.show_chart,                 activeIcon: Icons.show_chart),
    _TabDef(screen: SettingsScreen(),    icon: Icons.settings_outlined,          activeIcon: Icons.settings_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _navAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _navSlideAnim = CurvedAnimation(
        parent: _navAnimController, curve: Curves.easeInOutCubic);
    _navAnimController.value = 1.0;
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
      _navAnimController.reverse();
    } else {
      _navAnimController.forward();
    }
  }

  void _onNavTap(int index) {
    if (_currentIndex == index) return;
    HapticFeedback.selectionClick();
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
    ref.read(lastActiveTabProvider.notifier).setTab(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AsrioColors.offWhite,
      body: ValueListenableBuilder<bool>(
        valueListenable: zenModeNotifier,
        builder: (_, isZen, __) => PageView(
          controller: _pageController,
          physics: isZen
              ? const NeverScrollableScrollPhysics()
              : const PageScrollPhysics(),
          onPageChanged: (i) {
            setState(() => _currentIndex = i);
            ref.read(lastActiveTabProvider.notifier).setTab(i);
          },
          children: _tabs.map((t) => t.screen).toList(),
        ),
      ),
      bottomNavigationBar: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1), end: Offset.zero,
        ).animate(_navSlideAnim),
        child: _NoirNav(
          currentIndex: _currentIndex,
          tabs: _tabs,
          onTap: _onNavTap,
        ),
      ),
    );
  }
}

class _NoirNav extends StatelessWidget {
  const _NoirNav({
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
        border: Border(top: BorderSide(color: AsrioColors.border, width: 0.8)),
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
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        selected ? tabs[i].activeIcon : tabs[i].icon,
                        key: ValueKey(selected),
                        color: selected
                            ? AsrioColors.black
                            : AsrioColors.muted,
                        size: 22,
                      ),
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

class _TabDef {
  const _TabDef({
    required this.screen,
    required this.icon,
    required this.activeIcon,
  });
  final Widget screen;
  final IconData icon;
  final IconData activeIcon;
}
