import 'package:flutter/material.dart';

/// Design System Theme Configuration
/// Strictly follows the provided UI design system
/// Do NOT introduce new colors, font sizes, spacing, or behaviors outside this system.

class AppTheme {
  AppTheme._();

  // ============ COLORS ============
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryHover = Color(0xFF4F46E5);
  static const Color primaryPressed = Color(0xFF4338CA);

  static const Color danger = Color(0xFFEF4444);
  static const Color dangerHover = Color(0xFFDC2626);
  static const Color dangerPressed = Color(0xFFB91C1C);

  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);

  static const Color background = Color(0xFFF8FAFC);
  static const Color cardBackground = Colors.white;

  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textDisabled = Color(0xFF94A3B8);

  static const Color border = Color(0xFFE2E8F0);
  static const Color disabledBackground = Color(0xFFF1F5F9);

  // ============ TYPOGRAPHY ============
  static const String fontFamily = 'Inter';

  // Font sizes
  static const double fontSizeHelper = 12.0;
  static const double fontSizeLabel = 14.0;
  static const double fontSizeBody = 16.0;
  static const double fontSizeSectionTitle = 18.0;
  static const double fontSizeCardHeader = 20.0;
  static const double fontSizePageHeader = 24.0;

  // Font weights
  static const FontWeight fontWeightRegular = FontWeight.w400;
  static const FontWeight fontWeightMedium = FontWeight.w500;
  static const FontWeight fontWeightSemibold = FontWeight.w600;
  static const FontWeight fontWeightBold = FontWeight.w700;

  // ============ SPACING ============
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;

  // ============ DIMENSIONS ============
  static const double buttonHeight = 40.0;
  static const double buttonRadius = 8.0;
  static const double inputHeight = 40.0;
  static const double inputRadius = 8.0;
  static const double cardRadius = 12.0;

  // ============ ANIMATION ============
  static const Duration animationDuration = Duration(milliseconds: 150);
  static const Curve animationCurve = Curves.easeInOut;

  // ============ BREAKPOINTS ============
  static const double breakpointMobile = 640.0;
  static const double breakpointTablet = 768.0;
  static const double breakpointSmallDesktop = 1024.0;

  // ============ RESPONSIVE HELPERS ============
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < breakpointMobile;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= breakpointMobile &&
      MediaQuery.of(context).size.width < breakpointTablet;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= breakpointTablet;

  // ============ TEXT STYLES ============
  static const TextStyle helperText = TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSizeHelper,
    fontWeight: fontWeightRegular,
    color: textSecondary,
  );

  static const TextStyle errorText = TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSizeHelper,
    fontWeight: fontWeightRegular,
    color: danger,
  );

  static const TextStyle labelText = TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSizeLabel,
    fontWeight: fontWeightMedium,
    color: textPrimary,
  );

  static const TextStyle bodyText = TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSizeBody,
    fontWeight: fontWeightRegular,
    color: textPrimary,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSizeSectionTitle,
    fontWeight: fontWeightSemibold,
    color: textPrimary,
  );

  static const TextStyle cardHeader = TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSizeCardHeader,
    fontWeight: fontWeightSemibold,
    color: textPrimary,
  );

  static const TextStyle pageHeader = TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSizePageHeader,
    fontWeight: fontWeightBold,
    color: textPrimary,
  );

  // ============ CARD DECORATION ============
  static BoxDecoration get cardDecoration => BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      );

  // ============ INPUT DECORATION ============
  static InputDecoration inputDecoration({
    required String label,
    String? hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? errorText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      errorText: errorText,
      labelStyle: const TextStyle(
        fontFamily: fontFamily,
        fontSize: fontSizeLabel,
        color: textSecondary,
      ),
      hintStyle: const TextStyle(
        fontFamily: fontFamily,
        fontSize: fontSizeBody,
        color: textDisabled,
      ),
      errorStyle: const TextStyle(
        fontFamily: fontFamily,
        fontSize: fontSizeHelper,
        color: danger,
      ),
      filled: true,
      fillColor: cardBackground,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: spacing16,
        vertical: spacing12,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputRadius),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputRadius),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputRadius),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputRadius),
        borderSide: const BorderSide(color: danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputRadius),
        borderSide: const BorderSide(color: danger, width: 2),
      ),
    );
  }

  // ============ BUTTON STYLES ============

  /// Primary elevated button style
  static ButtonStyle get primaryButtonStyle => ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.disabled)) {
            return disabledBackground;
          }
          if (states.contains(WidgetState.pressed)) {
            return primaryPressed;
          }
          if (states.contains(WidgetState.hovered)) {
            return primaryHover;
          }
          return primary;
        }),
        foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.disabled)) {
            return textDisabled;
          }
          return Colors.white;
        }),
        minimumSize: WidgetStateProperty.all(
          const Size(double.minPositive, buttonHeight),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: spacing16, vertical: spacing12),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
        ),
        elevation: WidgetStateProperty.all(0),
        textStyle: WidgetStateProperty.all(
          const TextStyle(
            fontFamily: fontFamily,
            fontSize: fontSizeBody,
            fontWeight: fontWeightSemibold,
          ),
        ),
      );

  /// Primary outlined button style
  static ButtonStyle get primaryOutlinedButtonStyle => ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.pressed)) {
            return primary.withValues(alpha: 0.1);
          }
          if (states.contains(WidgetState.hovered)) {
            return primary.withValues(alpha: 0.05);
          }
          return Colors.transparent;
        }),
        foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.disabled)) {
            return textDisabled;
          }
          return primary;
        }),
        side: WidgetStateProperty.resolveWith<BorderSide>((states) {
          if (states.contains(WidgetState.disabled)) {
            return const BorderSide(color: border);
          }
          return const BorderSide(color: primary);
        }),
        minimumSize: WidgetStateProperty.all(
          const Size(double.minPositive, buttonHeight),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: spacing16, vertical: spacing12),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
        ),
        elevation: WidgetStateProperty.all(0),
        textStyle: WidgetStateProperty.all(
          const TextStyle(
            fontFamily: fontFamily,
            fontSize: fontSizeBody,
            fontWeight: fontWeightSemibold,
          ),
        ),
      );

  /// Danger elevated button style
  static ButtonStyle get dangerButtonStyle => ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.disabled)) {
            return disabledBackground;
          }
          if (states.contains(WidgetState.pressed)) {
            return dangerPressed;
          }
          if (states.contains(WidgetState.hovered)) {
            return dangerHover;
          }
          return danger;
        }),
        foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.disabled)) {
            return textDisabled;
          }
          return Colors.white;
        }),
        minimumSize: WidgetStateProperty.all(
          const Size(double.minPositive, buttonHeight),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: spacing16, vertical: spacing12),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
        ),
        elevation: WidgetStateProperty.all(0),
        textStyle: WidgetStateProperty.all(
          const TextStyle(
            fontFamily: fontFamily,
            fontSize: fontSizeBody,
            fontWeight: fontWeightSemibold,
          ),
        ),
      );

  /// Danger outlined button style
  static ButtonStyle get dangerOutlinedButtonStyle => ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.pressed)) {
            return danger.withValues(alpha: 0.1);
          }
          if (states.contains(WidgetState.hovered)) {
            return danger.withValues(alpha: 0.05);
          }
          return Colors.transparent;
        }),
        foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.disabled)) {
            return textDisabled;
          }
          return danger;
        }),
        side: WidgetStateProperty.resolveWith<BorderSide>((states) {
          if (states.contains(WidgetState.disabled)) {
            return const BorderSide(color: border);
          }
          return const BorderSide(color: danger);
        }),
        minimumSize: WidgetStateProperty.all(
          const Size(double.minPositive, buttonHeight),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: spacing16, vertical: spacing12),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
        ),
        elevation: WidgetStateProperty.all(0),
        textStyle: WidgetStateProperty.all(
          const TextStyle(
            fontFamily: fontFamily,
            fontSize: fontSizeBody,
            fontWeight: fontWeightSemibold,
          ),
        ),
      );

  /// Success button style
  static ButtonStyle get successButtonStyle => ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.disabled)) {
            return disabledBackground;
          }
          if (states.contains(WidgetState.pressed)) {
            return const Color(0xFF16A34A);
          }
          if (states.contains(WidgetState.hovered)) {
            return const Color(0xFF15803D);
          }
          return success;
        }),
        foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.disabled)) {
            return textDisabled;
          }
          return Colors.white;
        }),
        minimumSize: WidgetStateProperty.all(
          const Size(double.minPositive, buttonHeight),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: spacing16, vertical: spacing12),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
        ),
        elevation: WidgetStateProperty.all(0),
        textStyle: WidgetStateProperty.all(
          const TextStyle(
            fontFamily: fontFamily,
            fontSize: fontSizeBody,
            fontWeight: fontWeightSemibold,
          ),
        ),
      );

  // ============ THEME DATA ============
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        fontFamily: fontFamily,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          primary: primary,
          secondary: primary,
          error: danger,
          surface: cardBackground,
          surfaceContainerHighest: background,
        ),
        scaffoldBackgroundColor: background,
        appBarTheme: const AppBarTheme(
          backgroundColor: cardBackground,
          foregroundColor: textPrimary,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontFamily: fontFamily,
            fontSize: fontSizeCardHeader,
            fontWeight: fontWeightSemibold,
            color: textPrimary,
          ),
          iconTheme: IconThemeData(color: textPrimary),
        ),
        cardTheme: CardThemeData(
          color: cardBackground,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(cardRadius),
            side: const BorderSide(color: border),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: primaryButtonStyle,
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: primaryOutlinedButtonStyle,
        ),
        textButtonTheme: TextButtonThemeData(
          style: ButtonStyle(
            foregroundColor: WidgetStateProperty.all(primary),
            textStyle: WidgetStateProperty.all(
              const TextStyle(
                fontFamily: fontFamily,
                fontSize: fontSizeBody,
                fontWeight: fontWeightSemibold,
              ),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: cardBackground,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: spacing16,
            vertical: spacing12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(inputRadius),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(inputRadius),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(inputRadius),
            borderSide: const BorderSide(color: primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(inputRadius),
            borderSide: const BorderSide(color: danger),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(inputRadius),
            borderSide: const BorderSide(color: danger, width: 2),
          ),
          labelStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: fontSizeLabel,
            color: textSecondary,
          ),
          hintStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: fontSizeBody,
            color: textDisabled,
          ),
          errorStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: fontSizeHelper,
            color: danger,
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: border,
          thickness: 1,
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
        ),
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(cardRadius),
          ),
          backgroundColor: cardBackground,
          titleTextStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: fontSizeCardHeader,
            fontWeight: fontWeightSemibold,
            color: textPrimary,
          ),
          contentTextStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: fontSizeBody,
            color: textSecondary,
          ),
        ),
        expansionTileTheme: ExpansionTileThemeData(
          backgroundColor: cardBackground,
          collapsedBackgroundColor: cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(cardRadius),
            side: const BorderSide(color: border),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(cardRadius),
            side: const BorderSide(color: border),
          ),
          iconColor: textSecondary,
          collapsedIconColor: textSecondary,
          textColor: textPrimary,
          collapsedTextColor: textPrimary,
        ),
        iconTheme: const IconThemeData(
          color: textSecondary,
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontFamily: fontFamily,
            fontSize: 32,
            fontWeight: fontWeightBold,
            color: textPrimary,
          ),
          headlineLarge: TextStyle(
            fontFamily: fontFamily,
            fontSize: fontSizePageHeader,
            fontWeight: fontWeightBold,
            color: textPrimary,
          ),
          headlineMedium: TextStyle(
            fontFamily: fontFamily,
            fontSize: fontSizeCardHeader,
            fontWeight: fontWeightSemibold,
            color: textPrimary,
          ),
          headlineSmall: TextStyle(
            fontFamily: fontFamily,
            fontSize: fontSizeSectionTitle,
            fontWeight: fontWeightSemibold,
            color: textPrimary,
          ),
          titleLarge: TextStyle(
            fontFamily: fontFamily,
            fontSize: fontSizeSectionTitle,
            fontWeight: fontWeightSemibold,
            color: textPrimary,
          ),
          titleMedium: TextStyle(
            fontFamily: fontFamily,
            fontSize: fontSizeBody,
            fontWeight: fontWeightMedium,
            color: textPrimary,
          ),
          titleSmall: TextStyle(
            fontFamily: fontFamily,
            fontSize: fontSizeLabel,
            fontWeight: fontWeightMedium,
            color: textPrimary,
          ),
          bodyLarge: TextStyle(
            fontFamily: fontFamily,
            fontSize: fontSizeBody,
            fontWeight: fontWeightRegular,
            color: textPrimary,
          ),
          bodyMedium: TextStyle(
            fontFamily: fontFamily,
            fontSize: fontSizeLabel,
            fontWeight: fontWeightRegular,
            color: textPrimary,
          ),
          bodySmall: TextStyle(
            fontFamily: fontFamily,
            fontSize: fontSizeHelper,
            fontWeight: fontWeightRegular,
            color: textSecondary,
          ),
          labelLarge: TextStyle(
            fontFamily: fontFamily,
            fontSize: fontSizeBody,
            fontWeight: fontWeightSemibold,
            color: textPrimary,
          ),
          labelMedium: TextStyle(
            fontFamily: fontFamily,
            fontSize: fontSizeLabel,
            fontWeight: fontWeightMedium,
            color: textPrimary,
          ),
          labelSmall: TextStyle(
            fontFamily: fontFamily,
            fontSize: fontSizeHelper,
            fontWeight: fontWeightMedium,
            color: textSecondary,
          ),
        ),
      );
}

/// Convenience extension for easier access to theme colors
extension BuildContextThemeExtensions on BuildContext {
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;
}
