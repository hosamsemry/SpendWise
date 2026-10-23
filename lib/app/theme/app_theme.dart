import 'package:flutter/material.dart';

class AppColors {
  // Brand / Primary
  static const Color primary = Color(0xFF0F5132);
  static const Color primaryLight = Color(0xFFE8F5E9);
  static const Color primaryContainer = Color(0xFF2E7D32);

  // Financial States
  static const Color income = Color(0xFF16A34A);
  static const Color incomeLight = Color(0xFFDCFCE7);

  static const Color expense = Color(0xFF475569);
  static const Color expenseLight = Color(0xFFF1F5F9);

  static const Color overspent = Color(0xFFDC2626);
  static const Color overspentLight = Color(0xFFFEE2E2);

  static const Color warning = Color(0xFFD97706);
  static const Color warningLight = Color(0xFFFEF3C7);

  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F5F9);

  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textTertiary = Color(0xFF94A3B8);

  static const Color border = Color(0xFFE2E8F0);
  static const Color divider = Color(0xFFF1F5F9);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
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
          borderRadius: BorderRadius.circular(16),
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
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
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
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            );
          }
          return const TextStyle(
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
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
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
        bodyLarge: TextStyle(color: AppColorsDark.textPrimary),
        bodyMedium: TextStyle(color: AppColorsDark.textPrimary),
        bodySmall: TextStyle(color: AppColorsDark.textSecondary),
        titleLarge: TextStyle(color: AppColorsDark.textPrimary, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: AppColorsDark.textPrimary, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(color: AppColorsDark.textPrimary),
        labelLarge: TextStyle(color: AppColorsDark.textPrimary, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(color: AppColorsDark.textSecondary),
        labelSmall: TextStyle(color: AppColorsDark.textSecondary),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: AppColorsDark.textPrimary,
        iconColor: AppColorsDark.textSecondary,
        titleTextStyle: TextStyle(
          color: AppColorsDark.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: TextStyle(
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
          borderRadius: BorderRadius.circular(16),
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
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColorsDark.textPrimary,
          side: const BorderSide(color: AppColorsDark.border),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColorsDark.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColorsDark.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColorsDark.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColorsDark.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
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
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColorsDark.primary,
            );
          }
          return const TextStyle(
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColorsDark.textPrimary,
        ),
        contentTextStyle: const TextStyle(
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
    );
  }
}

class AppColorsDark {
  // Brand / Primary
  static const Color primary = Color(0xFF22C55E); // Crisp Emerald 500
  static const Color primaryLight = Color(0xFF14532D); // Deep emerald container
  static const Color primaryContainer = Color(0xFF166534);

  // Financial States
  static const Color income = Color(0xFF4ADE80); // Bright Mint/Green
  static const Color incomeLight = Color(0xFF14532D);

  static const Color expense = Color(0xFF94A3B8);
  static const Color expenseLight = Color(0xFF1E293B);

  static const Color overspent = Color(0xFFF87171); // Soft Coral Red
  static const Color overspentLight = Color(0xFF450A0A);

  static const Color warning = Color(0xFFFBBF24); // Warm Amber
  static const Color warningLight = Color(0xFF451A03);

  static const Color background = Color(0xFF0F172A); // Deep Slate Navy
  static const Color surface = Color(0xFF1E293B); // Elevated Slate Surface
  static const Color surfaceVariant = Color(0xFF334155);

  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textTertiary = Color(0xFF64748B);

  static const Color border = Color(0xFF334155);
  static const Color divider = Color(0xFF1E293B);
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
