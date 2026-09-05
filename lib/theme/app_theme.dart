import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// COLOR PALETTE
// ═══════════════════════════════════════════════════════════════════════════════

/// Centralized color constants for both neon-dark and clean-light themes.
class AppColors {
  AppColors._();

  // ── Dark Theme – Background & Surface ───────────────────────────────────────
  static const Color background   = Color(0xFF0F172A);
  static const Color surface      = Color(0xFF1E293B);
  static const Color surfaceHigh  = Color(0xFF253047);
  static const Color border       = Color(0xFF334155);

  // ── Light Theme – Background & Surface ─────────────────────────────────────
  static const Color lightBackground  = Color(0xFFF1F5F9);
  static const Color lightSurface     = Color(0xFFFFFFFF);
  static const Color lightSurfaceHigh = Color(0xFFE2E8F0);
  static const Color lightBorder      = Color(0xFFCBD5E1);

  // ── Accent / Status ─────────────────────────────────────────────────────────
  static const Color accent   = Color(0xFF0EA5E9); // sky-500
  static const Color success  = Color(0xFF22C55E);
  static const Color warning  = Color(0xFFF59E0B);
  static const Color error    = Color(0xFFEF4444);

  // ── Dark text ───────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted     = Color(0xFF475569);

  // ── Light text ──────────────────────────────────────────────────────────────
  static const Color lightTextPrimary   = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted     = Color(0xFF94A3B8);

  // ── Tetromino palette – index 0 = empty, indices 1-7 = I O T S Z J L ───────
  static const List<Color> tetrominoes = [
    Colors.transparent, // 0: empty cell
    Color(0xFF00E5FF),  // 1: I – electric cyan
    Color(0xFFFFD600),  // 2: O – hyper gold
    Color(0xFFD500F9),  // 3: T – ultraviolet purple
    Color(0xFF00E676),  // 4: S – neon emerald
    Color(0xFFFF1744),  // 5: Z – radiant crimson
    Color(0xFF2979FF),  // 6: J – electric cobalt
    Color(0xFFFF9100),  // 7: L – hyper amber
  ];
}

// ═══════════════════════════════════════════════════════════════════════════════
// THEME
// ═══════════════════════════════════════════════════════════════════════════════

/// Builds Material 3 dark and light themes with the app's color palette.
class AppTheme {
  AppTheme._();

  // ── Dark theme ─────────────────────────────────────────────────────────────

  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,

      colorScheme: base.colorScheme.copyWith(
        primary:      AppColors.accent,
        secondary:    AppColors.success,
        surface:      AppColors.surface,
        error:        AppColors.error,
        onPrimary:    AppColors.background,
        onSecondary:  AppColors.background,
        onSurface:    AppColors.textPrimary,
      ),

      textTheme: _buildTextTheme(
        base: ThemeData.dark(useMaterial3: true).textTheme,
        primaryColor: AppColors.textPrimary,
        secondaryColor: AppColors.textSecondary,
        mutedColor: AppColors.textMuted,
      ),

      elevatedButtonTheme: _elevatedBtnTheme(AppColors.accent, AppColors.background),
      outlinedButtonTheme: _outlinedBtnTheme(AppColors.textPrimary, AppColors.border),
    );
  }

  // ── Light theme ────────────────────────────────────────────────────────────

  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.lightBackground,

      colorScheme: base.colorScheme.copyWith(
        primary:      AppColors.accent,
        secondary:    AppColors.success,
        surface:      AppColors.lightSurface,
        error:        AppColors.error,
        onPrimary:    Colors.white,
        onSecondary:  Colors.white,
        onSurface:    AppColors.lightTextPrimary,
      ),

      textTheme: _buildTextTheme(
        base: ThemeData.light(useMaterial3: true).textTheme,
        primaryColor: AppColors.lightTextPrimary,
        secondaryColor: AppColors.lightTextSecondary,
        mutedColor: AppColors.lightTextMuted,
      ),

      elevatedButtonTheme: _elevatedBtnTheme(AppColors.accent, Colors.white),
      outlinedButtonTheme: _outlinedBtnTheme(AppColors.lightTextPrimary, AppColors.lightBorder),
    );
  }

  // ── Shared helpers ─────────────────────────────────────────────────────────

  /// The bundled Outfit family. Declared in pubspec.yaml under
  /// `assets/fonts/`, so the app never fetches a font at runtime — text
  /// renders correctly offline and on first launch.
  static const String fontFamily = 'Outfit';

  /// [TextStyle] in the bundled Outfit family.
  static TextStyle _outfit({
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    Color? color,
  }) =>
      TextStyle(
        fontFamily: fontFamily,
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        color: color,
      );

  static TextTheme _buildTextTheme({
    required TextTheme base,
    required Color primaryColor,
    required Color secondaryColor,
    required Color mutedColor,
  }) {
    return base.apply(fontFamily: fontFamily).copyWith(
      displayLarge: _outfit(
        fontSize: 52, fontWeight: FontWeight.w900,
        letterSpacing: 5, color: primaryColor,
      ),
      headlineLarge: _outfit(
        fontSize: 32, fontWeight: FontWeight.w800,
        letterSpacing: 2, color: primaryColor,
      ),
      headlineMedium: _outfit(
        fontSize: 22, fontWeight: FontWeight.w700,
        letterSpacing: 1.5, color: primaryColor,
      ),
      titleLarge: _outfit(
        fontSize: 18, fontWeight: FontWeight.w700,
        color: primaryColor,
      ),
      bodyLarge: _outfit(
        fontSize: 16, color: secondaryColor,
      ),
      bodyMedium: _outfit(
        fontSize: 14, color: secondaryColor,
      ),
      labelSmall: _outfit(
        fontSize: 11, letterSpacing: 1.5,
        color: mutedColor, fontWeight: FontWeight.w600,
      ),
    );
  }

  static ElevatedButtonThemeData _elevatedBtnTheme(Color bg, Color fg) =>
      ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: _outfit(
            fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 2,
          ),
        ),
      );

  static OutlinedButtonThemeData _outlinedBtnTheme(Color fg, Color border) =>
      OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          side: BorderSide(color: border, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: _outfit(
            fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1.5,
          ),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════════════
// THEME-AWARE COLOR HELPER
// ═══════════════════════════════════════════════════════════════════════════════

/// Resolves the correct color variant based on the active [Brightness].
///
/// Usage: `ThemeColors.of(context).surface`
class ThemeColors {
  final Brightness brightness;
  const ThemeColors._(this.brightness);

  factory ThemeColors.of(BuildContext context) =>
      ThemeColors._(Theme.of(context).brightness);

  bool get isDark => brightness == Brightness.dark;

  Color get background  => isDark ? AppColors.background  : AppColors.lightBackground;
  Color get surface     => isDark ? AppColors.surface      : AppColors.lightSurface;
  Color get surfaceHigh => isDark ? AppColors.surfaceHigh  : AppColors.lightSurfaceHigh;
  Color get border      => isDark ? AppColors.border       : AppColors.lightBorder;

  Color get textPrimary   => isDark ? AppColors.textPrimary   : AppColors.lightTextPrimary;
  Color get textSecondary => isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
  Color get textMuted     => isDark ? AppColors.textMuted     : AppColors.lightTextMuted;

  // Accent / status colours are the same in both themes.
  Color get accent  => AppColors.accent;
  Color get warning => AppColors.warning;
  Color get success => AppColors.success;
  Color get error   => AppColors.error;
}
