import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/app/theme/app_theme.dart';

void main() {
  // AnimatedTheme interpolates light <-> dark; a component text style that is
  // partial (inherit: true) in one theme but missing in the other cannot be
  // interpolated and throws in debug builds.
  test('button text styles can interpolate between light and dark', () {
    final l = AppTheme.lightTheme, d = AppTheme.darkTheme;
    for (final (name, a, b) in [
      ('text', l.textButtonTheme.style, d.textButtonTheme.style),
      ('elevated', l.elevatedButtonTheme.style, d.elevatedButtonTheme.style),
      ('outlined', l.outlinedButtonTheme.style, d.outlinedButtonTheme.style),
      ('segmented', l.segmentedButtonTheme.style, d.segmentedButtonTheme.style),
    ]) {
      final sa = a?.textStyle?.resolve({}), sb = b?.textStyle?.resolve({});
      expect(sa == null, sb == null, reason: '$name textStyle defined in only one theme');
      if (sa != null) expect(TextStyle.lerp(sa, sb, 0.5), isNotNull, reason: name);
    }
  });
}
