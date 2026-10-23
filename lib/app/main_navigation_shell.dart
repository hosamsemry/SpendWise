import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/providers/cycle_providers.dart';
import 'package:money_tracker/features/budgets/presentation/budgets_screen.dart';
import 'package:money_tracker/features/dashboard/presentation/dashboard_screen.dart';
import 'package:money_tracker/features/settings/presentation/settings_screen.dart';
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
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: currentIndex.clamp(0, screens.length - 1),
        children: screens,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        left: false,
        right: false,
        bottom: true,
        child: NavigationBar(
          selectedIndex: currentIndex.clamp(0, screens.length - 1),
          onDestinationSelected: navigateToIndex,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.dashboard_outlined),
              selectedIcon: const Icon(Icons.dashboard_rounded),
              label: context.l10n.navDashboard,
            ),
            NavigationDestination(
              icon: const Icon(Icons.receipt_long_outlined),
              selectedIcon: const Icon(Icons.receipt_long_rounded),
              label: context.l10n.navTransactions,
            ),
            NavigationDestination(
              icon: const Icon(Icons.pie_chart_outline_rounded),
              selectedIcon: const Icon(Icons.pie_chart_rounded),
              label: context.l10n.navBudgets,
            ),
            NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: const Icon(Icons.settings_rounded),
              label: context.l10n.navSettings,
            ),
          ],
        ),
      ),
    );
  }
}
