import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/providers/reminder_provider.dart';

import 'package:money_tracker/features/settings/presentation/widgets/settings_page_scaffold.dart';

class RemindersSettingsPage extends ConsumerStatefulWidget {
  const RemindersSettingsPage({super.key});

  @override
  ConsumerState<RemindersSettingsPage> createState() =>
      _RemindersSettingsPageState();
}

class _RemindersSettingsPageState extends ConsumerState<RemindersSettingsPage> {
  @override
  Widget build(BuildContext context) {
    return SettingsPageScaffold(
      title: context.l10n.settingsRemindersTitle,
      children: [
        Consumer(
          builder: (context, ref, _) {
            final reminderSettings = ref.watch(dailyReminderProvider);

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: reminderSettings.isEnabled
                                  ? Colors.indigo.withValues(alpha: 0.12)
                                  : Colors.grey.withValues(alpha: 0.12),
                              child: Icon(
                                Icons.notifications_active_outlined,
                                color: reminderSettings.isEnabled
                                    ? Colors.indigo
                                    : context.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.l10n.dailyEveningReminder,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: context.textPrimary,
                                  ),
                                ),
                                Text(
                                  reminderSettings.isEnabled
                                      ? context.l10n.scheduledForTime(
                                          reminderSettings.formattedTime,
                                        )
                                      : context.l10n.remindMeToLogDaily,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Switch.adaptive(
                          value: reminderSettings.isEnabled,
                          activeTrackColor: context.primaryColor,
                          onChanged: (val) async {
                            final success = await ref
                                .read(dailyReminderProvider.notifier)
                                .setEnabled(val);
                            if (!success && val && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    context.l10n.notificationPermissionDenied,
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                    if (reminderSettings.isEnabled) ...[
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            context.l10n.reminderTime,
                            style: TextStyle(
                              fontSize: 14,
                              color: context.textPrimary,
                            ),
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.access_time, size: 16),
                            label: Text(reminderSettings.formattedTime),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay(
                                  hour: reminderSettings.hour,
                                  minute: reminderSettings.minute,
                                ),
                              );
                              if (picked != null) {
                                await ref
                                    .read(dailyReminderProvider.notifier)
                                    .setTime(picked.hour, picked.minute);
                              }
                            },
                          ),
                        ],
                      ),
                    ],
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
