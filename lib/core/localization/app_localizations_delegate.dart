// lib/core/localization/app_localizations_delegate.dart
//
// This file is the bridge between Flutter's localization framework and the
// existing static AppLocalizations class from the spec.
//
// Flutter's localization system works through [LocalizationsDelegate].
// MaterialApp requires at least one delegate in its 'localizationsDelegates'
// list to know how to build locale-aware objects.
//
// Our AppLocalizations is a static class (no instance needed) so this delegate
// is very thin — its main job is telling Flutter which locales we support.

import 'package:flutter/material.dart';

/// Bridges Flutter's [LocalizationsDelegate] system with ASRIO's static
/// [AppLocalizations] translation map.
///
/// Because [AppLocalizations] uses static methods (no instantiation needed),
/// the 'load' step is a no-op — we just return 'this'.
class AsrioLocalizationsDelegate
    extends LocalizationsDelegate<AsrioLocalizationsDelegate> {
  const AsrioLocalizationsDelegate();

  /// The complete list of language codes ASRIO supports.
  /// This must stay in sync with the keys in AppLocalizations._values.
  ///
  /// Flutter uses this list to find the best available locale when the
  /// device's locale is something we don't explicitly support (e.g., 'en-GB'
  /// falls back to 'en').
  static const List<Locale> supportedLocales = [
    Locale('en'), // English  — fallback language, must always be first.
    Locale('de'), // German
    Locale('fr'), // French
    Locale('es'), // Spanish
    Locale('it'), // Italian
    Locale('pt'), // Portuguese
    Locale('hu'), // Hungarian
    Locale('ro'), // Romanian
    Locale('tr'), // Turkish
    Locale('ru'), // Russian
    Locale('uk'), // Ukrainian
    Locale('zh'), // Chinese (Simplified)
    Locale('ja'), // Japanese
    Locale('ko'), // Korean
    Locale('vi'), // Vietnamese
    Locale('ar'), // Arabic
    Locale('id'), // Indonesian
    Locale('th'), // Thai
    Locale('hi'), // Hindi
    Locale('nl'), // Dutch
    Locale('pl'), // Polish
    Locale('sv'), // Swedish
  ];

  @override
  bool isSupported(Locale locale) {
    return supportedLocales
        .map((l) => l.languageCode)
        .contains(locale.languageCode);
  }

  @override
  Future<AsrioLocalizationsDelegate> load(Locale locale) async {
    // Our translations are a static map — no async loading needed.
    // Just return this delegate instance as the "loaded" object.
    return this;
  }

  @override
  bool shouldReload(AsrioLocalizationsDelegate old) {
    // Return false: our translation map is compile-time constant.
    // Returning true would force a rebuild on every locale change,
    // which is unnecessary and slightly wasteful.
    return false;
  }
}
