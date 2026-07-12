import 'package:flutter/material.dart';

/// Semantic color tokens for OTPBridge.
///
/// Restrained, trust-first palette: indigo primary, slate neutrals,
/// muted functional colors. No flashy gradients.
abstract final class AppColors {
  // ── Brand ────────────────────────────────────────────────────────────
  static const Color indigo500 = Color(0xFF4F46E5);
  static const Color indigo400 = Color(0xFF818CF8);
  static const Color indigo600 = Color(0xFF4338CA);
  static const Color indigo100 = Color(0xFFE0E7FF);
  static const Color indigo950 = Color(0xFF1E1B4B);

  // ── Neutrals (slate) ─────────────────────────────────────────────────
  static const Color slate25 = Color(0xFFFCFDFE);
  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate900 = Color(0xFF0F172A);
  static const Color slate950 = Color(0xFF080D1A);

  // ── Functional ───────────────────────────────────────────────────────
  static const Color successLight = Color(0xFF059669);
  static const Color successDark = Color(0xFF34D399);
  static const Color warningLight = Color(0xFFD97706);
  static const Color warningDark = Color(0xFFFBBF24);
  static const Color dangerLight = Color(0xFFDC2626);
  static const Color dangerDark = Color(0xFFF87171);
  static const Color infoLight = Color(0xFF0284C7);
  static const Color infoDark = Color(0xFF38BDF8);
}

/// Theme-aware semantic tokens, resolved once per brightness and exposed
/// through [BuildContext] via `context.tokens`.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.glassFill,
    required this.glassBorder,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.primary,
    required this.onPrimary,
    required this.primarySubtle,
    required this.onPrimarySubtle,
    required this.success,
    required this.successSubtle,
    required this.warning,
    required this.warningSubtle,
    required this.danger,
    required this.dangerSubtle,
    required this.info,
    required this.infoSubtle,
    required this.shadow,
  });

  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceSunken;
  final Color glassFill;
  final Color glassBorder;
  final Color border;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color primary;
  final Color onPrimary;
  final Color primarySubtle;
  final Color onPrimarySubtle;
  final Color success;
  final Color successSubtle;
  final Color warning;
  final Color warningSubtle;
  final Color danger;
  final Color dangerSubtle;
  final Color info;
  final Color infoSubtle;
  final Color shadow;

  static const AppTokens light = AppTokens(
    background: AppColors.slate50,
    surface: Colors.white,
    surfaceRaised: Colors.white,
    surfaceSunken: AppColors.slate100,
    glassFill: Color(0xCCFFFFFF),
    glassBorder: Color(0x14000000),
    border: AppColors.slate200,
    borderStrong: AppColors.slate300,
    textPrimary: AppColors.slate900,
    textSecondary: AppColors.slate500,
    textTertiary: AppColors.slate400,
    primary: AppColors.indigo500,
    onPrimary: Colors.white,
    primarySubtle: AppColors.indigo100,
    onPrimarySubtle: AppColors.indigo600,
    success: AppColors.successLight,
    successSubtle: Color(0xFFD1FAE5),
    warning: AppColors.warningLight,
    warningSubtle: Color(0xFFFEF3C7),
    danger: AppColors.dangerLight,
    dangerSubtle: Color(0xFFFEE2E2),
    info: AppColors.infoLight,
    infoSubtle: Color(0xFFE0F2FE),
    shadow: Color(0x14101828),
  );

  static const AppTokens dark = AppTokens(
    background: Color(0xFF0B1120),
    surface: Color(0xFF111A2E),
    surfaceRaised: Color(0xFF16203A),
    surfaceSunken: Color(0xFF0D1526),
    glassFill: Color(0x14FFFFFF),
    glassBorder: Color(0x1FFFFFFF),
    border: Color(0xFF1E293B),
    borderStrong: Color(0xFF334155),
    textPrimary: AppColors.slate100,
    textSecondary: AppColors.slate400,
    textTertiary: AppColors.slate500,
    primary: AppColors.indigo400,
    onPrimary: Color(0xFF0B1120),
    primarySubtle: Color(0xFF272E5C),
    onPrimarySubtle: Color(0xFFB4BCF9),
    success: AppColors.successDark,
    successSubtle: Color(0xFF0B2E22),
    warning: AppColors.warningDark,
    warningSubtle: Color(0xFF33270B),
    danger: AppColors.dangerDark,
    dangerSubtle: Color(0xFF351417),
    info: AppColors.infoDark,
    infoSubtle: Color(0xFF0B2536),
    shadow: Color(0x66000000),
  );

  @override
  AppTokens copyWith() => this;

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppTokens(
      background: l(background, other.background),
      surface: l(surface, other.surface),
      surfaceRaised: l(surfaceRaised, other.surfaceRaised),
      surfaceSunken: l(surfaceSunken, other.surfaceSunken),
      glassFill: l(glassFill, other.glassFill),
      glassBorder: l(glassBorder, other.glassBorder),
      border: l(border, other.border),
      borderStrong: l(borderStrong, other.borderStrong),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textTertiary: l(textTertiary, other.textTertiary),
      primary: l(primary, other.primary),
      onPrimary: l(onPrimary, other.onPrimary),
      primarySubtle: l(primarySubtle, other.primarySubtle),
      onPrimarySubtle: l(onPrimarySubtle, other.onPrimarySubtle),
      success: l(success, other.success),
      successSubtle: l(successSubtle, other.successSubtle),
      warning: l(warning, other.warning),
      warningSubtle: l(warningSubtle, other.warningSubtle),
      danger: l(danger, other.danger),
      dangerSubtle: l(dangerSubtle, other.dangerSubtle),
      info: l(info, other.info),
      infoSubtle: l(infoSubtle, other.infoSubtle),
      shadow: l(shadow, other.shadow),
    );
  }
}

extension AppTokensX on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}
