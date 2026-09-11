import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

class _Extension {
  const _Extension({
    required this.icon,
    required this.title,
    required this.description,
    required this.state,
  });

  final IconData icon;
  final String title;
  final String description;
  final _ExtensionState state;
}

enum _ExtensionState { installed, free, addable }

const _extensions = [
  _Extension(
    icon: Icons.calendar_today_outlined,
    title: 'Calendar Sync',
    description:
        'Two-way sync with Google Calendar and Outlook to manage tasks alongside meetings.',
    state: _ExtensionState.installed,
  ),
  _Extension(
    icon: Icons.wb_sunny_outlined,
    title: 'Weather Widget',
    description:
        'Plan your outdoor tasks with real-time, localized weather forecasts on your dashboard.',
    state: _ExtensionState.addable,
  ),
  _Extension(
    icon: Icons.account_balance_wallet_outlined,
    title: 'Finance Tracker',
    description: 'Track budgets and link financial goals to your task roadmap.',
    state: _ExtensionState.free,
  ),
];

/// Extensions page — installable modules like Contacts, Roadmap, Alarm, etc.
class ExtensionsScreen extends StatelessWidget {
  const ExtensionsScreen({super.key});

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
        Text('Extensions', style: AppTypography.headlineMd),
        const SizedBox(height: 4),
        Text(
          'Enhance your workflow with these tools.',
          style: AppTypography.bodySm,
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final ext in _extensions) ...[
          _ExtensionCard(extension: ext),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _ExtensionCard extends StatelessWidget {
  const _ExtensionCard({required this.extension});
  final _Extension extension;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppRadius.standard),
                  ),
                  child: Icon(
                    extension.icon,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                _StateChip(state: extension.state),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              extension.title,
              style: AppTypography.bodyLg.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(extension.description, style: AppTypography.bodySm),
            const SizedBox(height: AppSpacing.md),
            if (extension.state == _ExtensionState.installed)
              Row(
                children: [
                  Text(
                    'Configure',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward,
                    size: 14,
                    color: AppColors.primary,
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {},
                  child: const Text('Add Extension'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.state});
  final _ExtensionState state;

  @override
  Widget build(BuildContext context) {
    if (state == _ExtensionState.addable) return const SizedBox.shrink();

    final isInstalled = state == _ExtensionState.installed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isInstalled
            ? AppColors.tertiary.withValues(alpha: 0.16)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        isInstalled ? 'INSTALLED' : 'Free',
        style: AppTypography.labelCaps.copyWith(
          color: isInstalled ? AppColors.tertiary : AppColors.textSecondary,
          fontSize: 10,
        ),
      ),
    );
  }
}
