import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_tracker/core/providers/cycle_providers.dart';
import 'package:money_tracker/core/security/biometric_service.dart';
import 'package:money_tracker/core/security/security_service.dart';

/// PIN / biometric state shown on the Settings hub. Invalidate after
/// returning from the security page (it changes these without a refresh).
final settingsSecuritySummaryProvider =
    FutureProvider<({bool pinEnabled, bool biometricsEnabled})>((ref) async {
      ref.watch(refreshTriggerProvider);
      final pin = await ref.watch(securityServiceProvider).isPinEnabled();
      final bio = await ref
          .watch(biometricServiceProvider)
          .isBiometricsEnabled();
      return (pinEnabled: pin, biometricsEnabled: pin && bio);
    });
