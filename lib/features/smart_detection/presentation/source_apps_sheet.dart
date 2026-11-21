import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/features/smart_detection/domain/source_app.dart';
import 'package:money_tracker/features/smart_detection/presentation/smart_detection_providers.dart';

/// Lets the user choose which apps (besides SMS) may be read as transaction
/// sources: accept or ignore suggested apps, and remove watched ones.
class SourceAppsSheet extends ConsumerWidget {
  const SourceAppsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SourceAppsSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggested =
        ref.watch(suggestedSourceAppsProvider).asData?.value ??
        const <SuggestedSourceApp>[];
    final watched =
        ref.watch(watchedSourceAppsProvider).asData?.value ??
        const <WatchedSourceApp>[];
    final coordinator = ref.read(smartDetectionCoordinatorProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.sourceAppsTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.sourceAppsExplainer,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: context.textSecondary,
            ),
          ),
          if (suggested.isNotEmpty) ...[
            const SizedBox(height: 20),
            _SectionHeader(context.l10n.suggestedSourceAppsHeader),
            ...suggested.map(
              (app) => _AppRow(
                key: ValueKey('suggested_app_${app.packageName}'),
                label: app.label,
                packageName: app.packageName,
                detail: context.l10n.suggestedSourceAppHint(app.count),
                actions: [
                  TextButton(
                    key: ValueKey('ignore_app_${app.packageName}'),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      coordinator.dismissSuggestedApp(app.packageName);
                    },
                    child: Text(context.l10n.ignoreSourceApp),
                  ),
                  FilledButton(
                    key: ValueKey('watch_app_${app.packageName}'),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      coordinator.watchSourceApp(
                        packageName: app.packageName,
                        label: app.label,
                      );
                    },
                    child: Text(context.l10n.watchSourceApp),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          _SectionHeader(context.l10n.watchedSourceAppsHeader),
          if (watched.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                context.l10n.noWatchedSourceApps,
                style: TextStyle(fontSize: 13, color: context.textSecondary),
              ),
            )
          else
            ...watched.map(
              (app) => _AppRow(
                key: ValueKey('watched_app_${app.packageName}'),
                label: app.label,
                packageName: app.packageName,
                actions: [
                  TextButton(
                    key: ValueKey('unwatch_app_${app.packageName}'),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      coordinator.unwatchSourceApp(app.packageName);
                    },
                    child: Text(
                      context.l10n.unwatchSourceApp,
                      style: TextStyle(color: context.expenseColor),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: context.textSecondary,
        ),
      ),
    );
  }
}

class _AppRow extends StatelessWidget {
  final String label;
  final String packageName;
  final String? detail;
  final List<Widget> actions;

  const _AppRow({
    super.key,
    required this.label,
    required this.packageName,
    this.detail,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final showPackage = label != packageName;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.surfaceVariantColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.apps_rounded, size: 20, color: context.primaryColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                    if (showPackage)
                      Text(
                        packageName,
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.textTertiary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (detail != null) ...[
            const SizedBox(height: 6),
            Text(
              detail!,
              style: TextStyle(fontSize: 12, color: context.textSecondary),
            ),
          ],
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Wrap(spacing: 8, children: actions),
          ),
        ],
      ),
    );
  }
}
