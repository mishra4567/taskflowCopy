import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography scale from Design.md:
/// - Hanken Grotesk for headlines (architectural, bold)
/// - Inter for body copy (high legibility)
/// - Geist for labels / mono utility text (system-level feel)
///
/// These styles are intentionally colorless — apply color at the call site
/// via `.copyWith(color: context.colors.textPrimary)` (or similar) so text
/// responds correctly to the active theme (dark/light).
class AppTypography {
  AppTypography._();

  static TextStyle headlineLg = GoogleFonts.hankenGrotesk(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 40 / 32,
    letterSpacing: -0.02 * 32,
  );

  static TextStyle headlineLgMobile = GoogleFonts.hankenGrotesk(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 32 / 26,
    letterSpacing: -0.01 * 26,
  );

  static TextStyle headlineMd = GoogleFonts.hankenGrotesk(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 32 / 24,
  );

  static TextStyle bodyLg = GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    height: 28 / 18,
  );

  static TextStyle bodyMd = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 24 / 16,
  );

  static TextStyle bodySm = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 20 / 14,
    letterSpacing: 0.1, // slightly increased tracking for small copy
  );

  static TextStyle labelCaps = GoogleFonts.geist(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 16 / 12,
    letterSpacing: 0.05 * 12,
  );

  static TextStyle monoUtility = GoogleFonts.geist(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 18 / 13,
  );
}
