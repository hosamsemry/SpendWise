import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/features/settings/presentation/settings_providers.dart';
import 'package:money_tracker/features/settings/presentation/widgets/settings_page_scaffold.dart';

/// Version, privacy promise and copyright.
class AboutSettingsPage extends ConsumerWidget {
  const AboutSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final version = ref.watch(appVersionProvider).asData?.value;

    Widget point(IconData icon, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: context.incomeColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: context.textPrimary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );

    return SettingsPageScaffold(
      title: l10n.aboutTitle,
      children: [
        const SizedBox(height: 8),
        Center(child: Image.asset('assets/images/logo.png', height: 64)),
        const SizedBox(height: 12),
        Center(
          child: Text(
            l10n.appName,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: context.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            l10n.aboutTagline,
            style: TextStyle(color: context.textSecondary),
          ),
        ),
        if (version != null) ...[
          const SizedBox(height: 4),
          Center(
            child: Text(
              l10n.versionLabel(version),
              key: const ValueKey('about_version'),
              textDirection: TextDirection.ltr,
              style: TextStyle(fontSize: 12, color: context.textTertiary),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.aboutPrivacyTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                point(Icons.phone_android_rounded, l10n.aboutPrivacyOffline),
                point(
                  Icons.visibility_off_outlined,
                  l10n.aboutPrivacyNoTracking,
                ),
                point(Icons.ios_share_rounded, l10n.aboutPrivacyBackups),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            '© 2026 Hosam · ${l10n.aboutLicense}',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: context.textTertiary),
          ),
        ),
      ],
    );
  }
}
