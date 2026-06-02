// lib/app.dart — Phase 6 (onboarding gate added)

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/localization/app_localizations_delegate.dart';
import 'core/theme/app_theme.dart';
import 'features/main_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'providers/settings_provider.dart';

class AsrioApp extends ConsumerWidget {
  const AsrioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode      = ref.watch(themeModeProvider);
    final localeCode     = ref.watch(localeCodeProvider);
    final onboardingDone = ref.watch(onboardingDoneProvider);

    return MaterialApp(
      title: 'ASRIO',
      debugShowCheckedModeBanner: false,

      themeMode: themeMode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),

      locale: Locale(localeCode),
      supportedLocales: AsrioLocalizationsDelegate.supportedLocales,
      localizationsDelegates: const [
        AsrioLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // ── Onboarding Gate ────────────────────────────────────────────────
      // onboardingDone is read from SharedPreferences in settings_provider.
      // If false → show OnboardingScreen (first install or after wipe).
      // If true  → go straight to MainScreen (every subsequent launch).
      //
      // The gate is reactive: when OnboardingNotifier.markDone() is called
      // at the end of onboarding, this widget rebuilds automatically and
      // navigates to MainScreen without any explicit navigation call.
      home: onboardingDone ? const MainScreen() : const OnboardingScreen(),
    );
  }
}
