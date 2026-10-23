import 'dart:ffi';
import 'package:sqlite3/open.dart';

/// Configures SQLite dynamic library resolution for Linux environments in tests.
void setupTestSqlite() {
  open.overrideFor(OperatingSystem.linux, () {
    try {
      return DynamicLibrary.open('libsqlite3.so.0');
    } catch (_) {
      try {
        return DynamicLibrary.open('libsqlite3.so');
      } catch (_) {
        return DynamicLibrary.open('/usr/lib/x86_64-linux-gnu/libsqlite3.so.0');
      }
    }
  });
}
