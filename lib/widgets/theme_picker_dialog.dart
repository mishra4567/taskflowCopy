import 'package:flutter/material.dart';
import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import '../theme/theme_controller.dart';

/// The Light / Dark / System picker opened from the "Theme" row in More.
Future<void> showThemePickerDialog(BuildContext context) {
  final colors = context.colors;
  return showDialog<void>(
    context: context,
    builder: (context) {
      return SimpleDialog(
        backgroundColor: colors.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.container),
          side: BorderSide(color: colors.borderSubtle),
        ),
        titlePadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        title: Text(
          'Theme',
          style: AppTypography.bodyLg.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        children: [
          for (final mode in ThemeMode.values) _ThemeOption(mode: mode),
        ],
      );
    },
  );
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({required this.mode});
  final ThemeMode mode;

  IconData get _icon => switch (mode) {
    ThemeMode.dark => Icons.dark_mode_outlined,
    ThemeMode.light => Icons.light_mode_outlined,
    ThemeMode.system => Icons.brightness_auto_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeController,
      builder: (context, current, _) {
        final selected = current == mode;
        return InkWell(
          onTap: () {
            themeController.set(mode);
            Navigator.of(context).pop();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: 12,
            ),
            child: Row(
              children: [
                Icon(
                  _icon,
                  size: 20,
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    ThemeController.label(mode),
                    style: AppTypography.bodyMd.copyWith(
                      color: selected ? colors.primary : colors.textPrimary,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (selected)
                  Icon(Icons.check, size: 18, color: colors.primary),
              ],
            ),
          ),
        );
      },
    );
  }
}
