import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/app/widgets/floating_dock_nav_bar.dart';

double _contrastRatio(Color foreground, Color background) {
  final l1 = foreground.computeLuminance();
  final l2 = background.computeLuminance();
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('AppTheme WCAG AA Contrast & Input Legibility', () {
    test('Light theme achieves WCAG AA (>= 4.5:1) for text, hints, and primary', () {
      // Primary accent on white surface & white text on primary button
      expect(
        _contrastRatio(AppColors.primary, AppColors.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(Colors.white, AppColors.primary),
        greaterThanOrEqualTo(4.5),
      );

      // Typography & input legibility on porcelain surface and input fill
      expect(
        _contrastRatio(AppColors.textPrimary, AppColors.inputFill),
        greaterThanOrEqualTo(7.0), // AAA
      );
      expect(
        _contrastRatio(AppColors.textSecondary, AppColors.inputFill),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(AppColors.textTertiary, AppColors.surface),
        greaterThanOrEqualTo(4.5),
      );

      // Edit box fill is visually distinct from white dialog surface
      final inputTheme = AppTheme.lightTheme.inputDecorationTheme;
      expect(inputTheme.filled, isTrue);
      expect(inputTheme.fillColor, isNot(AppColors.surface));
      expect(inputTheme.floatingLabelStyle?.color, AppColors.primary);
    });

    test('Dark theme achieves WCAG AA (>= 4.5:1) for edit boxes and dialog text', () {
      expect(
        _contrastRatio(AppColorsDark.primary, AppColorsDark.dialogSurface),
        greaterThanOrEqualTo(7.0),
      );
      expect(
        _contrastRatio(Colors.white, AppColorsDark.inputFill),
        greaterThanOrEqualTo(15.0),
      );
      expect(
        _contrastRatio(AppColorsDark.textSecondary, AppColorsDark.inputFill),
        greaterThanOrEqualTo(7.0),
      );
      expect(
        _contrastRatio(AppColorsDark.textTertiary, AppColorsDark.inputFill),
        greaterThanOrEqualTo(4.5),
      );

      // Recessed dark well is distinct from dialog surface
      final inputTheme = AppTheme.darkTheme.inputDecorationTheme;
      expect(inputTheme.filled, isTrue);
      expect(inputTheme.fillColor, isNot(AppColorsDark.dialogSurface));
      expect(inputTheme.floatingLabelStyle?.color, AppColorsDark.primary);
    });
  });

  group('FloatingDockNavBar', () {
    const items = [
      FloatingDockItem(
        icon: Icons.grid_view_outlined,
        selectedIcon: Icons.grid_view_rounded,
        label: 'Dashboard',
      ),
      FloatingDockItem(
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long_rounded,
        label: 'Transactions',
      ),
      FloatingDockItem(
        icon: Icons.pie_chart_outline_rounded,
        selectedIcon: Icons.pie_chart_rounded,
        label: 'Budgets',
      ),
      FloatingDockItem(
        icon: Icons.tune_outlined,
        selectedIcon: Icons.tune_rounded,
        label: 'Settings',
      ),
    ];

    testWidgets('Renders all destinations and triggers callback on tap (Light & Dark)', (tester) async {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        int selected = 0;

        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: StatefulBuilder(
              builder: (context, setState) => Scaffold(
                body: const SizedBox.shrink(),
                bottomNavigationBar: FloatingDockNavBar(
                  selectedIndex: selected,
                  onDestinationSelected: (idx) => setState(() => selected = idx),
                  items: items,
                ),
              ),
            ),
          ),
        );

        expect(find.text('Dashboard'), findsOneWidget);
        expect(find.text('Transactions'), findsOneWidget);
        expect(find.text('Budgets'), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);

        // Selected icon is shown for index 0
        expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
        expect(find.byIcon(Icons.pie_chart_outline_rounded), findsOneWidget);

        // Tap Budgets -> switches selection to index 2
        await tester.tap(find.text('Budgets'));
        await tester.pumpAndSettle();

        expect(selected, 2);
        expect(find.byIcon(Icons.pie_chart_rounded), findsOneWidget);
        expect(find.byIcon(Icons.grid_view_outlined), findsOneWidget);
      }
    });
  });
}
