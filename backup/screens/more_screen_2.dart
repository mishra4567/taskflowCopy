import 'package:flutter/material.dart';
import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import '../theme/theme_controller.dart';

/// More page — Archive, Trash, Settings, Theme, Account.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.containerMargin,
        AppSpacing.md,
        AppSpacing.containerMargin,
        140,
      ),
      children: [
        Text(
          'More',
          style: AppTypography.headlineMd.copyWith(color: colors.textPrimary),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'DATA MANAGEMENT',
          style: AppTypography.labelCaps.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        const _SectionCard(
          rows: [
            _RowSpec(icon: Icons.inventory_2_outlined, label: 'Archive'),
            _RowSpec(icon: Icons.delete_outline, label: 'Trash Can'),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'PREFERENCES',
          style: AppTypography.labelCaps.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Rebuilds just this row when the theme mode changes, so the label
        // (Dark (OLED) / Light) and the tap toggle both stay in sync.
        ValueListenableBuilder<ThemeMode>(
          valueListenable: themeController,
          builder: (context, mode, _) {
            return _SectionCard(
              rows: [
                const _RowSpec(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                ),
                _RowSpec(
                  icon: Icons.palette_outlined,
                  label: 'Theme',
                  trailingText: mode == ThemeMode.dark
                      ? 'Dark (OLED)'
                      : 'Light',
                  onTap: themeController.toggle,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'ACCOUNT',
          style: AppTypography.labelCaps.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: colors.surfaceContainerHigh,
                  child: Icon(Icons.person, color: colors.onSurfaceVariant),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'John Doe',
                        style: AppTypography.bodyMd.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        'john.doe@example.com',
                        style: AppTypography.bodySm.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: colors.outline),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RowSpec {
  const _RowSpec({
    required this.icon,
    required this.label,
    this.trailingText,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final String? trailingText;
  final VoidCallback? onTap;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.rows});
  final List<_RowSpec> rows;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _MoreRow(spec: rows[i]),
            if (i != rows.length - 1)
              Divider(height: 1, indent: 56, color: colors.borderSubtle),
          ],
        ],
      ),
    );
  }
}

class _MoreRow extends StatelessWidget {
  const _MoreRow({required this.spec});
  final _RowSpec spec;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: spec.onTap ?? () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        child: Row(
          children: [
            Icon(spec.icon, size: 20, color: colors.onSurfaceVariant),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                spec.label,
                style: AppTypography.bodyMd.copyWith(color: colors.textPrimary),
              ),
            ),
            if (spec.trailingText != null)
              Text(
                spec.trailingText!,
                style: AppTypography.bodySm.copyWith(color: colors.primary),
              ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: colors.outline),
          ],
        ),
      ),
    );
  }
}
