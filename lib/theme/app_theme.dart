import 'package:flutter/material.dart';
import 'app_palette.dart';
import 'app_tokens.dart';
import 'app_typography.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark => _build(AppPalette.dark, Brightness.dark);
  static ThemeData get light => _build(AppPalette.light, Brightness.light);

  static ThemeData _build(AppPalette palette, Brightness brightness) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      surface: palette.surfaceContainer,
      onSurface: palette.onSurface,
      onSurfaceVariant: palette.onSurfaceVariant,
      primary: palette.primary,
      onPrimary: palette.onPrimary,
      primaryContainer: palette.primaryContainer,
      onPrimaryContainer: palette.onPrimaryContainer,
      secondary: palette.secondary,
      onSecondary: palette.onPrimary,
      tertiary: palette.tertiary,
      onTertiary: palette.onPrimary,
      error: palette.error,
      onError: palette.onPrimary,
      outline: palette.outline,
      outlineVariant: palette.borderSubtle,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      extensions: [palette],

      // Strict OLED black (or clean white) canvas, distinct from the
      // slightly stepped-up tone used for cards.
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.background,

      textTheme: TextTheme(
        headlineLarge: AppTypography.headlineLg.copyWith(
          color: palette.textPrimary,
        ),
        headlineMedium: AppTypography.headlineMd.copyWith(
          color: palette.textPrimary,
        ),
        bodyLarge: AppTypography.bodyLg.copyWith(color: palette.onSurface),
        bodyMedium: AppTypography.bodyMd.copyWith(color: palette.onSurface),
        bodySmall: AppTypography.bodySm.copyWith(color: palette.textSecondary),
        labelLarge: AppTypography.labelCaps.copyWith(
          color: palette.textSecondary,
        ),
        labelSmall: AppTypography.monoUtility.copyWith(
          color: palette.onSurfaceVariant,
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: palette.onSurface),
        titleTextStyle: AppTypography.headlineMd.copyWith(
          color: palette.primary,
          fontSize: 22,
        ),
      ),

      cardTheme: CardThemeData(
        color: palette.surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.container),
          side: BorderSide(color: palette.borderSubtle, width: 1),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.primaryContainer,
          foregroundColor: palette.onPrimary,
          disabledBackgroundColor: palette.surfaceContainerHigh,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          textStyle: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: palette.background,
          foregroundColor: palette.onSurface,
          side: BorderSide(color: palette.borderSubtle, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.standard),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.background,
        hintStyle: AppTypography.bodyMd.copyWith(color: palette.textSecondary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.standard),
          borderSide: BorderSide(color: palette.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.standard),
          borderSide: BorderSide(color: palette.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.standard),
          borderSide: BorderSide(color: palette.primary, width: 1.5),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: palette.surfaceContainerHigh,
        labelStyle: AppTypography.bodySm.copyWith(color: palette.onSurface),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      dividerTheme: DividerThemeData(
        color: palette.borderSubtle,
        thickness: 1,
        space: 1,
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: palette.background,
        selectedItemColor: palette.primaryContainer,
        unselectedItemColor: palette.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: palette.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: palette.borderSubtle),
        ),
        textStyle: AppTypography.bodyMd.copyWith(color: palette.onSurface),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.surfaceContainerHighest,
        contentTextStyle: AppTypography.bodyMd.copyWith(
          color: palette.textPrimary,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        insetPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: palette.borderSubtle),
        ),
      ),

      iconTheme: IconThemeData(color: palette.onSurface),
    );
  }
}
