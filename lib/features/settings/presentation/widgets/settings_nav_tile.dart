import 'package:flutter/material.dart';
import 'package:money_tracker/app/theme/app_theme.dart';

/// One row of the Settings hub: icon, title, optional current-value summary,
/// and a chevron that opens the sub-page.
class SettingsNavTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? summary;
  final VoidCallback onTap;

  const SettingsNavTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.summary,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? context.primaryColor;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: context.textPrimary,
        ),
      ),
      subtitle: summary == null
          ? null
          : Text(
              summary!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.textSecondary, fontSize: 13),
            ),
      trailing: Icon(
        Directionality.of(context) == TextDirection.rtl
            ? Icons.chevron_left
            : Icons.chevron_right,
        color: context.textSecondary,
      ),
      onTap: onTap,
    );
  }
}
