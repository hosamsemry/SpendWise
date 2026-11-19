import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_tracker/app/widgets/floating_dock_nav_bar.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/providers/cycle_providers.dart';
import 'package:money_tracker/features/budgets/presentation/budgets_screen.dart';
import 'package:money_tracker/features/dashboard/presentation/dashboard_screen.dart';
import 'package:money_tracker/features/reports/presentation/reports_screen.dart';
import 'package:money_tracker/features/transactions/presentation/transactions_screen.dart';

class MainNavigationShell extends ConsumerWidget {
  const MainNavigationShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(currentNavigationIndexProvider);

    void navigateToIndex(int index) {
      HapticFeedback.selectionClick();
      ref.read(currentNavigationIndexProvider.notifier).setIndex(index);
    }

    final screens = [
      DashboardScreen(
        onNavigateToTransactions: () => navigateToIndex(1),
        onNavigateToBudgets: () => navigateToIndex(2),
      ),
      const TransactionsScreen(),
      const BudgetsScreen(),
      const ReportsScreen(),
    ];

    final clampedIndex = currentIndex.clamp(0, screens.length - 1);

    return Scaffold(
      body: IndexedStack(
        index: clampedIndex,
        children: screens,
      ),
      bottomNavigationBar: FloatingDockNavBar(
        selectedIndex: clampedIndex,
        onDestinationSelected: navigateToIndex,
        items: [
          FloatingDockItem(
            icon: Icons.grid_view_outlined,
            selectedIcon: Icons.grid_view_rounded,
            label: context.l10n.navDashboard,
          ),
          FloatingDockItem(
            icon: Icons.receipt_long_outlined,
            selectedIcon: Icons.receipt_long_rounded,
            label: context.l10n.navTransactions,
          ),
          FloatingDockItem(
            icon: Icons.pie_chart_outline_rounded,
            selectedIcon: Icons.pie_chart_rounded,
            label: context.l10n.navBudgets,
          ),
          FloatingDockItem(
            icon: Icons.insights_outlined,
            selectedIcon: Icons.insights_rounded,
            label: context.l10n.navInsights,
          ),
        ],
      ),
    );
  }
}
