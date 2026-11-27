import 'package:flutter/material.dart';

/// Paydial "Pine" theme.
///
/// Quiet neutral surfaces, near-black / near-white ink, and a single accent
/// (deep pine teal) that also marks money coming in. Every other colour has a
/// job: brick red = overspent, amber = warning, steel blue = savings. No
/// gradients, glows or tinted shadows; depth comes from hairline borders.
///
/// Light and dark share one builder ([AppTheme._build]) so the two modes can
/// never drift apart and AnimatedTheme can always interpolate between them.
class AppColors {
  // Accent: Pine (6.4:1 on white, white text on it passes AA)
  static const Color primary = Color(0xFF0F6B5C);
  static const Color primaryLight = Color(0xFFE6F1EE); // Selected / tinted surfaces
  static const Color primaryContainer = Color(0xFFD2E7E1);

  // Savings & vault: steel blue
  static const Color savings = Color(0xFF2D5F8A);
  static const Color savingsLight = Color(0xFFE7EEF5);

  // Financial states
  static const Color income = Color(0xFF0F6B5C);
  static const Color incomeLight = Color(0xFFE6F1EE);

  static const Color expense = Color(0xFF565B61);
  static const Color expenseLight = Color(0xFFF0F0EC);

  static const Color overspent = Color(0xFFBF3A2C);
  static const Color overspentLight = Color(0xFFFBECEA);

  static const Color warning = Color(0xFF9E5700);
  static const Color warningLight = Color(0xFFFBF1E1);

  // Surfaces
  static const Color background = Color(0xFFF6F6F3);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color dialogSurface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFEFEFEB);
  static const Color inputFill = Color(0xFFF3F3EF);

  // Typography
  static const Color textPrimary = Color(0xFF15171A);
  static const Color textSecondary = Color(0xFF565B61); // ~6.9:1 on white
  static const Color textTertiary = Color(0xFF6B7076); // ~5.0:1 on white

  static const Color border = Color(0xFFE4E4DF);
  static const Color inputBorder = Color(0xFFD4D4CE);
  static const Color divider = Color(0xFFECECE7);
}

class AppColorsDark {
  // Accent: light pine (~7.4:1 on the dialog surface)
  static const Color primary = Color(0xFF66D1B9);
  static const Color primaryLight = Color(0xFF1F3D37);
  static const Color primaryContainer = Color(0xFF25493F);

  // Savings & vault: steel blue
  static const Color savings = Color(0xFF8DB8E0);
  static const Color savingsLight = Color(0xFF22344A);

  // Financial states
  static const Color income = Color(0xFF66D1B9);
  static const Color incomeLight = Color(0xFF1F3D37);

  static const Color expense = Color(0xFFAEB4BA);
  static const Color expenseLight = Color(0xFF2A2E33);

  static const Color overspent = Color(0xFFF07A6E);
  static const Color overspentLight = Color(0xFF45241F);

  static const Color warning = Color(0xFFF0B157);
  static const Color warningLight = Color(0xFF43331A);

  // Charcoal surfaces (soft, neutral, not blue-tinted, not near-black)
  static const Color background = Color(0xFF1A1D20);
  static const Color surface = Color(0xFF23272B);
  static const Color dialogSurface = Color(0xFF2A2E33);
  static const Color surfaceVariant = Color(0xFF30353A);
  static const Color inputFill = Color(0xFF1E2124); // recessed well

  // Typography
  static const Color textPrimary = Color(0xFFEEF0F2);
  static const Color textSecondary = Color(0xFFAEB4BA); // ~7.7:1 on inputFill
  static const Color textTertiary = Color(0xFF959CA3); // ~5.8:1 on inputFill

  static const Color border = Color(0xFF363B40);
  static const Color inputBorder = Color(0xFF474D53);
  static const Color divider = Color(0xFF2E3237);
}

/// One mode's colours, so both themes come out of the same builder.
class _Palette {
  final Brightness brightness;
  final Color primary;
  final Color onPrimary;
  final Color primaryLight;
  final Color primaryContainer;
  final Color background;
  final Color surface;
  final Color dialogSurface;
  final Color surfaceVariant;
  final Color inputFill;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color border;
  final Color inputBorder;
  final Color divider;
  final Color error;
  final Color snackBackground;
  final Color snackText;
  final Color snackAction;

  const _Palette({
    required this.brightness,
    required this.primary,
    required this.onPrimary,
    required this.primaryLight,
    required this.primaryContainer,
    required this.background,
    required this.surface,
    required this.dialogSurface,
    required this.surfaceVariant,
    required this.inputFill,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.border,
    required this.inputBorder,
    required this.divider,
    required this.error,
    required this.snackBackground,
    required this.snackText,
    required this.snackAction,
  });
}

const _light = _Palette(
  brightness: Brightness.light,
  primary: AppColors.primary,
  onPrimary: Colors.white,
  primaryLight: AppColors.primaryLight,
  primaryContainer: AppColors.primaryContainer,
  background: AppColors.background,
  surface: AppColors.surface,
  dialogSurface: AppColors.dialogSurface,
  surfaceVariant: AppColors.surfaceVariant,
  inputFill: AppColors.inputFill,
  textPrimary: AppColors.textPrimary,
  textSecondary: AppColors.textSecondary,
  textTertiary: AppColors.textTertiary,
  border: AppColors.border,
  inputBorder: AppColors.inputBorder,
  divider: AppColors.divider,
  error: AppColors.overspent,
  snackBackground: AppColors.textPrimary,
  snackText: Colors.white,
  snackAction: AppColorsDark.primary,
);

const _dark = _Palette(
  brightness: Brightness.dark,
  primary: AppColorsDark.primary,
  onPrimary: Color(0xFF06201B),
  primaryLight: AppColorsDark.primaryLight,
  primaryContainer: AppColorsDark.primaryContainer,
  background: AppColorsDark.background,
  surface: AppColorsDark.surface,
  dialogSurface: AppColorsDark.dialogSurface,
  surfaceVariant: AppColorsDark.surfaceVariant,
  inputFill: AppColorsDark.inputFill,
  textPrimary: AppColorsDark.textPrimary,
  textSecondary: AppColorsDark.textSecondary,
  textTertiary: AppColorsDark.textTertiary,
  border: AppColorsDark.border,
  inputBorder: AppColorsDark.inputBorder,
  divider: AppColorsDark.divider,
  error: AppColorsDark.overspent,
  snackBackground: Color(0xFFEDEEEF),
  snackText: Color(0xFF15171A),
  snackAction: AppColors.primary,
);

class AppTheme {
  static const String fontFamily = 'Outfit';

  /// Corner radii used across the app.
  static const double radiusSmall = 10;
  static const double radius = 14;
  static const double radiusLarge = 20;

  static ThemeData get lightTheme => _build(_light);
  static ThemeData get darkTheme => _build(_dark);

  static ThemeData _build(_Palette p) {
    final isDark = p.brightness == Brightness.dark;
    TextStyle t(double size, FontWeight weight, Color color,
            {double? spacing, double? height}) =>
        TextStyle(
          fontFamily: fontFamily,
          fontSize: size,
          fontWeight: weight,
          color: color,
          letterSpacing: spacing,
          height: height,
        );

    OutlineInputBorder inputBorder(Color color, double width) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: color, width: width),
        );

    final roundedShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      splashFactory: InkSparkle.splashFactory,
      colorScheme: ColorScheme.fromSeed(
        brightness: p.brightness,
        seedColor: p.primary,
        primary: p.primary,
        onPrimary: p.onPrimary,
        primaryContainer: p.primaryContainer,
        onPrimaryContainer: p.textPrimary,
        secondary: p.primary,
        onSecondary: p.onPrimary,
        secondaryContainer: p.primaryLight,
        onSecondaryContainer: p.textPrimary,
        tertiary: isDark ? AppColorsDark.savings : AppColors.savings,
        error: p.error,
        surface: p.surface,
        onSurface: p.textPrimary,
        onSurfaceVariant: p.textSecondary,
        surfaceTint: Colors.transparent,
        surfaceContainerLowest: isDark ? p.background : p.surface,
        surfaceContainerLow: isDark ? p.surface : p.background,
        surfaceContainer: p.surface,
        surfaceContainerHigh: p.surfaceVariant,
        surfaceContainerHighest: p.surfaceVariant,
        outline: p.inputBorder,
        outlineVariant: p.border,
        inverseSurface: p.snackBackground,
        onInverseSurface: p.snackText,
        inversePrimary: p.snackAction,
        shadow: Colors.black,
        scrim: Colors.black,
      ),
      textTheme: TextTheme(
        displaySmall: t(34, FontWeight.w700, p.textPrimary, spacing: -0.8),
        headlineLarge: t(30, FontWeight.w700, p.textPrimary, spacing: -0.6),
        headlineMedium: t(26, FontWeight.w700, p.textPrimary, spacing: -0.5),
        headlineSmall: t(22, FontWeight.w700, p.textPrimary, spacing: -0.3),
        titleLarge: t(20, FontWeight.w700, p.textPrimary, spacing: -0.2),
        titleMedium: t(16, FontWeight.w600, p.textPrimary),
        titleSmall: t(14, FontWeight.w600, p.textPrimary),
        bodyLarge: t(16, FontWeight.w400, p.textPrimary, height: 1.4),
        bodyMedium: t(14, FontWeight.w400, p.textPrimary, height: 1.4),
        bodySmall: t(12, FontWeight.w400, p.textSecondary, height: 1.35),
        labelLarge: t(14, FontWeight.w600, p.textPrimary),
        labelMedium: t(12, FontWeight.w500, p.textSecondary),
        labelSmall: t(11, FontWeight.w500, p.textSecondary, spacing: 0.2),
      ),
      iconTheme: IconThemeData(color: p.textSecondary, size: 22),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.primary,
        selectionColor: p.primary.withValues(alpha: isDark ? 0.3 : 0.2),
        selectionHandleColor: p.primary,
      ),
      listTileTheme: ListTileThemeData(
        textColor: p.textPrimary,
        iconColor: p.textSecondary,
        shape: roundedShape,
        titleTextStyle: t(15.5, FontWeight.w600, p.textPrimary),
        subtitleTextStyle: t(13.5, FontWeight.w400, p.textSecondary),
      ),
      dividerTheme: DividerThemeData(color: p.divider, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: t(20, FontWeight.w700, p.textPrimary, spacing: -0.2),
        iconTheme: IconThemeData(color: p.textPrimary),
        actionsIconTheme: IconThemeData(color: p.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge - 4),
          side: BorderSide(color: p.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          elevation: 0,
          minimumSize: const Size(64, 50),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: roundedShape,
          textStyle: t(15.5, FontWeight.w600, p.onPrimary),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          minimumSize: const Size(64, 50),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: roundedShape,
          textStyle: t(15.5, FontWeight.w600, p.onPrimary),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          side: BorderSide(color: p.inputBorder),
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: roundedShape,
          textStyle: t(15, FontWeight.w600, p.textPrimary),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        // No textStyle override: the default (textTheme.labelLarge) already
        // matches, and both themes leave it unset so they interpolate.
        style: TextButton.styleFrom(
          foregroundColor: p.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: p.textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.inputFill,
        border: inputBorder(p.inputBorder, 1),
        enabledBorder: inputBorder(p.inputBorder, 1),
        disabledBorder: inputBorder(p.border, 1),
        focusedBorder: inputBorder(p.primary, 1.6),
        errorBorder: inputBorder(p.error, 1.4),
        focusedErrorBorder: inputBorder(p.error, 1.8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: t(15, FontWeight.w500, p.textSecondary),
        floatingLabelStyle: t(14, FontWeight.w600, p.primary),
        hintStyle: t(15, FontWeight.w400, p.textTertiary),
        helperStyle: t(12.5, FontWeight.w400, p.textSecondary),
        errorStyle: t(12.5, FontWeight.w500, p.error),
        prefixStyle: t(16, FontWeight.w600, p.textPrimary),
        suffixStyle: t(15, FontWeight.w600, p.textSecondary),
        prefixIconColor: p.textSecondary,
        suffixIconColor: p.textSecondary,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.dialogSurface,
        surfaceTintColor: Colors.transparent,
        elevation: isDark ? 8 : 3,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.6 : 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge + 4),
          side: BorderSide(color: p.border, width: 1),
        ),
        titleTextStyle: t(19, FontWeight.w700, p.textPrimary, spacing: -0.2),
        contentTextStyle: t(14, FontWeight.w400, p.textPrimary, height: 1.45),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.dialogSurface,
        modalBackgroundColor: p.dialogSurface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        dragHandleColor: p.inputBorder,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusLarge + 4)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.dialogSurface,
        surfaceTintColor: Colors.transparent,
        elevation: isDark ? 6 : 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: p.border),
        ),
        textStyle: t(14.5, FontWeight.w500, p.textPrimary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        indicatorColor: p.primaryLight,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return t(
            12,
            selected ? FontWeight.w700 : FontWeight.w500,
            selected ? p.primary : p.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? p.primary
                : p.textSecondary,
            size: 24,
          );
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        elevation: isDark ? 2 : 1,
        highlightElevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge - 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        selectedColor: p.primaryLight,
        secondarySelectedColor: p.primary,
        checkmarkColor: p.primary,
        labelStyle: t(12.5, FontWeight.w500, p.textPrimary),
        secondaryLabelStyle: t(12.5, FontWeight.w600, p.onPrimary),
        side: BorderSide(color: p.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: p.primaryLight,
          selectedForegroundColor: p.primary,
          backgroundColor: p.surface,
          foregroundColor: p.textSecondary,
          textStyle: t(13, FontWeight.w600, p.textPrimary),
          side: BorderSide(color: p.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius - 2),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return p.onPrimary;
          return p.textTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return p.primary;
          return p.surfaceVariant;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.transparent;
          return p.inputBorder;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return p.primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(p.onPrimary),
        side: BorderSide(color: p.inputBorder, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return p.primary;
          return p.textTertiary;
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.primary,
        linearTrackColor: p.surfaceVariant,
        circularTrackColor: p.surfaceVariant,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.primary,
        inactiveTrackColor: p.surfaceVariant,
        thumbColor: p.primary,
        overlayColor: p.primary.withValues(alpha: 0.12),
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: p.primary,
        labelColor: p.primary,
        unselectedLabelColor: p.textSecondary,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: t(13, FontWeight.w700, p.primary),
        unselectedLabelStyle: t(13, FontWeight.w500, p.textSecondary),
        dividerColor: p.border,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.snackBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: t(12, FontWeight.w500, p.snackText),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.snackBackground,
        contentTextStyle: t(14, FontWeight.w500, p.snackText),
        actionTextColor: p.snackAction,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: p.dialogSurface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: p.dialogSurface,
        headerForegroundColor: p.textPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge + 4),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: p.dialogSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge + 4),
        ),
      ),
    );
  }

  /// Category colours for charts: distinct hues at even lightness, no purple.
  static const List<Color> chartPaletteLight = [
    Color(0xFF0F6B5C), // pine
    Color(0xFF2D5F8A), // steel blue
    Color(0xFFC0762A), // ochre
    Color(0xFFB5473A), // brick
    Color(0xFF5E7D3A), // olive
    Color(0xFF3C8DA8), // lagoon
    Color(0xFF8A6D3B), // walnut
    Color(0xFF6B7580), // slate
  ];

  static const List<Color> chartPaletteDark = [
    Color(0xFF66D1B9), // pine
    Color(0xFF8DB8E0), // steel blue
    Color(0xFFE8A867), // ochre
    Color(0xFFEF8A7C), // brick
    Color(0xFFA9C77A), // olive
    Color(0xFF7CCBE3), // lagoon
    Color(0xFFD4B483), // walnut
    Color(0xFFAAB3BC), // slate
  ];
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
  Color get dialogSurfaceColor =>
      isDark ? AppColorsDark.dialogSurface : AppColors.dialogSurface;
  Color get surfaceVariantColor =>
      isDark ? AppColorsDark.surfaceVariant : AppColors.surfaceVariant;
  Color get backgroundColor =>
      isDark ? AppColorsDark.background : AppColors.background;
  Color get borderColor => isDark ? AppColorsDark.border : AppColors.border;
  Color get dividerColor => isDark ? AppColorsDark.divider : AppColors.divider;

  Color get primaryColor => isDark ? AppColorsDark.primary : AppColors.primary;

  /// Text/icon color on a [primaryColor] background.
  Color get onPrimaryColor =>
      isDark ? const Color(0xFF06201B) : Colors.white;
  Color get primaryLightColor =>
      isDark ? AppColorsDark.primaryLight : AppColors.primaryLight;

  /// Interactive / highlight accent (same as [primaryColor]).
  Color get accentColor => primaryColor;

  /// Savings & vault accent.
  Color get savingsColor => isDark ? AppColorsDark.savings : AppColors.savings;
  /// Text/icon color on a [savingsColor] background.
  Color get onSavingsColor =>
      isDark ? const Color(0xFF0C1A27) : Colors.white;
  Color get savingsLightColor =>
      isDark ? AppColorsDark.savingsLight : AppColors.savingsLight;

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

  /// Text/icon color on an [overspentColor] background (delete swipes,
  /// destructive buttons).
  Color get onOverspentColor =>
      isDark ? const Color(0xFF2A0E0B) : Colors.white;

  Color get warningColor => isDark ? AppColorsDark.warning : AppColors.warning;
  Color get warningLightColor =>
      isDark ? AppColorsDark.warningLight : AppColors.warningLight;

  /// Category chart colours for the current mode.
  List<Color> get chartPalette =>
      isDark ? AppTheme.chartPaletteDark : AppTheme.chartPaletteLight;
}
