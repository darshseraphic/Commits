// lib/core/router/app_router.dart
//
// ══════════════════════════════════════════════════════════════════════════════
// ASRIO Router — GoRouter with ShellRoute
// ══════════════════════════════════════════════════════════════════════════════
//
// WHY ShellRoute?
//
// The 5 tabs share a persistent BottomNavigationBar. Without ShellRoute,
// navigating between tabs would rebuild the Scaffold (and the navbar) on every
// switch. ShellRoute keeps the shell (Scaffold + navbar) alive while only
// swapping the 'child' content area.
//
// WHY NoTransitionPage for tab switches?
//
// Standard tab navigation in iOS and Android has NO transition animation —
// tabs switch instantly. Hero animations and slide transitions are for pushing
// to a new destination (like opening a diary entry). We match the platform
// convention here: instant for tabs, animated for pushes.
//
// ROUTE NAMING:
// All route paths are constants in AppRoutes. Never write '/diary' as a string
// inside a widget — use AppRoutes.diary. One typo in a route string causes a
// silent navigation failure at runtime that's hard to trace.
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/consistency/consistency_screen.dart';
import '../../features/diary/diary_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/todo/todo_screen.dart';

// ── Route Constants ───────────────────────────────────────────────────────────

/// All route paths as constants.
/// Import this class wherever you need to navigate — never hardcode strings.
abstract final class AppRoutes {
  static const home        = '/';
  static const todo        = '/todo';
  static const diary       = '/diary';
  static const consistency = '/consistency';
  static const settings    = '/settings';
}

// ── Tab Configuration ─────────────────────────────────────────────────────────

/// Defines the metadata for each bottom nav tab in a single, ordered list.
/// The order here determines the order in the navbar.
const _tabs = [
  _TabItem(
    label: 'Home',
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
    route: AppRoutes.home,
  ),
  _TabItem(
    label: 'Tasks',
    icon: Icons.check_circle_outline_rounded,
    activeIcon: Icons.check_circle_rounded,
    route: AppRoutes.todo,
  ),
  _TabItem(
    label: 'Diary',
    icon: Icons.menu_book_outlined,
    activeIcon: Icons.menu_book_rounded,
    route: AppRoutes.diary,
  ),
  _TabItem(
    label: 'Consistency',
    icon: Icons.bar_chart_outlined,
    activeIcon: Icons.bar_chart_rounded,
    route: AppRoutes.consistency,
  ),
  _TabItem(
    label: 'Settings',
    icon: Icons.settings_outlined,
    activeIcon: Icons.settings_rounded,
    route: AppRoutes.settings,
  ),
];

class _TabItem {
  const _TabItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.route,
  });
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;
}

// ── Router Provider ───────────────────────────────────────────────────────────

/// The [GoRouter] instance, provided as a Riverpod provider.
///
/// Using a provider (rather than a global variable) means:
///   - The router can be overridden in tests.
///   - It integrates cleanly with the Riverpod dependency graph.
///   - It can access other providers if needed (e.g., for auth guards in future).
final appRouterProvider = Provider<GoRouter>(
  (ref) => GoRouter(
    initialLocation: AppRoutes.home,
    // Only log in debug mode. Router logs every navigation event.
    debugLogDiagnostics: true,
    routes: [
      // ── Shell Route ─────────────────────────────────────────────────────
      // All 5 tabs are children of this shell. The shell renders the
      // Scaffold + BottomNavigationBar. The 'child' argument is the
      // currently active tab's screen.
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: HomeScreen()),
          ),
          GoRoute(
            path: AppRoutes.todo,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: TodoScreen()),
          ),
          GoRoute(
            path: AppRoutes.diary,
            // Phase 4: Replace with a custom book-open page transition.
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: DiaryScreen()),
          ),
          GoRoute(
            path: AppRoutes.consistency,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: ConsistencyScreen()),
          ),
          GoRoute(
            path: AppRoutes.settings,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: SettingsScreen()),
          ),
        ],
      ),
    ],
  ),
  name: 'appRouterProvider',
);

// ── App Shell ─────────────────────────────────────────────────────────────────

/// The persistent shell widget: [Scaffold] + [NavigationBar].
///
/// This widget stays alive across all tab switches. Only the [child] changes.
///
/// IMPORTANT: The diary screen hides the navbar via a [ValueNotifier] that
/// this shell will listen to in Phase 4. The hiding animation is owned here,
/// not inside DiaryScreen, to keep the diary decoupled from the shell's layout.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Determine the current selected index by matching the active route
    // against our tab list. Falls back to 0 (Home) if no match found.
    final location = GoRouterState.of(context).uri.path;
    final currentIndex = _resolveTabIndex(location);

    return Scaffold(
      // The body is the active tab's screen, provided by ShellRoute.
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        animationDuration: const Duration(milliseconds: 300),
        onDestinationSelected: (index) {
          // context.go() replaces the current route (no back stack buildup).
          // This is correct for tab navigation — tabs don't stack.
          context.go(_tabs[index].route);
        },
        destinations: _tabs.map((tab) {
          return NavigationDestination(
            icon: Icon(tab.icon),
            selectedIcon: Icon(tab.activeIcon),
            label: tab.label,
          );
        }).toList(),
      ),
    );
  }

  /// Resolves the active tab index from the current route path.
  ///
  /// The home route '/' is special — startsWith('/') would match everything,
  /// so we check for exact equality for the root route.
  static int _resolveTabIndex(String path) {
    for (int i = 0; i < _tabs.length; i++) {
      final route = _tabs[i].route;
      if (route == AppRoutes.home) {
        if (path == AppRoutes.home) return i;
      } else if (path.startsWith(route)) {
        return i;
      }
    }
    return 0; // Default to Home.
  }
}
