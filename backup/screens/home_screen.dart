import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

/// Home page — the entry list of built-in + extension-provided modules
/// (TODO list, TODO Roadmap, Contacts, …).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
        _ModuleCard(
          icon: Icons.check_circle_outline,
          iconColor: AppColors.primary,
          title: 'TODO List',
          subtitle: '3 tasks due this week',
          trailing: const _CountBadge(count: 3),
        ),
        const SizedBox(height: AppSpacing.md),
        _ModuleCard(
          icon: Icons.map_outlined,
          iconColor: AppColors.tertiary,
          title: 'TODO Roadmap',
          subtitle: 'Product V2 · 45% complete',
          trailing: const _ProgressBadge(
            percent: 0.45,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _ModuleCard(
          icon: Icons.people_outline,
          iconColor: AppColors.secondary,
          title: 'Contacts',
          subtitle: '12 people',
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('EXTENSIONS', style: AppTypography.labelCaps),
        const SizedBox(height: AppSpacing.sm),
        _ModuleCard(
          icon: Icons.calendar_today_outlined,
          iconColor: AppColors.primary,
          title: 'Calendar Sync',
          subtitle: 'Two-way sync with Google Calendar',
        ),
      ],
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadius.standard),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodyMd.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTypography.bodySm),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.sm),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        '$count',
        style: AppTypography.bodySm.copyWith(color: AppColors.onSurface),
      ),
    );
  }
}

class _ProgressBadge extends StatelessWidget {
  const _ProgressBadge({required this.percent, required this.color});
  final double percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: percent,
            strokeWidth: 3,
            backgroundColor: AppColors.surfaceContainerHigh,
            valueColor: AlwaysStoppedAnimation(color),
          ),
          Text(
            '${(percent * 100).round()}',
            style: AppTypography.monoUtility.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }
}
