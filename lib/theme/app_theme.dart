import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// COLOR PALETTE
// ═══════════════════════════════════════════════════════════════════════════════

/// Centralized color constants for the neon-dark Tetris theme.
class AppColors {
  AppColors._();

  // ── Background & Surface ────────────────────────────────────────────────────
  static const Color background   = Color(0xFF0F172A); // Spec requirement
  static const Color surface      = Color(0xFF1E293B); // Spec requirement
  static const Color surfaceHigh  = Color(0xFF253047);
  static const Color border       = Color(0xFF334155);

  // ── Accent / Status ─────────────────────────────────────────────────────────
  static const Color accent   = Color(0xFF38BDF8); // Spec requirement
  static const Color success  = Color(0xFF22C55E); // Spec requirement
  static const Color warning  = Color(0xFFF59E0B); // Spec requirement
  static const Color error    = Color(0xFFEF4444);

  // ── Text ────────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted     = Color(0xFF475569);

  // ── Tetromino palette – index 0 = empty, indices 1-7 = I O T S Z J L ───────
  static const List<Color> tetrominoes = [
    Colors.transparent, // 0: empty cell
    Color(0xFF00D4FF),  // 1: I – electric cyan
    Color(0xFFFFD700),  // 2: O – gold
    Color(0xFFBF00FF),  // 3: T – neon purple
    Color(0xFF00FF7F),  // 4: S – spring green
    Color(0xFFFF3366),  // 5: Z – neon pink-red
    Color(0xFF4169FF),  // 6: J – electric blue
    Color(0xFFFF8C00),  // 7: L – neon orange
  ];
}

// ═══════════════════════════════════════════════════════════════════════════════
// THEME
// ═══════════════════════════════════════════════════════════════════════════════

/// Builds a Material 3 dark theme with the neon palette and Outfit typography.
class AppTheme {
  AppTheme._();

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

      // Outfit gives a clean, modern geometric look perfect for a game UI.
      textTheme: GoogleFonts.outfitTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(
          fontSize: 52, fontWeight: FontWeight.w900,
          letterSpacing: 5, color: AppColors.textPrimary,
        ),
        headlineLarge: GoogleFonts.outfit(
          fontSize: 32, fontWeight: FontWeight.w800,
          letterSpacing: 2, color: AppColors.textPrimary,
        ),
        headlineMedium: GoogleFonts.outfit(
          fontSize: 22, fontWeight: FontWeight.w700,
          letterSpacing: 1.5, color: AppColors.textPrimary,
        ),
        titleLarge: GoogleFonts.outfit(
          fontSize: 18, fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        bodyLarge: GoogleFonts.outfit(
          fontSize: 16, color: AppColors.textSecondary,
        ),
        bodyMedium: GoogleFonts.outfit(
          fontSize: 14, color: AppColors.textSecondary,
        ),
        labelSmall: GoogleFonts.outfit(
          fontSize: 11, letterSpacing: 1.5,
          color: AppColors.textMuted, fontWeight: FontWeight.w600,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.background,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.outfit(
            fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 2,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.outfit(
            fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}
