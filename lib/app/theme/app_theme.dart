import 'package:flutter/material.dart';

class AppColors {
  // Brand / Luxury Gold Accent
  static const Color primary = Color(0xFFB38A24); // Warm Rich Gold for Light mode contrast
  static const Color primaryLight = Color(0xFFFFFBEB);
  static const Color primaryContainer = Color(0xFFF3E3B6);
  static const Color gold = Color(0xFFE5C158);

  // Financial States
  static const Color income = Color(0xFF059669);
  static const Color incomeLight = Color(0xFFECFDF5);

  static const Color expense = Color(0xFF64748B);
  static const Color expenseLight = Color(0xFFF1F5F9);

  static const Color crimson = Color(0xFF881337);
  static const Color crimsonLight = Color(0xFFFFE4E6);

  static const Color overspent = Color(0xFFDC2626);
  static const Color overspentLight = Color(0xFFFEE2E2);

  static const Color warning = Color(0xFFD97706);
  static const Color warningLight = Color(0xFFFEF3C7);

  // Surfaces
  static const Color background = Color(0xFFF9F9FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F3F7);

  // Typography
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textTertiary = Color(0xFF94A3B8);

  static const Color border = Color(0xFFE2E4E8);
  static const Color divider = Color(0xFFF1F5F9);
}

class AppColorsDark {
  // Brand / Luxury Gold Accent
  static const Color primary = Color(0xFFE5C158); // Champagne Gold
  static const Color primaryLight = Color(0xFF2A2312);
  static const Color primaryContainer = Color(0xFF3D3215);
  static const Color gold = Color(0xFFE5C158);

  // Velvet Crimson Accents
  static const Color crimson = Color(0xFF7B1123);
  static const Color crimsonLight = Color(0xFF3D0811);

  // Financial States
  static const Color income = Color(0xFF10B981); // Luminous Emerald
  static const Color incomeLight = Color(0xFF064E3B);

  static const Color expense = Color(0xFF94A3B8);
  static const Color expenseLight = Color(0xFF1A1A22);

  static const Color overspent = Color(0xFFF87171); // Velvet Coral Red
  static const Color overspentLight = Color(0xFF450A0A);

  static const Color warning = Color(0xFFFBBF24); // Warm Amber
  static const Color warningLight = Color(0xFF451A03);

  // Obsidian Surfaces
  static const Color background = Color(0xFF0B0B0E); // Matte Obsidian Black
  static const Color surface = Color(0xFF14141B); // Titanium / Elevated Obsidian
  static const Color surfaceVariant = Color(0xFF1E1E28);

  // Typography (Porcelain White)
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textTertiary = Color(0xFF64748B);

  static const Color border = Color(0xFF262633);
  static const Color divider = Color(0xFF181820);
}

class AppTheme {
  static const String fontFamily = 'Outfit';

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.surface,
        surfaceContainerLowest: AppColors.surface,
        surfaceContainerLow: AppColors.surfaceVariant,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.overspent),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: const TextStyle(color: AppColors.textTertiary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primaryLight,
        elevation: 4,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontFamily: fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            );
          }
          return const TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primary, size: 24);
          }
          return const IconThemeData(color: AppColors.textSecondary, size: 24);
        }),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: CircleBorder(),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceVariant,
        selectedColor: AppColors.primaryContainer,
        secondarySelectedColor: AppColors.primary,
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: AppColors.primary,
          selectedForegroundColor: Colors.white,
          backgroundColor: AppColors.surfaceVariant,
          foregroundColor: AppColors.textSecondary,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        indicatorColor: AppColors.primary,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        dividerColor: AppColors.border,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          color: Colors.white,
          fontSize: 14,
        ),
        actionTextColor: AppColors.gold,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: AppColorsDark.background,
      colorScheme: ColorScheme.fromSeed(
        brightness: Brightness.dark,
        seedColor: AppColorsDark.primary,
        primary: AppColorsDark.primary,
        onPrimary: Colors.black,
        surface: AppColorsDark.surface,
        onSurface: AppColorsDark.textPrimary,
        surfaceContainerLowest: AppColorsDark.background,
        surfaceContainerLow: AppColorsDark.surface,
        surfaceContainer: AppColorsDark.surface,
        surfaceContainerHigh: AppColorsDark.surfaceVariant,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontFamily: fontFamily, color: AppColorsDark.textPrimary),
        bodyMedium: TextStyle(fontFamily: fontFamily, color: AppColorsDark.textPrimary),
        bodySmall: TextStyle(fontFamily: fontFamily, color: AppColorsDark.textSecondary),
        titleLarge: TextStyle(fontFamily: fontFamily, color: AppColorsDark.textPrimary, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(fontFamily: fontFamily, color: AppColorsDark.textPrimary, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(fontFamily: fontFamily, color: AppColorsDark.textPrimary),
        labelLarge: TextStyle(fontFamily: fontFamily, color: AppColorsDark.textPrimary, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(fontFamily: fontFamily, color: AppColorsDark.textSecondary),
        labelSmall: TextStyle(fontFamily: fontFamily, color: AppColorsDark.textSecondary),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: AppColorsDark.textPrimary,
        iconColor: AppColorsDark.textSecondary,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: AppColorsDark.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: AppColorsDark.textSecondary,
          fontSize: 14,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColorsDark.border,
        thickness: 1,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColorsDark.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColorsDark.textPrimary,
        ),
        iconTheme: IconThemeData(color: AppColorsDark.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColorsDark.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColorsDark.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColorsDark.primary,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColorsDark.textPrimary,
          side: const BorderSide(color: AppColorsDark.border),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColorsDark.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColorsDark.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColorsDark.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColorsDark.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColorsDark.overspent),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: const TextStyle(color: AppColorsDark.textTertiary),
        labelStyle: const TextStyle(color: AppColorsDark.textSecondary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColorsDark.surface,
        indicatorColor: AppColorsDark.primaryLight,
        elevation: 4,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontFamily: fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColorsDark.primary,
            );
          }
          return const TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColorsDark.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColorsDark.primary, size: 24);
          }
          return const IconThemeData(
            color: AppColorsDark.textSecondary,
            size: 24,
          );
        }),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColorsDark.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titleTextStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColorsDark.textPrimary,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          color: AppColorsDark.textSecondary,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColorsDark.surface,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColorsDark.primary,
        foregroundColor: Colors.black,
        elevation: 3,
        shape: CircleBorder(),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColorsDark.surfaceVariant,
        selectedColor: AppColorsDark.primaryContainer,
        secondarySelectedColor: AppColorsDark.primary,
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColorsDark.textPrimary,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
        side: const BorderSide(color: AppColorsDark.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: AppColorsDark.primary,
          selectedForegroundColor: Colors.black,
          backgroundColor: AppColorsDark.surfaceVariant,
          foregroundColor: AppColorsDark.textSecondary,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
          side: const BorderSide(color: AppColorsDark.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        indicatorColor: AppColorsDark.primary,
        labelColor: AppColorsDark.primary,
        unselectedLabelColor: AppColorsDark.textSecondary,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        dividerColor: AppColorsDark.border,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColorsDark.surfaceVariant,
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          color: AppColorsDark.textPrimary,
          fontSize: 14,
        ),
        actionTextColor: AppColorsDark.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColorsDark.border),
        ),
      ),
    );
  }
}

extension ThemeContextExt on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get textPrimary =>
      isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
  Color get textSecondary =>
      isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;
  Color get textTertiary =>
      isDark ? AppColorsDark.textTertiary : AppColors.textTertiary;

  Color get surfaceColor => isDark ? AppColorsDark.surface : AppColors.surface;
  Color get surfaceVariantColor =>
      isDark ? AppColorsDark.surfaceVariant : AppColors.surfaceVariant;
  Color get backgroundColor =>
      isDark ? AppColorsDark.background : AppColors.background;
  Color get borderColor => isDark ? AppColorsDark.border : AppColors.border;

  Color get primaryColor => isDark ? AppColorsDark.primary : AppColors.primary;
  Color get primaryLightColor =>
      isDark ? AppColorsDark.primaryLight : AppColors.primaryLight;

  Color get goldColor => isDark ? AppColorsDark.gold : AppColors.gold;
  Color get crimsonColor => isDark ? AppColorsDark.crimson : AppColors.crimson;
  Color get crimsonLightColor =>
      isDark ? AppColorsDark.crimsonLight : AppColors.crimsonLight;

  Color get incomeColor => isDark ? AppColorsDark.income : AppColors.income;
  Color get incomeLightColor =>
      isDark ? AppColorsDark.incomeLight : AppColors.incomeLight;

  Color get expenseColor => isDark ? AppColorsDark.expense : AppColors.expense;
  Color get expenseLightColor =>
      isDark ? AppColorsDark.expenseLight : AppColors.expenseLight;

  Color get overspentColor =>
      isDark ? AppColorsDark.overspent : AppColors.overspent;
  Color get overspentLightColor =>
      isDark ? AppColorsDark.overspentLight : AppColors.overspentLight;

  Color get warningColor => isDark ? AppColorsDark.warning : AppColors.warning;
  Color get warningLightColor =>
      isDark ? AppColorsDark.warningLight : AppColors.warningLight;
}
