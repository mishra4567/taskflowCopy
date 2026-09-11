// app_palette
import 'package:flutter/material.dart';

/// All the custom color roles the app uses beyond Flutter's standard
/// ColorScheme (text tiers, ghost borders, tonal surface steps). Registered
/// as a ThemeExtension so screens can pull the *active* palette (dark or
/// light) instead of hardcoding one brightness.
///
/// Usage in widgets: `context.colors.primary`, `context.colors.textPrimary`, etc.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.surfaceContainerHighest,
    required this.borderSubtle,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outline,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.tertiary,
    required this.error,
    required this.textPrimary,
    required this.textSecondary,
  });

  final Color background;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color surfaceContainerHighest;
  final Color borderSubtle;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color outline;
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color secondary;
  final Color tertiary;
  final Color error;
  final Color textPrimary;
  final Color textSecondary;

  /// Ported 1:1 from Design.md ("Obsidian Velocity" — Full Black / OLED).
  static const dark = AppPalette(
    background: Color(0xFF000000),
    surfaceContainer: Color(0xFF121212), // Level 1 cards
    surfaceContainerHigh: Color(0xFF2A2A2A),
    surfaceContainerHighest: Color(0xFF1E1E1E), // Level 2 overlays
    borderSubtle: Color(0xFF2E2E2E), // "ghost border"
    onSurface: Color(0xFFE2E2E2),
    onSurfaceVariant: Color(0xFFC6C5D5),
    outline: Color(0xFF908F9E),
    primary: Color(0xFFBDC2FF),
    onPrimary: Color(0xFF000000),
    primaryContainer: Color(0xFF818CF8),
    onPrimaryContainer: Color(0xFF101B8A),
    secondary: Color(0xFFC8C6C5),
    tertiary: Color(0xFF3CDDC7),
    error: Color(0xFFFFB4AB),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFF94A3B8),
  );

  /// Design.md only specifies the dark theme. These are derived from the
  /// same brand hues using Design.md's Material 3 "fixed" tokens, which
  /// are built to stay legible across both light and dark surfaces.
  static const light = AppPalette(
    background: Color(0xFFFFFFFF),
    surfaceContainer: Color(0xFFF7F7F8),
    surfaceContainerHigh: Color(0xFFEDEDF0),
    surfaceContainerHighest: Color(0xFFE5E5E8),
    borderSubtle: Color(0xFFE3E3E6),
    onSurface: Color(0xFF1B1B1B),
    onSurfaceVariant: Color(0xFF45464F),
    outline: Color(0xFF767680),
    primary: Color(0xFF4953BC), // inverse-primary — reads on white
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFE0E0FF), // primary-fixed
    onPrimaryContainer: Color(0xFF000767), // on-primary-fixed
    secondary: Color(0xFF474746),
    tertiary: Color(0xFF00786B), // darkened for contrast on white
    error: Color(0xFFBA1A1A),
    textPrimary: Color(0xFF1B1B1B),
    textSecondary: Color(0xFF57575F),
  );

  @override
  AppPalette copyWith({
    Color? background,
    Color? surfaceContainer,
    Color? surfaceContainerHigh,
    Color? surfaceContainerHighest,
    Color? borderSubtle,
    Color? onSurface,
    Color? onSurfaceVariant,
    Color? outline,
    Color? primary,
    Color? onPrimary,
    Color? primaryContainer,
    Color? onPrimaryContainer,
    Color? secondary,
    Color? tertiary,
    Color? error,
    Color? textPrimary,
    Color? textSecondary,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surfaceContainer: surfaceContainer ?? this.surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh ?? this.surfaceContainerHigh,
      surfaceContainerHighest:
          surfaceContainerHighest ?? this.surfaceContainerHighest,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      onSurface: onSurface ?? this.onSurface,
      onSurfaceVariant: onSurfaceVariant ?? this.onSurfaceVariant,
      outline: outline ?? this.outline,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      onPrimaryContainer: onPrimaryContainer ?? this.onPrimaryContainer,
      secondary: secondary ?? this.secondary,
      tertiary: tertiary ?? this.tertiary,
      error: error ?? this.error,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      surfaceContainer: Color.lerp(
        surfaceContainer,
        other.surfaceContainer,
        t,
      )!,
      surfaceContainerHigh: Color.lerp(
        surfaceContainerHigh,
        other.surfaceContainerHigh,
        t,
      )!,
      surfaceContainerHighest: Color.lerp(
        surfaceContainerHighest,
        other.surfaceContainerHighest,
        t,
      )!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      onSurfaceVariant: Color.lerp(
        onSurfaceVariant,
        other.onSurfaceVariant,
        t,
      )!,
      outline: Color.lerp(outline, other.outline, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      primaryContainer: Color.lerp(
        primaryContainer,
        other.primaryContainer,
        t,
      )!,
      onPrimaryContainer: Color.lerp(
        onPrimaryContainer,
        other.onPrimaryContainer,
        t,
      )!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      tertiary: Color.lerp(tertiary, other.tertiary, t)!,
      error: Color.lerp(error, other.error, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
    );
  }
}

/// Shorthand: `context.colors.primary` instead of
/// `Theme.of(context).extension<AppPalette>()!.primary`.
extension AppPaletteContext on BuildContext {
  AppPalette get colors => Theme.of(this).extension<AppPalette>()!;
}
