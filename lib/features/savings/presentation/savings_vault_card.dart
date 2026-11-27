import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/providers/currency_provider.dart';
import 'package:money_tracker/core/providers/privacy_provider.dart';
import 'package:money_tracker/core/providers/savings_providers.dart';
import 'goals_screen.dart';

class SavingsVaultCard extends ConsumerWidget {
  const SavingsVaultCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(primaryCurrencyProvider);
    final isAmountsHidden = ref.watch(dashboardAmountsHiddenProvider);
    final vaultAsync = ref.watch(savingsVaultProvider);
    final topGoal = ref.watch(savingsOverviewProvider).value?.activeGoals.firstOrNull;

    return vaultAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
      data: (vault) {
        final balance = vault.balance;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge - 4),
            side: BorderSide(color: context.borderColor),
          ),
          color: context.surfaceColor,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GoalsScreen()),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: context.savingsLightColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.savings_rounded,
                      color: context.savingsColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.lifetimeSavingsVault.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6,
                            color: context.savingsColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Text(
                            isAmountsHidden
                                ? '••••••'
                                : balance.toFormattedString(
                                    currencySymbol: context.l10n.currencySymbol,
                                  ),
                            key: ValueKey('vault_balance_$isAmountsHidden'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: isAmountsHidden ? 1.8 : 0,
                              color: context.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          topGoal != null
                              ? context.l10n.vaultCardGoalLine(
                                  topGoal.goal.goal.name,
                                  (topGoal.goal.fraction * 100).floor(),
                                )
                              : vault.lastSweepAmount != null
                              ? (context.l10n.isArabic
                                  ? 'تم حفظ +${isAmountsHidden ? '••••' : vault.lastSweepAmount!.toFormattedString(currencySymbol: context.l10n.currencySymbol)} مؤخراً'
                                  : 'Last swept +${isAmountsHidden ? '••••' : vault.lastSweepAmount!.toFormattedString(currencySymbol: context.l10n.currencySymbol)}')
                              : context.l10n.vaultCardSubtitleEmpty,
                          style: TextStyle(
                            fontSize: 11,
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: context.textSecondary.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
