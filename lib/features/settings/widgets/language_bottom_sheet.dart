// lib/features/settings/widgets/language_bottom_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations_delegate.dart';
import '../../../core/theme/asrio_colors.dart';
import '../../../core/theme/asrio_text_styles.dart';
import '../../../providers/settings_provider.dart';

void showLanguageSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _LanguageSheet(),
  );
}

// Display names for all 22 supported locales.
const _localeNames = {
  'en': 'English',
  'de': 'Deutsch',
  'fr': 'Français',
  'es': 'Español',
  'it': 'Italiano',
  'pt': 'Português',
  'hu': 'Magyar',
  'ro': 'Română',
  'tr': 'Türkçe',
  'ru': 'Русский',
  'uk': 'Українська',
  'zh': '中文',
  'ja': '日本語',
  'ko': '한국어',
  'vi': 'Tiếng Việt',
  'ar': 'العربية',
  'id': 'Bahasa Indonesia',
  'th': 'ภาษาไทย',
  'hi': 'हिन्दी',
  'nl': 'Nederlands',
  'pl': 'Polski',
  'sv': 'Svenska',
};

class _LanguageSheet extends ConsumerWidget {
  const _LanguageSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(localeCodeProvider);
    final locales = AsrioLocalizationsDelegate.supportedLocales;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AsrioColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Handle + header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 36, height: 3,
                    decoration: BoxDecoration(
                      color: AsrioColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Language', style: AsrioText.cardTitle),
                    Text(
                      '${locales.length} languages',
                      style: AsrioText.bodyMuted,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          const Divider(color: AsrioColors.border, height: 1),

          // Locale list
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: locales.length,
              separatorBuilder: (_, __) => const Divider(
                  color: AsrioColors.border,
                  height: 1,
                  indent: 20,
                  endIndent: 20),
              itemBuilder: (context, i) {
                final code     = locales[i].languageCode;
                final name     = _localeNames[code] ?? code;
                final selected = code == current;

                return InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref
                        .read(localeCodeProvider.notifier)
                        .setLocale(code);
                    Navigator.pop(context);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                  style: selected
                                      ? AsrioText.taskTitle.copyWith(
                                          fontWeight: FontWeight.w700)
                                      : AsrioText.taskTitle),
                              Text(code.toUpperCase(),
                                  style: AsrioText.caption),
                            ],
                          ),
                        ),
                        // Selected checkmark
                        AnimatedOpacity(
                          opacity: selected ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            width: 24, height: 24,
                            decoration: const BoxDecoration(
                              color: AsrioColors.black,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_rounded,
                                size: 14, color: AsrioColors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
