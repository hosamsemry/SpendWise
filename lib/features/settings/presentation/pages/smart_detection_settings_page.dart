import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/features/smart_detection/presentation/smart_detection_providers.dart';
import 'package:money_tracker/features/smart_detection/presentation/source_apps_sheet.dart';

import 'package:money_tracker/features/settings/presentation/widgets/settings_page_scaffold.dart';

class SmartDetectionSettingsPage extends ConsumerStatefulWidget {
  const SmartDetectionSettingsPage({super.key});

  @override
  ConsumerState<SmartDetectionSettingsPage> createState() =>
      _SmartDetectionSettingsPageState();
}

class _SmartDetectionSettingsPageState
    extends ConsumerState<SmartDetectionSettingsPage> {
  @override
  Widget build(BuildContext context) {
    return SettingsPageScaffold(
      title: context.l10n.settingsSmartDetectionTitle,
      children: [
        Consumer(
          builder: (context, ref, _) {
            final enabledAsync = ref.watch(smartDetectionEnabledProvider);
            final isEnabled = enabledAsync.asData?.value ?? false;
            final accessAsync = ref.watch(notificationAccessStatusProvider);
            final hasAccess = accessAsync.asData?.value ?? false;

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: isEnabled
                              ? context.primaryColor.withValues(alpha: 0.14)
                              : context.surfaceVariantColor,
                          child: Icon(
                            Icons.mark_chat_read_outlined,
                            color: isEnabled
                                ? context.primaryColor
                                : context.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.smartDetectionTitle,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: context.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                context.l10n.smartDetectionSubtitle,
                                style: TextStyle(
                                  color: context.textSecondary,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          key: const ValueKey('smart_detection_switch'),
                          value: isEnabled,
                          activeTrackColor: context.primaryColor,
                          onChanged: (val) async {
                            if (!val) {
                              await ref
                                  .read(smartDetectionEnabledProvider.notifier)
                                  .setEnabled(false);
                              return;
                            }

                            // Google Play Policy: Prominent disclosure before enabling Notification Access
                            final agreed = await showDialog<bool>(
                              context: context,
                              builder: (dlgCtx) => AlertDialog(
                                title: Text(
                                  context.l10n.smartDetectionDisclosureTitle,
                                ),
                                content: Text(
                                  context.l10n.smartDetectionDisclosureBody,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: context.textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dlgCtx, false),
                                    child: Text(context.l10n.cancel),
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.pop(dlgCtx, true),
                                    child: Text(
                                      context.l10n.enableSmartDetection,
                                    ),
                                  ),
                                ],
                              ),
                            );

                            if (agreed != true) return;
                            await ref
                                .read(smartDetectionEnabledProvider.notifier)
                                .setEnabled(true);

                            final granted = await ref
                                .read(smartDetectionChannelProvider)
                                .isNotificationAccessEnabled();
                            if (!granted && context.mounted) {
                              await ref
                                  .read(smartDetectionChannelProvider)
                                  .openNotificationAccessSettings();
                            }
                          },
                        ),
                      ],
                    ),
                    if (isEnabled) ...[
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                hasAccess
                                    ? Icons.verified_user_outlined
                                    : Icons.notifications_off_outlined,
                                size: 18,
                                color: hasAccess
                                    ? context.incomeColor
                                    : context.warningColor,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                hasAccess
                                    ? context.l10n.notificationAccessGranted
                                    : context.l10n.notificationAccessNeeded,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: hasAccess
                                      ? context.incomeColor
                                      : context.warningColor,
                                ),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: () => ref
                                .read(smartDetectionChannelProvider)
                                .openNotificationAccessSettings(),
                            child: Text(
                              context.l10n.openNotificationSettings,
                              style: const TextStyle(fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const Divider(height: 20),
                    Consumer(
                      builder: (context, ref, _) {
                        final watchedCount =
                            ref
                                .watch(watchedSourceAppsProvider)
                                .asData
                                ?.value
                                .length ??
                            0;
                        final suggestionCount =
                            ref
                                .watch(suggestedSourceAppsProvider)
                                .asData
                                ?.value
                                .length ??
                            0;
                        return InkWell(
                          key: const ValueKey('source_apps_tile'),
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => SourceAppsSheet.show(context),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.account_balance_outlined,
                                  size: 20,
                                  color: context.primaryColor,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        context.l10n.sourceAppsTitle,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: context.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        context.l10n.sourceAppsSubtitle(
                                          watchedCount,
                                        ),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: context.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (suggestionCount > 0)
                                  Badge(
                                    key: const ValueKey(
                                      'source_apps_suggestion_badge',
                                    ),
                                    label: Text('$suggestionCount'),
                                    backgroundColor: context.goldColor,
                                    textColor: Colors.black,
                                  ),
                                Icon(
                                  Icons.chevron_right,
                                  color: context.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
