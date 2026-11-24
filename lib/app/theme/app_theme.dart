import 'package:flutter/material.dart';

class AppColors {
  // "Paper & ink" light palette: warm neutral paper, near-black ink as the
  // primary colour, and colour reserved for meaning (money in/out, alerts).
  // All text colours meet WCAG AA on white and on the paper background.
  static const Color primary = Color(0xFF1B1B18); // Ink (17:1 on white)
  static const Color primaryLight = Color(0xFFEFEEE9); // Selected / tinted surfaces
  static const Color primaryContainer = Color(0xFFE6E4DE);
  static const Color gold = Color(0xFF8F6A1C); // Brand gold, used sparingly (savings)

  // Financial states
  static const Color income = Color(0xFF12715A);
  static const Color incomeLight = Color(0xFFE7F2EC);

  static const Color expense = Color(0xFF5C5B56);
  static const Color expenseLight = Color(0xFFF0EFEA);

  static const Color crimson = Color(0xFF8E2A3A);
  static const Color crimsonLight = Color(0xFFF7E8EA);

  static const Color overspent = Color(0xFFC2372B);
  static const Color overspentLight = Color(0xFFFAECE9);

  static const Color warning = Color(0xFF9A5A06);
  static const Color warningLight = Color(0xFFFAF0DF);

  // Surfaces
  static const Color background = Color(0xFFF7F6F2); // Paper
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFEFEEE9);
  static const Color inputFill = Color(0xFFF4F3EF);

  // Typography
  static const Color textPrimary = Color(0xFF1B1B18);
  static const Color textSecondary = Color(0xFF5C5B56); // 6.8:1 on white
  static const Color textTertiary = Color(0xFF6F6E68); // 5.0:1 on white

  static const Color border = Color(0xFFE4E2DC);
  static const Color inputBorder = Color(0xFFD6D4CD);
  static const Color divider = Color(0xFFECEAE5);
}

class AppColorsDark {
  // Brand / Luxury Champagne Gold Accent
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

  static const Color expense = Color(0xFFA8B3C5);
  static const Color expenseLight = Color(0xFF1A1A22);

  static const Color overspent = Color(0xFFF87171); // Velvet Coral Red
  static const Color overspentLight = Color(0xFF450A0A);

  static const Color warning = Color(0xFFFBBF24); // Warm Amber
  static const Color warningLight = Color(0xFF451A03);

  // Obsidian Surfaces
  static const Color background = Color(0xFF0B0B0E); // Matte Obsidian Black
  static const Color surface = Color(0xFF14141B); // Titanium / Elevated Obsidian
  static const Color dialogSurface = Color(0xFF171721); // Lifted Dialog Obsidian
  static const Color surfaceVariant = Color(0xFF1E1E28);
  static const Color inputFill = Color(0xFF0E0E14); // Deep recessed well for crisp input contrast

  // Typography (Crisp Porcelain White - AA/AAA compliant)
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFFB0BACB); // ~9.5:1 on surface
  static const Color textTertiary = Color(0xFF8592A6); // ~5.4:1 on inputFill

  static const Color border = Color(0xFF282836);
  static const Color inputBorder = Color(0xFF3C3F52);
  static const Color divider = Color(0xFF1A1A24);
}

class AppTheme {
  static const String fontFamily = 'Outfit';

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        brightness: Brightness.light,
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        surfaceContainerLowest: AppColors.surface,
        surfaceContainerLow: AppColors.surfaceVariant,
        surfaceContainer: AppColors.surface,
        surfaceContainerHigh: AppColors.surfaceVariant,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(
          fontFamily: fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          color: AppColors.textPrimary,
        ),
        bodySmall: TextStyle(
          fontFamily: fontFamily,
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
        titleLarge: TextStyle(
          fontFamily: fontFamily,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: TextStyle(
          fontFamily: fontFamily,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: TextStyle(
          fontFamily: fontFamily,
          color: AppColors.textPrimary,
        ),
        labelLarge: TextStyle(
          fontFamily: fontFamily,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: TextStyle(
          fontFamily: fontFamily,
          color: AppColors.textSecondary,
        ),
        labelSmall: TextStyle(
          fontFamily: fontFamily,
          color: AppColors.textSecondary,
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionColor: AppColors.primary.withValues(alpha: 0.22),
        selectionHandleColor: AppColors.primary,
      ),
      listTileTheme: const ListTileThemeData(
        textColor: AppColors.textPrimary,
        iconColor: AppColors.textSecondary,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: AppColors.textSecondary,
          fontSize: 14,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
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
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
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
          side: const BorderSide(color: AppColors.inputBorder),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        // No textStyle override: the default (textTheme.labelLarge, Outfit
        // w600) already matches, and a partial style here would differ from
        // the dark theme's and break the light <-> dark theme animation.
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.inputBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.inputBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.overspent, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.overspent, width: 2.0),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          color: AppColors.textSecondary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        floatingLabelStyle: const TextStyle(
          fontFamily: fontFamily,
          color: AppColors.primary,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: const TextStyle(
          fontFamily: fontFamily,
          color: AppColors.textTertiary,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        helperStyle: const TextStyle(
          fontFamily: fontFamily,
          color: AppColors.textSecondary,
          fontSize: 12.5,
        ),
        errorStyle: const TextStyle(
          fontFamily: fontFamily,
          color: AppColors.overspent,
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
        ),
        prefixStyle: const TextStyle(
          fontFamily: fontFamily,
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        suffixStyle: const TextStyle(
          fontFamily: fontFamily,
          color: AppColors.textSecondary,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 19,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          color: AppColors.textPrimary,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
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
        elevation: 1,
        highlightElevation: 2,
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
          // iOS-style segmented control: white "thumb" on a paper track.
          selectedBackgroundColor: AppColors.surface,
          selectedForegroundColor: AppColors.textPrimary,
          backgroundColor: AppColors.surfaceVariant,
          foregroundColor: AppColors.textPrimary,
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
        actionTextColor: Color(0xFFE9D3A0),
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
        bodyLarge: TextStyle(
          fontFamily: fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        bodyMedium: TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          color: AppColorsDark.textPrimary,
        ),
        bodySmall: TextStyle(
          fontFamily: fontFamily,
          fontSize: 12,
          color: AppColorsDark.textSecondary,
        ),
        titleLarge: TextStyle(
          fontFamily: fontFamily,
          color: AppColorsDark.textPrimary,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: TextStyle(
          fontFamily: fontFamily,
          color: AppColorsDark.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: TextStyle(
          fontFamily: fontFamily,
          color: AppColorsDark.textPrimary,
        ),
        labelLarge: TextStyle(
          fontFamily: fontFamily,
          color: AppColorsDark.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: TextStyle(
          fontFamily: fontFamily,
          color: AppColorsDark.textSecondary,
        ),
        labelSmall: TextStyle(
          fontFamily: fontFamily,
          color: AppColorsDark.textSecondary,
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColorsDark.primary,
        selectionColor: AppColorsDark.primary.withValues(alpha: 0.28),
        selectionHandleColor: AppColorsDark.primary,
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
        surfaceTintColor: Colors.transparent,
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
        surfaceTintColor: Colors.transparent,
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
          side: const BorderSide(color: AppColorsDark.inputBorder),
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
        fillColor: AppColorsDark.inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColorsDark.inputBorder, width: 1.4),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColorsDark.inputBorder, width: 1.4),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColorsDark.primary, width: 2.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColorsDark.overspent, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColorsDark.overspent, width: 2.0),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          color: Color(0xFFCBD5E1),
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        floatingLabelStyle: const TextStyle(
          fontFamily: fontFamily,
          color: AppColorsDark.primary,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: const TextStyle(
          fontFamily: fontFamily,
          color: AppColorsDark.textTertiary,
          fontSize: 15,
        ),
        helperStyle: const TextStyle(
          fontFamily: fontFamily,
          color: AppColorsDark.textSecondary,
          fontSize: 12.5,
        ),
        errorStyle: const TextStyle(
          fontFamily: fontFamily,
          color: AppColorsDark.overspent,
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
        ),
        prefixStyle: const TextStyle(
          fontFamily: fontFamily,
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        suffixStyle: const TextStyle(
          fontFamily: fontFamily,
          color: Color(0xFFE2E8F0),
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
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
        backgroundColor: AppColorsDark.dialogSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColorsDark.border, width: 1.2),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 19,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          color: AppColorsDark.textPrimary,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColorsDark.surface,
        surfaceTintColor: Colors.transparent,
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
          foregroundColor: AppColorsDark.textPrimary,
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
  /// Text/icon color on a [primaryColor] background: white on light-mode ink,
  /// black on dark-mode gold (white on gold fails contrast).
  Color get onPrimaryColor => isDark ? Colors.black : Colors.white;
  Color get primaryLightColor =>
      isDark ? AppColorsDark.primaryLight : AppColors.primaryLight;

  Color get goldColor => isDark ? AppColorsDark.gold : AppColors.gold;

  /// Interactive / highlight accent: champagne gold in dark mode, ink in light.
  Color get accentColor => isDark ? AppColorsDark.gold : AppColors.primary;

  /// Savings & vault accent: the brand gold in both modes.
  Color get savingsColor => isDark ? AppColorsDark.gold : AppColors.gold;
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
