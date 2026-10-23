import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/providers/language_provider.dart';

class LanguageSelectionScreen extends ConsumerStatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  ConsumerState<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState
    extends ConsumerState<LanguageSelectionScreen> {
  String? _selectedLanguageCode;
  bool _isSaving = false;

  Future<void> _handleConfirm() async {
    final code = _selectedLanguageCode;
    if (code == null || _isSaving) return;

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      await ref.read(appLanguageProvider.notifier).setLanguage(code);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _selectedLanguageCode == 'ar'
                  ? 'فشل حفظ اللغة: $e'
                  : 'Error saving language: $e',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = _selectedLanguageCode != null;

    return Scaffold(
      backgroundColor: context.surfaceColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // App Emblem
                Center(
                  child: Image.asset(
                    'assets/images/logo_emblem.png',
                    width: 80,
                    height: 80,
                  ),
                ),
                const SizedBox(height: 20),

                // Dual-language header
                Text(
                  'Welcome to SpendWise\nمرحباً بك في سبيند وايز',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Select your preferred language to begin\nاختر لغتك المفضلة للبدء',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(height: 36),

                // English Option Card
                _buildLanguageOptionCard(
                  languageCode: 'en',
                  title: 'English',
                  badge: 'EN',
                ),
                const SizedBox(height: 16),

                // Arabic Option Card
                _buildLanguageOptionCard(
                  languageCode: 'ar',
                  title: 'عربي',
                  badge: 'عربي',
                ),
                const SizedBox(height: 40),

                // Confirm & Continue Button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        context.primaryColor.withValues(alpha: 0.3),
                    disabledForegroundColor: Colors.white.withValues(alpha: 0.6),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: isSelected && !_isSaving ? _handleConfirm : null,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          _selectedLanguageCode == 'ar'
                              ? 'تأكيد ومتابعة'
                              : 'Confirm & Continue',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 16),

                Text(
                  _selectedLanguageCode == 'ar'
                      ? 'يمكنك تغيير اللغة لاحقاً في أي وقت من شاشة الإعدادات.'
                      : 'You can change the language anytime later from Settings.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageOptionCard({
    required String languageCode,
    required String title,
    required String badge,
  }) {
    final isChosen = _selectedLanguageCode == languageCode;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedLanguageCode = languageCode);
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isChosen
              ? context.primaryColor.withValues(alpha: 0.08)
              : context.surfaceVariantColor.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isChosen ? context.primaryColor : context.borderColor,
            width: isChosen ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Badge avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isChosen
                    ? context.primaryColor
                    : context.surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isChosen ? context.primaryColor : context.borderColor,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                badge,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isChosen ? Colors.white : context.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Title
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
            ),

            // Radio check indicator
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isChosen ? context.primaryColor : context.borderColor,
                  width: 2,
                ),
                color: isChosen ? context.primaryColor : Colors.transparent,
              ),
              child: isChosen
                  ? const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
