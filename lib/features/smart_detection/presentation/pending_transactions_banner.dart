import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/features/smart_detection/presentation/pending_transactions_sheet.dart';
import 'package:money_tracker/features/smart_detection/presentation/smart_detection_providers.dart';

/// Compact notification banner displayed when bank/wallet alerts await user confirmation.
class PendingTransactionsBanner extends ConsumerWidget {
  final EdgeInsetsGeometry margin;

  const PendingTransactionsBanner({
    super.key,
    this.margin = const EdgeInsets.only(bottom: 16),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingTransactionsProvider);

    return pendingAsync.when(
      skipLoadingOnReload: true,
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();

        final latest = items.first;
        final isDark = context.isDark;
        final accent = context.accentColor;

        return Padding(
          padding: margin,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: const ValueKey('pending_transactions_banner'),
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                HapticFeedback.selectionClick();
                PendingTransactionsSheet.show(context);
              },
              child: Ink(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? accent.withValues(alpha: 0.12)
                      : context.surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: accent.withValues(alpha: isDark ? 0.45 : 0.55),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: isDark ? 0.20 : 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.mark_chat_read_outlined,
                        color: accent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.pendingDetectedBannerTitle(
                              items.length,
                            ),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: context.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${latest.note} • ${latest.amount.toFormattedString(includeCurrency: false)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: context.primaryColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        context.l10n.reviewAndConfirm,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: context.onPrimaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
