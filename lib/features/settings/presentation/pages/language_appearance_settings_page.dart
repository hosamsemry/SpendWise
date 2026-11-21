import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/providers/language_provider.dart';
import 'package:money_tracker/core/providers/theme_provider.dart';

import 'package:money_tracker/features/settings/presentation/widgets/settings_page_scaffold.dart';

class LanguageAppearanceSettingsPage extends ConsumerStatefulWidget {
  const LanguageAppearanceSettingsPage({super.key});

  @override
  ConsumerState<LanguageAppearanceSettingsPage> createState() =>
      _LanguageAppearanceSettingsPageState();
}

class _LanguageAppearanceSettingsPageState
    extends ConsumerState<LanguageAppearanceSettingsPage> {
  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    return SettingsPageScaffold(
      title: context.l10n.settingsLanguageAppearanceTitle,
      children: [
        // Section: Language
        Text(
          context.l10n.sectionLanguage,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: context.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.language_rounded,
                      color: context.primaryColor,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      context.l10n.currentLanguageLabel,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment<String>(
                        value: 'en',
                        label: Text('English'),
                        icon: Icon(Icons.language, size: 16),
                      ),
                      ButtonSegment<String>(
                        value: 'ar',
                        label: Text('عربي'),
                        icon: Icon(Icons.translate, size: 16),
                      ),
                    ],
                    selected: {
                      ref
                              .watch(appLanguageProvider)
                              .asData
                              ?.value
                              ?.languageCode ??
                          'en',
                    },
                    onSelectionChanged: (set) {
                      ref
                          .read(appLanguageProvider.notifier)
                          .setLanguage(set.first);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Section 3: Appearance
        Text(
          context.l10n.sectionAppearance,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: context.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.palette_outlined,
                      color: context.primaryColor,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      context.l10n.themeModeLabel,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    segments: [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text(context.l10n.themeSystem),
                        icon: const Icon(Icons.brightness_auto, size: 16),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text(context.l10n.themeLight),
                        icon: const Icon(Icons.light_mode, size: 16),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text(context.l10n.themeDark),
                        icon: const Icon(Icons.dark_mode, size: 16),
                      ),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (set) {
                      ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(set.first);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
