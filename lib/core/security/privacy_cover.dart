import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';

/// Bridge to the native privacy helpers in `MainActivity`.
class PrivacyChannel {
  static const MethodChannel _channel = MethodChannel(
    'com.paydial.app/privacy',
  );

  const PrivacyChannel._();

  /// True when Android itself keeps the app out of recent-apps thumbnails
  /// (Android 13+ `setRecentsScreenshotEnabled(false)`), so no Flutter cover
  /// is needed. False elsewhere or when the platform cannot tell.
  static Future<bool> isRecentsPreviewHiddenNatively() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isRecentsPreviewHiddenNatively') ??
          false;
    } catch (_) {
      return false;
    }
  }
}

/// Neutral branded screen drawn over the app while it is not in the
/// foreground, so the recent-apps thumbnail on Android 12 and older shows no
/// balances. Screenshots taken by the user in the foreground are unaffected.
class PrivacyCover extends StatelessWidget {
  const PrivacyCover({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const ValueKey('privacy_cover'),
      color: context.backgroundColor,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/logo_emblem.png',
              width: 96,
              height: 96,
              errorBuilder: (_, _, _) => Icon(
                Icons.lock_outline,
                size: 64,
                color: context.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.appName,
              textDirection: TextDirection.ltr,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
