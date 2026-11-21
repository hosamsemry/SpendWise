import 'package:flutter/material.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';

/// Prominent reminder at the top of Settings when the user has never backed
/// up (or not recently): the app is offline-only, so losing the phone means
/// losing the data.
class BackupNudgeCard extends StatelessWidget {
  final String ageLabel;
  final VoidCallback onBackUp;

  const BackupNudgeCard({
    super.key,
    required this.ageLabel,
    required this.onBackUp,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      key: const ValueKey('backup_nudge_card'),
      color: context.warningLightColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: context.warningColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.backupNudgeTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${l10n.backupNudgeBody} ($ageLabel)',
              style: TextStyle(fontSize: 13, color: context.textSecondary),
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.icon(
                key: const ValueKey('backup_nudge_action'),
                onPressed: onBackUp,
                icon: const Icon(Icons.save_alt_rounded, size: 18),
                label: Text(l10n.backupNudgeAction),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
