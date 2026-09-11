import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Typography scale from Design.md:
/// - Hanken Grotesk for headlines (architectural, bold)
/// - Inter for body copy (high legibility)
/// - Geist for labels / mono utility text (system-level feel)
class AppTypography {
  AppTypography._();

  static TextStyle headlineLg = GoogleFonts.hankenGrotesk(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 40 / 32,
    letterSpacing: -0.02 * 32,
    color: AppColors.textPrimary,
  );

  static TextStyle headlineLgMobile = GoogleFonts.hankenGrotesk(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 32 / 26,
    letterSpacing: -0.01 * 26,
    color: AppColors.textPrimary,
  );

  static TextStyle headlineMd = GoogleFonts.hankenGrotesk(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 32 / 24,
    color: AppColors.textPrimary,
  );

  static TextStyle bodyLg = GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    height: 28 / 18,
    color: AppColors.onSurface,
  );

  static TextStyle bodyMd = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 24 / 16,
    color: AppColors.onSurface,
  );

  static TextStyle bodySm = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 20 / 14,
    letterSpacing: 0.1, // slightly increased tracking against pure black
    color: AppColors.textSecondary,
  );

  static TextStyle labelCaps = GoogleFonts.geist(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 16 / 12,
    letterSpacing: 0.05 * 12,
    color: AppColors.textSecondary,
  );

  static TextStyle monoUtility = GoogleFonts.geist(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 18 / 13,
    color: AppColors.onSurfaceVariant,
  );
}
