import 'dart:io';
import 'package:flutter/services.dart';
import 'package:money_tracker/features/smart_detection/domain/source_app.dart';

/// How the native listener classified the app that posted an alert.
/// Mirrors `SourceAppPolicy.SourceKind` on Android.
enum AlertSourceKind {
  /// A bank/wallet app the user chose to watch.
  watched,

  /// An SMS app, which also carries personal messages.
  sms,

  /// Unknown, e.g. alerts queued before source gating existed.
  unknown;

  static AlertSourceKind fromWire(String? value) => switch (value) {
        'watched' => AlertSourceKind.watched,
        'sms' => AlertSourceKind.sms,
        _ => AlertSourceKind.unknown,
      };
}

class RawNativeAlert {
  final String id;
  final String packageName;
  final String title;
  final String text;
  final DateTime receivedAt;
  final AlertSourceKind sourceKind;

  const RawNativeAlert({
    required this.id,
    required this.packageName,
    required this.title,
    required this.text,
    required this.receivedAt,
    this.sourceKind = AlertSourceKind.unknown,
  });

  factory RawNativeAlert.fromMap(Map<dynamic, dynamic> map) {
    final ts = (map['timestampMs'] as num?)?.toInt();
    return RawNativeAlert(
      id: (map['id'] as String?) ?? '',
      packageName: (map['packageName'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      text: (map['text'] as String?) ?? '',
      receivedAt: ts != null
          ? DateTime.fromMillisecondsSinceEpoch(ts)
          : DateTime.now(),
      sourceKind: AlertSourceKind.fromWire(map['sourceKind'] as String?),
    );
  }
}

/// Platform channel bridge to Android's NotificationListenerService & ACTION_SEND Share intent.
class SmartDetectionChannel {
  static const MethodChannel _channel = MethodChannel(
    'com.personal.money_tracker/smart_detection',
  );

  void Function(RawNativeAlert alert)? onAlertReceived;
  void Function(String sharedText)? onSharedTextReceived;

  SmartDetectionChannel() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onAlertDetected':
        if (call.arguments is Map) {
          onAlertReceived?.call(
            RawNativeAlert.fromMap(call.arguments as Map),
          );
        }
        return null;
      case 'onSharedText':
        if (call.arguments is String) {
          onSharedTextReceived?.call(call.arguments as String);
        }
        return null;
      default:
        return null;
    }
  }

  Future<bool> isNotificationAccessEnabled() async {
    if (!Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>(
        'isNotificationAccessEnabled',
      );
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> openNotificationAccessSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('openNotificationAccessSettings');
    } catch (_) {
      // No-op on unsupported environments
    }
  }

  Future<void> setNativeDetectionEnabled(bool enabled) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('setSmartDetectionEnabled', {
        'enabled': enabled,
      });
    } catch (_) {
      // No-op in tests or non-Android builds
    }
  }

  /// Mirrors the user's watched/dismissed source apps to the native listener.
  Future<void> setSourcePolicy({
    required List<String> watched,
    required List<String> dismissed,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('setSourcePolicy', {
        'watched': watched,
        'dismissed': dismissed,
      });
    } catch (_) {
      // No-op in tests or non-Android builds
    }
  }

  /// Unwatched apps that posted financial-looking notifications.
  Future<List<SuggestedSourceApp>> getSuggestedApps() async {
    if (!Platform.isAndroid) return const [];
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('getSuggestedApps');
      if (raw == null) return const [];
      return raw
          .whereType<Map<dynamic, dynamic>>()
          .map(SuggestedSourceApp.fromMap)
          .where((app) => app.packageName.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<RawNativeAlert>> consumePendingNativeAlerts() async {
    if (!Platform.isAndroid) return const [];
    try {
      final rawList = await _channel.invokeMethod<List<dynamic>>(
        'consumePendingNativeAlerts',
      );
      if (rawList == null) return const [];
      return rawList
          .whereType<Map<dynamic, dynamic>>()
          .map(RawNativeAlert.fromMap)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<String?> consumeSharedText() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('consumeSharedText');
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getDiagnosticLogs() async {
    if (!Platform.isAndroid) return const [];
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>(
        'getDiagnosticLogs',
      );
      if (raw == null) return const [];
      return raw
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => m.map((k, v) => MapEntry(k.toString(), v)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> clearDiagnosticLogs() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('clearDiagnosticLogs');
    } catch (_) {
      // No-op
    }
  }
}
