import 'package:flutter/material.dart';

/// Color tokens ported 1:1 from Design.md ("Obsidian Velocity").
/// Background is kept strictly pure black (#000000) per the design doc's
/// "Full Black / OLED-optimized" spec, even though other surface levels
/// use the softer #121212 / #1e1e1e tones for tonal layering.
class AppColors {
  AppColors._();

  // Canvas
  static const background = Color(0xFF000000);
  static const onBackground = Color(0xFFE2E2E2);

  // Surfaces (tonal layering, since OLED black gives no shadow contrast)
  static const surfaceContainerLowest = Color(0xFF0E0E0E);
  static const surfaceContainerLow = Color(0xFF1B1B1B);
  static const surfaceContainer = Color(0xFF121212); // Level 1 cards
  static const surfaceContainerHigh = Color(0xFF2A2A2A);
  static const surfaceContainerHighest = Color(0xFF1E1E1E); // Level 2 overlays
  static const surfaceBright = Color(0xFF393939);

  static const onSurface = Color(0xFFE2E2E2);
  static const onSurfaceVariant = Color(0xFFC6C5D5);

  static const outline = Color(0xFF908F9E);
  static const outlineVariant = Color(0xFF454653);
  static const borderSubtle = Color(0xFF2E2E2E); // "ghost border" on cards

  // Primary (vibrant indigo)
  static const primary = Color(0xFFBDC2FF); // text / icon accent
  static const onPrimary = Color(0xFF000000);
  static const primaryContainer = Color(0xFF818CF8); // filled buttons / FAB
  static const onPrimaryContainer = Color(0xFF101B8A);
  static const inversePrimary = Color(0xFF4953BC);

  // Secondary (deep charcoal / neutral)
  static const secondary = Color(0xFFC8C6C5);
  static const onSecondary = Color(0xFF303030);
  static const secondaryContainer = Color(0xFF474746);
  static const onSecondaryContainer = Color(0xFFB7B5B4);

  // Tertiary (teal — success / milestones)
  static const tertiary = Color(0xFF3CDDC7);
  static const onTertiary = Color(0xFF003731);
  static const tertiaryContainer = Color(0xFF00A896);
  static const onTertiaryContainer = Color(0xFF00352E);

  // Error
  static const error = Color(0xFFFFB4AB);
  static const onError = Color(0xFF690005);
  static const errorContainer = Color(0xFF93000A);
  static const onErrorContainer = Color(0xFFFFDAD6);

  // Text (high-contrast off-white / muted slate)
  static const textPrimary = Color(0xFFF8FAFC);
  static const textSecondary = Color(0xFF94A3B8);

  static const inverseSurface = Color(0xFFE2E2E2);
  static const inverseOnSurface = Color(0xFF303030);
}
