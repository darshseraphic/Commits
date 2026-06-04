// lib/providers/settings_provider.dart
//
// ══════════════════════════════════════════════════════════════════════════════
// Settings Providers — Theme & Locale
// ══════════════════════════════════════════════════════════════════════════════
//
// These two providers form the reactive backbone of app-level preferences.
// Both patterns follow the same architecture:
//
//   SharedPreferences (disk) → StateNotifier (RAM) → MaterialApp (UI)
//
// Writing a preference triggers: StateNotifier.state update → MaterialApp rebuilds.
// Reading a preference on startup: SharedPreferences.getInstance() → initial state.
//
// WHY StateNotifier and not StateProvider?
// StateNotifier encapsulates the mutation logic (the setTheme/setLocale methods)
// inside the notifier class. This means no widget can directly mutate state —
// they must go through the typed API. Safer and easier to test.
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Keys ────────────────────────────────────────────────────────────────────
// Prefixed with 'asrio_' to avoid collisions if the package is ever combined
// with other libraries that use SharedPreferences.
const _kThemeKey = 'asrio_theme_mode';
const _kLocaleKey = 'asrio_locale_code';

// ── SharedPreferences Bootstrap ──────────────────────────────────────────────

/// Loads [SharedPreferences] once at startup.
///
/// Using [FutureProvider] means Riverpod handles the async loading state.
/// Dependent providers use [maybeWhen] to gracefully handle the loading state
/// by falling back to default values rather than blocking the UI.
final sharedPreferencesProvider = FutureProvider<SharedPreferences>(
  (ref) async => SharedPreferences.getInstance(),
  name: 'sharedPreferencesProvider',
);

// ── Theme ────────────────────────────────────────────────────────────────────

/// Exposes the current [ThemeMode] to the widget tree.
///
/// Usage in a widget:
///   final mode = ref.watch(themeModeProvider);
///
/// Usage in Settings to change the theme:
///   ref.read(themeModeProvider.notifier).setTheme(ThemeMode.dark);
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) {
    // Synchronously read SharedPreferences from the FutureProvider's cache.
    // If prefs haven't loaded yet (first frame), we get null and use the default.
    final prefs = ref.watch(sharedPreferencesProvider).maybeWhen(
          data: (p) => p,
          orElse: () => null,
        );
    return ThemeModeNotifier(prefs);
  },
  name: 'themeModeProvider',
);

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(this._prefs) : super(_readFromDisk(_prefs));

  final SharedPreferences? _prefs;

  /// Reads the persisted theme from disk, falling back to [ThemeMode.system].
  ///
  /// ThemeMode.system is the safest default — it respects the user's OS preference
  /// without imposing a choice they haven't made yet.
  static ThemeMode _readFromDisk(SharedPreferences? prefs) {
    return switch (prefs?.getString(_kThemeKey)) {
      'light'  => ThemeMode.light,
      'dark'   => ThemeMode.dark,
      'system' => ThemeMode.system,
      _        => ThemeMode.system, // Default for null / unknown values.
    };
  }

  /// Changes the active theme and persists the choice immediately.
  Future<void> setTheme(ThemeMode mode) async {
    state = mode; // Triggers immediate UI update.
    await _prefs?.setString(_kThemeKey, mode.name);
  }
}

// ── Locale ───────────────────────────────────────────────────────────────────

/// Exposes the current locale code (e.g., 'en', 'ar', 'ja') to the widget tree.
///
/// Usage in a widget to read the current language for AppLocalizations:
///   final code = ref.watch(localeCodeProvider);
///   final label = AppLocalizations.text(code, 'settings');
///
/// Usage in Settings to change language:
///   ref.read(localeCodeProvider.notifier).setLocale('de');
final localeCodeProvider = StateNotifierProvider<LocaleNotifier, String>(
  (ref) {
    final prefs = ref.watch(sharedPreferencesProvider).maybeWhen(
          data: (p) => p,
          orElse: () => null,
        );
    return LocaleNotifier(prefs);
  },
  name: 'localeCodeProvider',
);

class LocaleNotifier extends StateNotifier<String> {
  LocaleNotifier(this._prefs) : super(_readFromDisk(_prefs));

  final SharedPreferences? _prefs;

  static String _readFromDisk(SharedPreferences? prefs) {
    // Default to 'en'. This is the only language guaranteed to have
    // a complete translation map in AppLocalizations.
    return prefs?.getString(_kLocaleKey) ?? 'en';
  }

  /// Changes the active locale and persists the choice immediately.
  ///
  /// The [code] must be one of the language codes in
  /// [AsrioLocalizationsDelegate.supportedLocales], e.g., 'en', 'de', 'ar'.
  Future<void> setLocale(String code) async {
    state = code;
    await _prefs?.setString(_kLocaleKey, code);
  }
}

// ── Diary Lock ────────────────────────────────────────────────────────────────
//
// Controls whether biometric authentication is required to open diary entries.
// Default: false — the user opts in consciously from Settings.
//
// Architecture: identical to ThemeModeNotifier / LocaleNotifier.
// The toggle in SettingsScreen writes here; DiaryScreen reads here.

const _kDiaryLockKey = 'asrio_diary_lock_enabled';

/// Whether the Diary Lock (biometric gate) is active.
///
/// Read by DiaryScreen before opening any entry.
/// Written by the Settings toggle after a successful test-auth.
final diaryLockEnabledProvider =
    StateNotifierProvider<DiaryLockNotifier, bool>(
  (ref) {
    final prefs = ref.watch(sharedPreferencesProvider).maybeWhen(
          data: (p) => p,
          orElse: () => null,
        );
    return DiaryLockNotifier(prefs);
  },
  name: 'diaryLockEnabledProvider',
);

class DiaryLockNotifier extends StateNotifier<bool> {
  DiaryLockNotifier(this._prefs)
      : super(_prefs?.getBool(_kDiaryLockKey) ?? false);

  final SharedPreferences? _prefs;

  /// Enables diary lock. Should only be called after a successful test-auth
  /// in the Settings screen to ensure the device actually supports biometrics.
  Future<void> enable() async {
    state = true;
    await _prefs?.setBool(_kDiaryLockKey, true);
  }

  /// Disables diary lock. No auth required to disable — the user is already
  /// authenticated by virtue of having the phone unlocked.
  Future<void> disable() async {
    state = false;
    await _prefs?.setBool(_kDiaryLockKey, false);
  }
}

// ── Last Active Tab ───────────────────────────────────────────────────────────
//
// Persisted so on relaunch we can detect if the diary was the last screen.
// Written by MainScreen on every page change.
// Read by DiaryScreen on initState to decide if relaunch-auth is needed.

const _kLastTabKey = 'asrio_last_tab_index';
const kDiaryTabIndex = 2; // Must match the tab order in main_screen.dart.

final lastActiveTabProvider =
    StateNotifierProvider<LastTabNotifier, int>(
  (ref) {
    final prefs = ref.watch(sharedPreferencesProvider).maybeWhen(
          data: (p) => p,
          orElse: () => null,
        );
    return LastTabNotifier(prefs);
  },
  name: 'lastActiveTabProvider',
);

class LastTabNotifier extends StateNotifier<int> {
  LastTabNotifier(this._prefs)
      : super(_prefs?.getInt(_kLastTabKey) ?? 0);

  final SharedPreferences? _prefs;

  Future<void> setTab(int index) async {
    state = index;
    await _prefs?.setInt(_kLastTabKey, index);
  }
}

// ── Onboarding ────────────────────────────────────────────────────────────────
//
// Written to true only when the user completes the full 3-slide onboarding.
// Never resets unless the app is uninstalled (SharedPreferences is cleared).

const _kOnboardingKey = 'asrio_onboarding_done';

final onboardingDoneProvider = StateNotifierProvider<OnboardingNotifier, bool>(
  (ref) {
    final prefs = ref.watch(sharedPreferencesProvider).maybeWhen(
          data: (p) => p,
          orElse: () => null,
        );
    return OnboardingNotifier(prefs);
  },
  name: 'onboardingDoneProvider',
);

class OnboardingNotifier extends StateNotifier<bool> {
  OnboardingNotifier(this._prefs)
      : super(_prefs?.getBool(_kOnboardingKey) ?? false);

  final SharedPreferences? _prefs;

  Future<void> markDone() async {
    state = true;
    await _prefs?.setBool(_kOnboardingKey, true);
  }

  /// Resets onboarding — used by wipe data so user sees it on next launch.
  Future<void> disable() async {
    state = false;
    await _prefs?.setBool(_kOnboardingKey, false);
  }
}

// ── Notification Settings ─────────────────────────────────────────────────────

const _kDiaryReminderEnabled  = 'asrio_diary_reminder_enabled';
const _kDiaryReminderHour     = 'asrio_diary_reminder_hour';
const _kDiaryReminderMinute   = 'asrio_diary_reminder_minute';
const _kTaskReminderEnabled   = 'asrio_task_reminder_enabled';
const _kTaskReminderHour      = 'asrio_task_reminder_hour';
const _kTaskReminderMinute    = 'asrio_task_reminder_minute';

/// Whether the daily diary reminder notification is enabled.
final diaryReminderEnabledProvider =
    StateNotifierProvider<_BoolPrefNotifier, bool>(
  (ref) {
    final prefs = ref.watch(sharedPreferencesProvider).maybeWhen(
          data: (p) => p, orElse: () => null);
    return _BoolPrefNotifier(prefs, _kDiaryReminderEnabled, defaultValue: false);
  },
  name: 'diaryReminderEnabledProvider',
);

/// The hour component of the daily diary reminder time.
final diaryReminderHourProvider =
    StateNotifierProvider<_IntPrefNotifier, int>(
  (ref) {
    final prefs = ref.watch(sharedPreferencesProvider).maybeWhen(
          data: (p) => p, orElse: () => null);
    return _IntPrefNotifier(prefs, _kDiaryReminderHour, defaultValue: 21);
  },
  name: 'diaryReminderHourProvider',
);

/// The minute component of the daily diary reminder time.
final diaryReminderMinuteProvider =
    StateNotifierProvider<_IntPrefNotifier, int>(
  (ref) {
    final prefs = ref.watch(sharedPreferencesProvider).maybeWhen(
          data: (p) => p, orElse: () => null);
    return _IntPrefNotifier(prefs, _kDiaryReminderMinute, defaultValue: 0);
  },
  name: 'diaryReminderMinuteProvider',
);

/// Whether task reminders are enabled globally.
final taskReminderEnabledProvider =
    StateNotifierProvider<_BoolPrefNotifier, bool>(
  (ref) {
    final prefs = ref.watch(sharedPreferencesProvider).maybeWhen(
          data: (p) => p, orElse: () => null);
    return _BoolPrefNotifier(prefs, _kTaskReminderEnabled, defaultValue: true);
  },
  name: 'taskReminderEnabledProvider',
);

// ── Generic Pref Notifiers (internal helpers) ─────────────────────────────────

class _BoolPrefNotifier extends StateNotifier<bool> {
  _BoolPrefNotifier(this._prefs, this._key, {required bool defaultValue})
      : super(_prefs?.getBool(_key) ?? defaultValue);
  final SharedPreferences? _prefs;
  final String _key;

  Future<void> set(bool value) async {
    state = value;
    await _prefs?.setBool(_key, value);
  }
}

class _IntPrefNotifier extends StateNotifier<int> {
  _IntPrefNotifier(this._prefs, this._key, {required int defaultValue})
      : super(_prefs?.getInt(_key) ?? defaultValue);
  final SharedPreferences? _prefs;
  final String _key;

  Future<void> set(int value) async {
    state = value;
    await _prefs?.setInt(_key, value);
  }
}
