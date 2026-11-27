import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/features/settings/presentation/widgets/settings_page_scaffold.dart';

void main() {
  testWidgets('settings pages clear the navigation bar exactly once', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    // Edge-to-edge: a 48px gesture/3-button navigation bar at the bottom.
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 48);
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 48);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPageScaffold(
          title: 'Page',
          children: [
            for (var i = 0; i < 30; i++) SizedBox(height: 40, child: Text('row $i')),
          ],
        ),
      ),
    );

    await tester.drag(find.byType(ListView), const Offset(0, -5000));
    await tester.pumpAndSettle();

    final lastBottom = tester.getBottomLeft(find.text('row 29')).dy;
    // 800 - 48 (nav bar) - 24 (list padding); a doubled inset would end at 680.
    expect(tester.getRect(find.ancestor(of: find.text('row 29'), matching: find.byType(SizedBox)).first).bottom,
        closeTo(800 - 48 - 24, 0.5));
    expect(lastBottom, lessThanOrEqualTo(800 - 48));
  });
}
