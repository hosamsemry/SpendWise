import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs around every test file. Points path_provider at a throwaway temp
/// folder, so code that stores files in app folders (e.g. the safety
/// snapshots taken before a restore) works in tests without a device.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final root = await Directory.systemTemp.createTemp('paydial_test_app_dirs');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => root.path,
      );
  await testMain();
}
