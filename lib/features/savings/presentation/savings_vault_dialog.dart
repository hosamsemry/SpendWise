import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/core/providers/cycle_providers.dart';
import 'package:money_tracker/core/providers/savings_providers.dart';
import '../domain/savings_vault.dart';

class SavingsVaultDialog extends ConsumerStatefulWidget {
  final SavingsVault vault;

  const SavingsVaultDialog({super.key, required this.vault});

  static Future<void> show(BuildContext context, SavingsVault vault) {
    return showDialog(
      context: context,
      builder: (_) => SavingsVaultDialog(vault: vault),
    );
  }

  @override
  ConsumerState<SavingsVaultDialog> createState() => _SavingsVaultDialogState();
}

class _SavingsVaultDialogState extends ConsumerState<SavingsVaultDialog> {
  bool _isDepositMode = true;
  final TextEditingController _amountController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _amountController.text.trim();
    final amount = Money.tryParse(text);

    if (amount == null || amount.inMinorUnits <= 0) {
      setState(() => _errorMessage = context.l10n.isArabic ? 'أدخل مبلغاً صالحاً' : 'Enter a valid amount');
      return;
    }

    final repo = ref.read(savingsVaultRepositoryProvider);

    try {
      if (_isDepositMode) {
        await repo.deposit(amount: amount);
      } else {
        if (amount > widget.vault.balance) {
          setState(() => _errorMessage = context.l10n.cannotWithdrawOverdraft);
          return;
        }
        await repo.withdraw(amount: amount);
      }

      ref.read(refreshTriggerProvider.notifier).trigger();
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      Navigator.pop(context);

      final actionStr = _isDepositMode
          ? (context.l10n.isArabic ? 'تم إيداع' : 'Deposited')
          : (context.l10n.isArabic ? 'تم سحب' : 'Withdrew');
      final prepStr = _isDepositMode
          ? (context.l10n.isArabic ? 'في' : 'into')
          : (context.l10n.isArabic ? 'من' : 'from');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$actionStr ${amount.toFormattedString(currencySymbol: context.l10n.currencySymbol)} $prepStr ${context.l10n.lifetimeSavingsVault}.'),
        ),
      );
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance = widget.vault.balance;
    final lastSweptAt = widget.vault.lastSweptAt;
    final lastSweepAmount = widget.vault.lastSweepAmount;

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.savings_rounded,
              color: Color(0xFF10B981),
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Text(context.l10n.lifetimeSavingsVault),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Balance Hero Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.isDark
                    ? const Color(0xFF064E3B).withValues(alpha: 0.3)
                    : const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.isArabic
                        ? 'إجمالي المدخرات المحفوظة'
                        : 'TOTAL ACCUMULATED SAVINGS',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    balance.toFormattedString(currencySymbol: context.l10n.currencySymbol),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  if (lastSweptAt != null && lastSweepAmount != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      context.l10n.isArabic
                          ? 'تم حفظ +${lastSweepAmount.toFormattedString(currencySymbol: context.l10n.currencySymbol)} في ${DateFormat("d MMM yyyy").format(lastSweptAt)}'
                          : 'Last swept +${lastSweepAmount.toFormattedString(currencySymbol: context.l10n.currencySymbol)} on ${DateFormat("d MMM yyyy").format(lastSweptAt)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Mode Toggle (Deposit vs Withdraw)
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: Center(child: Text(context.l10n.deposit)),
                    selected: _isDepositMode,
                    onSelected: (val) {
                      if (val) setState(() => _isDepositMode = true);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: Center(child: Text(context.l10n.withdraw)),
                    selected: !_isDepositMode,
                    onSelected: (val) {
                      if (val) setState(() => _isDepositMode = false);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Amount Input
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: _isDepositMode
                    ? (context.l10n.isArabic ? 'مبلغ الإيداع' : 'Deposit Amount')
                    : (context.l10n.isArabic ? 'مبلغ السحب' : 'Withdraw Amount'),
                prefixText: '${context.l10n.currencySymbol} ',
                errorText: _errorMessage,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (_errorMessage != null) {
                  setState(() => _errorMessage = null);
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
          ),
          child: Text(_isDepositMode ? context.l10n.deposit : context.l10n.withdraw),
        ),
      ],
    );
  }
}
