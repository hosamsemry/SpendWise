import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/security/biometric_service.dart';
import 'package:money_tracker/core/security/presentation/pin_lock_screen.dart';
import 'package:money_tracker/core/security/security_service.dart';

import 'package:money_tracker/features/settings/presentation/widgets/settings_page_scaffold.dart';

class SecuritySettingsPage extends ConsumerStatefulWidget {
  const SecuritySettingsPage({super.key});

  @override
  ConsumerState<SecuritySettingsPage> createState() =>
      _SecuritySettingsPageState();
}

class _SecuritySettingsPageState extends ConsumerState<SecuritySettingsPage> {
  /// Changing an existing PIN first requires the current one (rate limited
  /// like unlocking), so whoever holds an unlocked phone cannot replace it.
  Future<void> _changePin() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => PinLockScreen(
          mode: PinMode.unlock,
          onCancel: () => Navigator.pop(ctx),
          onUnlocked: () {
            Navigator.pop(ctx);
            if (mounted) _handlePinToggle(true);
          },
        ),
      ),
    );
  }

  Future<void> _handlePinToggle(bool enable) async {
    final security = ref.read(securityServiceProvider);
    if (enable) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => PinLockScreen(
            mode: PinMode.create,
            onCancel: () => Navigator.pop(ctx),
            onPinCreated: (firstPin) {
              Navigator.pushReplacement(
                ctx,
                MaterialPageRoute(
                  builder: (confirmCtx) => PinLockScreen(
                    mode: PinMode.confirm,
                    pinToConfirm: firstPin,
                    onCancel: () => Navigator.pop(confirmCtx),
                    onPinCreated: (confirmedPin) async {
                      await security.setPin(confirmedPin);
                      if (confirmCtx.mounted) Navigator.pop(confirmCtx);
                      if (!mounted) return;
                      setState(() {});
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.l10n.pinEnabledSuccess),
                          ),
                        );
                      }
                    },
                  ),
                ),
              );
            },
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => PinLockScreen(
            mode: PinMode.unlock,
            onCancel: () => Navigator.pop(ctx),
            onUnlocked: () async {
              await security.resetPin();
              if (ctx.mounted) Navigator.pop(ctx);
              if (!mounted) return;
              setState(() {});
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.l10n.pinDisabledSuccess)),
                );
              }
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final security = ref.watch(securityServiceProvider);
    return SettingsPageScaffold(
      title: context.l10n.settingsPrivacySecurityTitle,
      children: [
        FutureBuilder<bool>(
          future: security.isPinEnabled(),
          builder: (context, snapshot) {
            final isPinEnabled = snapshot.data ?? false;

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
                              backgroundColor: isPinEnabled
                                  ? context.primaryLightColor
                                  : context.surfaceVariantColor,
                              child: Icon(
                                isPinEnabled
                                    ? Icons.lock_rounded
                                    : Icons.lock_open_rounded,
                                color: isPinEnabled
                                    ? context.primaryColor
                                    : context.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.l10n.pinLock,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: context.textPrimary,
                                  ),
                                ),
                                Text(
                                  isPinEnabled
                                      ? (context.l10n.isArabic
                                            ? 'التطبيق محمي برمز PIN مكون من 4 أرقام'
                                            : 'App is protected with a 4-digit PIN')
                                      : context.l10n.pinLockSubtitle,
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
                          value: isPinEnabled,
                          onChanged: (val) => _handlePinToggle(val),
                          activeTrackColor: context.primaryColor,
                        ),
                      ],
                    ),
                    if (isPinEnabled) ...[
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
                      FutureBuilder<bool>(
                        future: ref
                            .read(biometricServiceProvider)
                            .isBiometricsEnabled(),
                        builder: (context, bioSnap) {
                          final isBioEnabled = bioSnap.data ?? false;
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.fingerprint,
                                    size: 20,
                                    color: context.primaryColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    context.l10n.biometricLock,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: context.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              Switch.adaptive(
                                value: isBioEnabled,
                                activeTrackColor: context.primaryColor,
                                onChanged: (val) async {
                                  final bioService = ref.read(
                                    biometricServiceProvider,
                                  );
                                  final unsupportedNotice =
                                      context.l10n.isArabic
                                      ? 'المصادقة البيومترية غير مدعومة أو غير مفعلة على هذا الجهاز.'
                                      : 'Biometric authentication is not supported or enrolled on this device.';
                                  final reasonStr = context.l10n.isArabic
                                      ? 'تأكيد البصمة لتمكين الفتح السريع'
                                      : 'Confirm biometrics to enable quick unlock';
                                  if (val) {
                                    final supported = await bioService
                                        .isDeviceSupported();
                                    if (!supported) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(unsupportedNotice),
                                          ),
                                        );
                                      }
                                      return;
                                    }
                                    final authenticated = await bioService
                                        .authenticate(reason: reasonStr);
                                    if (!authenticated) return;
                                  }
                                  await bioService.setBiometricsEnabled(val);
                                  if (mounted) setState(() {});
                                },
                              ),
                            ],
                          );
                        },
                      ),
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.pin_outlined, size: 18),
                            key: const ValueKey('change_pin_button'),
                            label: Text(context.l10n.changePin),
                            onPressed: _changePin,
                          ),
                          TextButton.icon(
                            icon: Icon(
                              Icons.lock_open_rounded,
                              size: 18,
                              color: context.overspentColor,
                            ),
                            label: Text(
                              context.l10n.disablePin,
                              style: TextStyle(color: context.overspentColor),
                            ),
                            onPressed: () => _handlePinToggle(false),
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
