import 'package:flutter/material.dart';
import '../widgets/permissions_card.dart';
import '../services/dev_mode_service.dart';
import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

/// Settings page — currently just Developer Mode, but structured as a
/// section list so more preferences can be added the same way later.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.containerMargin,
          AppSpacing.md,
          AppSpacing.containerMargin,
          140,
        ),
        children: [
          Text(
            'PERMISSIONS',
            style: AppTypography.labelCaps.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const PermissionsCard(),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'DEVELOPER',
            style: AppTypography.labelCaps.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 8,
              ),
              child: ValueListenableBuilder<bool>(
                valueListenable: DevModeService.instance.enabled,
                builder: (context, devMode, _) {
                  return Row(
                    children: [
                      Icon(
                        Icons.developer_mode_outlined,
                        size: 20,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Developer mode',
                              style: AppTypography.bodyMd.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Show in-progress extensions on Home',
                              style: AppTypography.bodySm.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: devMode,
                        onChanged: (value) =>
                            DevModeService.instance.setEnabled(value),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
