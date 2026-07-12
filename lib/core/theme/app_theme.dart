import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

/// Material 3 themes built from [AppTokens].
abstract final class AppTheme {
  static const String uiFont = 'Inter';
  static const String monoFont = 'JetBrainsMono';

  static ThemeData light() => _build(AppTokens.light, Brightness.light);
  static ThemeData dark() => _build(AppTokens.dark, Brightness.dark);

  static ThemeData _build(AppTokens t, Brightness brightness) {
    final ColorScheme scheme = ColorScheme(
      brightness: brightness,
      primary: t.primary,
      onPrimary: t.onPrimary,
      primaryContainer: t.primarySubtle,
      onPrimaryContainer: t.onPrimarySubtle,
      secondary: t.textSecondary,
      onSecondary: t.surface,
      error: t.danger,
      onError: brightness == Brightness.light ? Colors.white : t.background,
      errorContainer: t.dangerSubtle,
      onErrorContainer: t.danger,
      surface: t.surface,
      onSurface: t.textPrimary,
      surfaceContainerHighest: t.surfaceSunken,
      onSurfaceVariant: t.textSecondary,
      outline: t.border,
      outlineVariant: t.border,
      shadow: t.shadow,
      scrim: Colors.black54,
      inverseSurface: t.textPrimary,
      onInverseSurface: t.surface,
      inversePrimary: t.primarySubtle,
      surfaceTint: Colors.transparent,
    );

    final TextTheme text = _textTheme(t);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: uiFont,
      scaffoldBackgroundColor: t.background,
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      extensions: <ThemeExtension<dynamic>>[t],
      appBarTheme: AppBarTheme(
        backgroundColor: t.background,
        foregroundColor: t.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        systemOverlayStyle: brightness == Brightness.light
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
      ),
      cardTheme: CardTheme(
        color: t.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: t.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: t.border, thickness: 1, space: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: t.primary,
          foregroundColor: t.onPrimary,
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(
            fontFamily: uiFont,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.textPrimary,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: t.borderStrong),
          textStyle: const TextStyle(
            fontFamily: uiFont,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.primary,
          textStyle: const TextStyle(
            fontFamily: uiFont,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        hintStyle: TextStyle(color: t.textTertiary, fontSize: 15),
        labelStyle: TextStyle(color: t.textSecondary, fontSize: 15),
        helperStyle: TextStyle(color: t.textTertiary, fontSize: 13),
        errorStyle: TextStyle(color: t.danger, fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: t.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: t.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: t.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: t.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: t.danger, width: 2),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? t.onPrimary
              : t.textTertiary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? t.primary
              : t.surfaceSunken,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : t.borderStrong,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: t.surfaceSunken,
        selectedColor: t.primarySubtle,
        labelStyle: TextStyle(
          fontFamily: uiFont,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: t.textPrimary,
        ),
        side: BorderSide(color: t.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.surfaceRaised,
        modalBackgroundColor: t.surfaceRaised,
        showDragHandle: true,
        dragHandleColor: t.borderStrong,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: t.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: t.surface,
        indicatorColor: t.primarySubtle,
        height: 68,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? t.onPrimarySubtle
                : t.textTertiary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: uiFont,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? t.textPrimary
                : t.textTertiary,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: t.textPrimary,
        contentTextStyle: TextStyle(
          fontFamily: uiFont,
          fontSize: 14,
          color: t.surface,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: t.textSecondary,
        textColor: t.textPrimary,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.primary,
        linearTrackColor: t.surfaceSunken,
        circularTrackColor: t.surfaceSunken,
      ),
      tabBarTheme: TabBarTheme(
        labelColor: t.textPrimary,
        unselectedLabelColor: t.textTertiary,
        indicatorColor: t.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: t.border,
        labelStyle: const TextStyle(
          fontFamily: uiFont,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: uiFont,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  static TextTheme _textTheme(AppTokens t) {
    TextStyle s(double size, FontWeight w, Color c, {double? ls, double? h}) =>
        TextStyle(
          fontFamily: uiFont,
          fontSize: size,
          fontWeight: w,
          color: c,
          letterSpacing: ls,
          height: h,
        );

    return TextTheme(
      displayLarge: s(40, FontWeight.w700, t.textPrimary, ls: -1.2, h: 1.1),
      displayMedium: s(34, FontWeight.w700, t.textPrimary, ls: -1.0, h: 1.15),
      displaySmall: s(28, FontWeight.w700, t.textPrimary, ls: -0.8, h: 1.2),
      headlineLarge: s(24, FontWeight.w700, t.textPrimary, ls: -0.5, h: 1.25),
      headlineMedium: s(21, FontWeight.w600, t.textPrimary, ls: -0.4, h: 1.3),
      headlineSmall: s(18, FontWeight.w600, t.textPrimary, ls: -0.3, h: 1.3),
      titleLarge: s(17, FontWeight.w600, t.textPrimary, ls: -0.2, h: 1.3),
      titleMedium: s(15, FontWeight.w600, t.textPrimary, ls: -0.1, h: 1.4),
      titleSmall: s(13, FontWeight.w600, t.textSecondary, ls: 0.1, h: 1.4),
      bodyLarge: s(16, FontWeight.w400, t.textPrimary, h: 1.5),
      bodyMedium: s(14, FontWeight.w400, t.textPrimary, h: 1.5),
      bodySmall: s(13, FontWeight.w400, t.textSecondary, h: 1.45),
      labelLarge: s(14, FontWeight.w600, t.textPrimary, ls: 0.1),
      labelMedium: s(12, FontWeight.w500, t.textSecondary, ls: 0.2),
      labelSmall: s(11, FontWeight.w500, t.textTertiary, ls: 0.4),
    );
  }
}

/// Style for rendering OTP codes and amounts — monospaced, tabular.
abstract final class MonoText {
  static TextStyle otp(BuildContext context, {double size = 24}) => TextStyle(
        fontFamily: AppTheme.monoFont,
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: size * 0.18,
        color: context.tokens.textPrimary,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle amount(BuildContext context, {double size = 15}) =>
      TextStyle(
        fontFamily: AppTheme.monoFont,
        fontSize: size,
        fontWeight: FontWeight.w500,
        color: context.tokens.textPrimary,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}
