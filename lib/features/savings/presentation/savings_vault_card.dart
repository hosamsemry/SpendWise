import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/providers/currency_provider.dart';
import 'package:money_tracker/core/providers/privacy_provider.dart';
import 'package:money_tracker/core/providers/savings_providers.dart';
import 'savings_vault_dialog.dart';

class SavingsVaultCard extends ConsumerWidget {
  const SavingsVaultCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(primaryCurrencyProvider);
    final isAmountsHidden = ref.watch(dashboardAmountsHiddenProvider);
    final vaultAsync = ref.watch(savingsVaultProvider);

    return vaultAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
      data: (vault) {
        final balance = vault.balance;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: context.isDark
                  ? context.savingsColor.withValues(alpha: 0.3)
                  : context.borderColor,
            ),
          ),
          color: context.isDark
              ? const Color(0xFF14141B)
              : context.surfaceColor,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              HapticFeedback.lightImpact();
              SavingsVaultDialog.show(context, vault);
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: context.savingsColor.withValues(alpha: 0.12),
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
                          vault.lastSweepAmount != null
                              ? (context.l10n.isArabic
                                  ? 'تم حفظ +${isAmountsHidden ? '••••' : vault.lastSweepAmount!.toFormattedString(currencySymbol: context.l10n.currencySymbol)} مؤخراً'
                                  : 'Last swept +${isAmountsHidden ? '••••' : vault.lastSweepAmount!.toFormattedString(currencySymbol: context.l10n.currencySymbol)}')
                              : (context.l10n.isArabic
                                  ? 'انقر للإيداع أو سحب الأموال'
                                  : 'Tap to deposit or withdraw funds'),
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
