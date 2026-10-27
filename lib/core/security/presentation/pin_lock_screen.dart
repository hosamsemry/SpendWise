import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/security/biometric_service.dart';
import 'package:money_tracker/core/security/security_service.dart';

enum PinMode { unlock, create, confirm }

class PinLockScreen extends ConsumerStatefulWidget {
  final PinMode mode;
  final String? pinToConfirm;
  final VoidCallback? onUnlocked;
  final ValueChanged<String>? onPinCreated;
  final VoidCallback? onCancel;

  const PinLockScreen({
    super.key,
    this.mode = PinMode.unlock,
    this.pinToConfirm,
    this.onUnlocked,
    this.onPinCreated,
    this.onCancel,
  });

  @override
  ConsumerState<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends ConsumerState<PinLockScreen>
    with SingleTickerProviderStateMixin {
  String _enteredPin = '';
  String? _errorMessage;
  late AnimationController _shakeController;

  int _failedAttempts = 0;
  int _lockoutSeconds = 0;
  Timer? _lockoutTimer;
  bool _canUseBiometrics = false;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    if (widget.mode == PinMode.unlock) {
      final bioService = ref.read(biometricServiceProvider);
      final isEnabled = await bioService.isBiometricsEnabled();
      if (isEnabled) {
        final isSupported = await bioService.isDeviceSupported();
        if (mounted && isSupported) {
          setState(() => _canUseBiometrics = true);
          // Auto-prompt once on display
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _authenticateWithBiometrics();
          });
        }
      }
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    if (!_canUseBiometrics || _lockoutSeconds > 0) return;
    final bioService = ref.read(biometricServiceProvider);
    final reason = context.l10n.isArabic
        ? 'المصادقة لإلغاء قفل سبيند وايز'
        : 'Authenticate to unlock SpendWise';
    final authenticated = await bioService.authenticate(reason: reason);
    if (authenticated && mounted) {
      ref.read(isAppLockedProvider.notifier).state = false;
      widget.onUnlocked?.call();
    }
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  void _onDigitPressed(String digit) {
    if (_lockoutSeconds > 0) return;
    if (_enteredPin.length >= 4) return;

    setState(() {
      _errorMessage = null;
      _enteredPin += digit;
    });

    if (_enteredPin.length == 4) {
      _handleCompletedPin(_enteredPin);
    }
  }

  void _onBackspacePressed() {
    if (_lockoutSeconds > 0) return;
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _errorMessage = null;
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  Future<void> _handleCompletedPin(String pin) async {
    if (widget.mode == PinMode.unlock) {
      final security = ref.read(securityServiceProvider);
      final isValid = await security.verifyPin(pin);
      if (isValid) {
        _failedAttempts = 0;
        _lockoutTimer?.cancel();
        ref.read(isAppLockedProvider.notifier).state = false;
        widget.onUnlocked?.call();
      } else {
        _failedAttempts++;
        if (_failedAttempts >= 5) {
          _startLockout();
        } else {
          final remaining = 5 - _failedAttempts;
          if (mounted) _triggerError(context.l10n.incorrectPinNotice(remaining));
        }
      }
    } else if (widget.mode == PinMode.create) {
      widget.onPinCreated?.call(pin);
    } else if (widget.mode == PinMode.confirm) {
      if (pin == widget.pinToConfirm) {
        widget.onPinCreated?.call(pin);
      } else {
        if (mounted) _triggerError(context.l10n.pinsDoNotMatch);
      }
    }
  }

  void _startLockout() {
    _lockoutTimer?.cancel();
    setState(() {
      _lockoutSeconds = 30;
      if (mounted) _errorMessage = context.l10n.lockoutNotice(30);
      _enteredPin = '';
    });
    _shakeController.forward(from: 0.0);

    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_lockoutSeconds <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _lockoutSeconds = 0;
            _failedAttempts = 0;
            _errorMessage = null;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _lockoutSeconds--;
            if (mounted) _errorMessage = context.l10n.lockoutNotice(_lockoutSeconds);
          });
        }
      }
    });
  }

  void _triggerError(String message) {
    setState(() {
      _errorMessage = message;
      _enteredPin = '';
    });
    _shakeController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColorsDark.primary : AppColors.primary;
    final textColor = isDark
        ? AppColorsDark.textPrimary
        : AppColors.textPrimary;
    final dotEmptyColor = isDark
        ? AppColorsDark.surfaceVariant
        : const Color(0xFFE2E8F0);

    final title = widget.mode == PinMode.unlock
        ? context.l10n.enterAppPin
        : widget.mode == PinMode.create
        ? context.l10n.setAppPin
        : context.l10n.confirmAppPin;

    final subtitle = widget.mode == PinMode.unlock
        ? context.l10n.unlockFinancesSubtitle
        : widget.mode == PinMode.create
        ? context.l10n.choosePinSubtitle
        : context.l10n.reenterPinSubtitle;

    return PopScope(
      canPop: widget.mode != PinMode.unlock,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              if (widget.onCancel != null)
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12, top: 8),
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: widget.onCancel,
                    ),
                  ),
                )
              else
                const SizedBox(height: 48),

              const Spacer(flex: 1),

              // Lock Icon & Header
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.mode == PinMode.unlock
                      ? Icons.lock_outline
                      : Icons.security,
                  size: 36,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? AppColorsDark.textSecondary
                      : AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // PIN Indicator Dots with Shake Animation
              AnimatedBuilder(
                animation: _shakeController,
                builder: (context, child) {
                  final offset = (_shakeController.value * 6 * 3.14159);
                  final dx = _shakeController.isAnimating
                      ? (8 * (1 - _shakeController.value) * math.sin(offset))
                      : 0.0;
                  return Transform.translate(
                    offset: Offset(dx, 0),
                    child: child,
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final isFilled = index < _enteredPin.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _errorMessage != null
                            ? (isDark
                                  ? AppColorsDark.overspent
                                  : AppColors.overspent)
                            : isFilled
                            ? primaryColor
                            : dotEmptyColor,
                      ),
                    );
                  }),
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: isDark
                        ? AppColorsDark.overspent
                        : AppColors.overspent,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],

              const Spacer(flex: 2),

              // Keypad (3x4 Grid)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    _buildKeypadRow(['1', '2', '3']),
                    const SizedBox(height: 16),
                    _buildKeypadRow(['4', '5', '6']),
                    const SizedBox(height: 16),
                    _buildKeypadRow(['7', '8', '9']),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (_canUseBiometrics && widget.mode == PinMode.unlock)
                          SizedBox(
                            width: 72,
                            height: 72,
                            child: InkWell(
                              onTap: _lockoutSeconds > 0 ? null : _authenticateWithBiometrics,
                              borderRadius: BorderRadius.circular(36),
                              child: Center(
                                child: Icon(
                                  Icons.fingerprint,
                                  size: 32,
                                  color: _lockoutSeconds > 0
                                      ? textColor.withValues(alpha: 0.3)
                                      : primaryColor,
                                ),
                              ),
                            ),
                          )
                        else
                          const SizedBox(width: 72, height: 72),
                        _buildKeypadButton('0'),
                        SizedBox(
                          width: 72,
                          height: 72,
                          child: InkWell(
                            onTap: _onBackspacePressed,
                            borderRadius: BorderRadius.circular(36),
                            child: Center(
                              child: Icon(
                                Icons.backspace_outlined,
                                size: 26,
                                color: textColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map(_buildKeypadButton).toList(),
    );
  }

  Widget _buildKeypadButton(String digit) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final btnBg = isDark ? AppColorsDark.surfaceVariant : const Color(0xFFF1F5F9);
    final borderColor = isDark ? AppColorsDark.border : AppColors.border;
    final textColor = isDark
        ? AppColorsDark.textPrimary
        : AppColors.textPrimary;

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: btnBg,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 1),
      ),
      child: InkWell(
        onTap: () => _onDigitPressed(digit),
        borderRadius: BorderRadius.circular(36),
        child: Center(
          child: Text(
            digit,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}
