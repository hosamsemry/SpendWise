import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:money_tracker/app/theme/app_theme.dart';

class FloatingDockItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const FloatingDockItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

/// A bespoke floating pill navigation dock with subtle blur, tactile active pill,
/// and harmonized light/dark luxury styling.
class FloatingDockNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<FloatingDockItem> items;

  const FloatingDockNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return ColoredBox(
      color: context.backgroundColor,
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.45)
                      : const Color(0xFF0B0F19).withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
                if (!isDark)
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xEB15151E)
                        : const Color(0xF5FFFFFF),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: isDark
                          ? AppColorsDark.gold.withValues(alpha: 0.22)
                          : AppColors.border,
                      width: 1.1,
                    ),
                  ),
                  child: Row(
                    children: List.generate(items.length, (index) {
                      final item = items[index];
                      final isSelected = index == selectedIndex;

                      return Expanded(
                        child: Semantics(
                          selected: isSelected,
                          button: true,
                          label: item.label,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: () => onDestinationSelected(index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (isDark
                                        ? AppColorsDark.gold.withValues(
                                            alpha: 0.14,
                                          )
                                        : AppColors.primaryLight)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(22),
                                border: isSelected
                                    ? Border.all(
                                        color: isDark
                                            ? AppColorsDark.gold.withValues(
                                                alpha: 0.35,
                                              )
                                            : AppColors.gold.withValues(
                                                alpha: 0.45,
                                              ),
                                        width: 1,
                                      )
                                    : Border.all(
                                        color: Colors.transparent,
                                        width: 1,
                                      ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isSelected ? item.selectedIcon : item.icon,
                                    size: 22,
                                    color: isSelected
                                        ? context.primaryColor
                                        : context.textSecondary,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    item.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      letterSpacing: -0.1,
                                      color: isSelected
                                          ? context.primaryColor
                                          : context.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
