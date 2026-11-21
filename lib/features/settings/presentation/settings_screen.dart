import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/providers/currency_provider.dart';
import 'package:money_tracker/core/providers/cycle_providers.dart';
import 'package:money_tracker/core/providers/reminder_provider.dart';
import 'package:money_tracker/core/providers/theme_provider.dart';
import 'package:money_tracker/features/settings/presentation/settings_providers.dart';
import 'package:money_tracker/features/smart_detection/presentation/smart_detection_providers.dart';
import 'package:money_tracker/features/presets/presentation/presets_management_screen.dart';
import 'package:money_tracker/features/settings/presentation/pages/backup_export_settings_page.dart';
import 'package:money_tracker/features/settings/presentation/pages/budget_money_settings_page.dart';
import 'package:money_tracker/features/settings/presentation/pages/language_appearance_settings_page.dart';
import 'package:money_tracker/features/settings/presentation/pages/reminders_settings_page.dart';
import 'package:money_tracker/features/settings/presentation/pages/security_settings_page.dart';
import 'package:money_tracker/features/settings/presentation/pages/smart_detection_settings_page.dart';
import 'package:money_tracker/features/settings/presentation/widgets/settings_nav_tile.dart';
import 'package:money_tracker/features/settings/presentation/widgets/settings_page_scaffold.dart';

/// Settings hub: a short list of groups, each opening its own page.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> open(Widget page) async {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
      // Some pages change state that has no reactive provider (PIN, biometrics).
      ref.invalidate(settingsSecuritySummaryProvider);
    }

    final l10n = context.l10n;
    final isArabic = l10n.isArabic;
    String join(List<String?> parts) =>
        parts.whereType<String>().where((p) => p.isNotEmpty).join(' · ');

    final startDay = ref.watch(budgetCycleStartDayProvider).asData?.value;
    final currency = ref.watch(primaryCurrencyProvider);
    final budgetSummary = join([
      startDay == null
          ? null
          : startDay == 1
          ? l10n.calendarMonth
          : l10n.settingsCycleSummary(startDay),
      currency.displayLabel(isArabic: isArabic),
    ]);

    final themeLabel = switch (ref.watch(themeModeProvider)) {
      ThemeMode.light => l10n.themeLight,
      ThemeMode.dark => l10n.themeDark,
      ThemeMode.system => l10n.themeSystem,
    };
    final appearanceSummary = join([
      isArabic ? l10n.arabicLanguage : l10n.englishLanguage,
      themeLabel,
    ]);

    final security = ref.watch(settingsSecuritySummaryProvider).asData?.value;
    final securitySummary = security == null
        ? null
        : join([
            security.pinEnabled ? l10n.pinOnSummary : l10n.pinOffSummary,
            if (security.biometricsEnabled) l10n.biometricOnSummary,
          ]);

    final detectionOn =
        ref.watch(smartDetectionEnabledProvider).asData?.value ?? false;
    final watchedCount =
        ref.watch(watchedSourceAppsProvider).asData?.value.length ?? 0;
    final detectionSummary = detectionOn
        ? join([l10n.statusOn, l10n.sourceAppsSubtitle(watchedCount)])
        : l10n.statusOff;

    final reminder = ref.watch(dailyReminderProvider);
    final reminderSummary = reminder.isEnabled
        ? l10n.reminderSummary(reminder.formattedTime)
        : l10n.statusOff;

    return SettingsPageScaffold(
      title: context.l10n.settingsTitle,
      children: [
        // Section 1: Quick Presets
        Text(
          context.l10n.sectionQuickPresets,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: context.textSecondary,
          ),
        ),
        const SizedBox(height: 8),

        // Quick Presets Tile
        Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.amber.withValues(alpha: 0.12),
              child: const Icon(Icons.bolt_outlined, color: Colors.amber),
            ),
            title: Text(
              context.l10n.quickPresetsTileTitle,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
            subtitle: Text(
              context.l10n.quickPresetsTileSubtitle,
              style: TextStyle(color: context.textSecondary, fontSize: 13),
            ),
            trailing: Icon(Icons.chevron_right, color: context.textSecondary),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PresetsManagementScreen(),
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              SettingsNavTile(
                key: const ValueKey('settings_nav_budget_money'),
                icon: Icons.calendar_month_outlined,
                title: context.l10n.settingsBudgetMoneyTitle,
                summary: budgetSummary,
                onTap: () => open(const BudgetMoneySettingsPage()),
              ),
              const Divider(height: 1),
              SettingsNavTile(
                key: const ValueKey('settings_nav_language_appearance'),
                icon: Icons.palette_outlined,
                title: context.l10n.settingsLanguageAppearanceTitle,
                summary: appearanceSummary,
                onTap: () => open(const LanguageAppearanceSettingsPage()),
              ),
              const Divider(height: 1),
              SettingsNavTile(
                key: const ValueKey('settings_nav_security'),
                icon: Icons.lock_outline,
                title: context.l10n.settingsPrivacySecurityTitle,
                summary: securitySummary,
                onTap: () => open(const SecuritySettingsPage()),
              ),
              const Divider(height: 1),
              SettingsNavTile(
                key: const ValueKey('settings_nav_smart_detection'),
                icon: Icons.mark_chat_read_outlined,
                title: context.l10n.settingsSmartDetectionTitle,
                summary: detectionSummary,
                onTap: () => open(const SmartDetectionSettingsPage()),
              ),
              const Divider(height: 1),
              SettingsNavTile(
                key: const ValueKey('settings_nav_reminders'),
                icon: Icons.notifications_none_rounded,
                title: context.l10n.settingsRemindersTitle,
                summary: reminderSummary,
                onTap: () => open(const RemindersSettingsPage()),
              ),
              const Divider(height: 1),
              SettingsNavTile(
                key: const ValueKey('settings_nav_backup'),
                icon: Icons.save_alt_rounded,
                title: context.l10n.settingsBackupExportTitle,
                onTap: () => open(const BackupExportSettingsPage()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/logo.png', height: 48),
              const SizedBox(height: 6),
              Text(
                'SpendWise v1.0.0 • Offline & Private',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: context.textTertiary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}
