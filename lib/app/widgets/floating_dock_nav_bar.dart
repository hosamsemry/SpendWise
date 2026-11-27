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

/// The app's bottom navigation: a flat bar on the surface colour with a
/// hairline top border. The selected tab gets a small tinted indicator behind
/// its icon and an accent-coloured label; nothing floats, blurs or glows.
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        border: Border(top: BorderSide(color: context.borderColor)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          child: Row(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = index == selectedIndex;
              final color =
                  isSelected ? context.primaryColor : context.textSecondary;

              return Expanded(
                child: Semantics(
                  selected: isSelected,
                  button: true,
                  label: item.label,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    onTap: () => onDestinationSelected(index),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            width: 56,
                            height: 30,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? context.primaryLightColor
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Icon(
                              isSelected ? item.selectedIcon : item.icon,
                              size: 22,
                              color: color,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight:
                                  isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: color,
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
    );
  }
}
