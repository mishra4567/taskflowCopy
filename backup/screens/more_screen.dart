import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

/// More page — Archive, Trash, Settings, Theme, Account.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.containerMargin,
        AppSpacing.md,
        AppSpacing.containerMargin,
        140,
      ),
      children: [
        Text('More', style: AppTypography.headlineMd),
        const SizedBox(height: AppSpacing.lg),
        Text('DATA MANAGEMENT', style: AppTypography.labelCaps),
        const SizedBox(height: AppSpacing.sm),
        _SectionCard(
          rows: [
            _RowSpec(icon: Icons.inventory_2_outlined, label: 'Archive'),
            _RowSpec(icon: Icons.delete_outline, label: 'Trash Can'),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('PREFERENCES', style: AppTypography.labelCaps),
        const SizedBox(height: AppSpacing.sm),
        _SectionCard(
          rows: [
            _RowSpec(icon: Icons.settings_outlined, label: 'Settings'),
            _RowSpec(
              icon: Icons.palette_outlined,
              label: 'Theme',
              trailingText: 'Dark (OLED)',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('ACCOUNT', style: AppTypography.labelCaps),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.surfaceContainerHigh,
                  child: Icon(Icons.person, color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'John Doe',
                        style: AppTypography.bodyMd.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text('john.doe@example.com', style: AppTypography.bodySm),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.outline),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RowSpec {
  const _RowSpec({required this.icon, required this.label, this.trailingText});
  final IconData icon;
  final String label;
  final String? trailingText;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.rows});
  final List<_RowSpec> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _MoreRow(spec: rows[i]),
            if (i != rows.length - 1) const Divider(height: 1, indent: 56),
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
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        child: Row(
          children: [
            Icon(spec.icon, size: 20, color: AppColors.onSurfaceVariant),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                spec.label,
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (spec.trailingText != null)
              Text(
                spec.trailingText!,
                style: AppTypography.bodySm.copyWith(color: AppColors.primary),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.outline),
          ],
        ),
      ),
    );
  }
}
