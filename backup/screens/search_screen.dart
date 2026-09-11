import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

/// Unified search across TODO list, roadmap, and contacts.
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.containerMargin,
          AppSpacing.md,
          AppSpacing.containerMargin,
          140,
        ),
        children: [
          TextField(
            style: AppTypography.bodyMd,
            decoration: InputDecoration(
              hintText: 'Search tasks, roadmaps, or contacts...',
              prefixIcon: const Icon(
                Icons.search,
                color: AppColors.textSecondary,
              ),
              filled: true,
              fillColor: AppColors.surfaceContainer,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.standard),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('RECENT SEARCHES', style: AppTypography.labelCaps),
              Text(
                'Clear',
                style: AppTypography.bodySm.copyWith(color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: const [
              _RecentChip(label: '"Q3 Strategy"'),
              _RecentChip(label: 'Design System'),
              _RecentChip(label: '@Sarah'),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('TOP RESULTS', style: AppTypography.labelCaps),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            size: 16,
                            color: AppColors.tertiary,
                          ),
                          const SizedBox(width: 8),
                          Text('Tasks', style: AppTypography.bodyMd),
                        ],
                      ),
                      const _CountBadge(count: 3),
                    ],
                  ),
                  const Divider(height: AppSpacing.lg),
                  _TaskRow(
                    label: 'Finalize Q3 Strategy Deck',
                    meta: 'Due Tomorrow',
                    done: false,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _TaskRow(
                    label: 'Review Design System tokens',
                    meta: 'Completed',
                    done: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('ROADMAPS', style: AppTypography.labelCaps),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: const [
              Expanded(
                child: _RoadmapCard(
                  title: 'Product V2',
                  percent: 0.45,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: _RoadmapCard(
                  title: 'Marketing Site',
                  percent: 0.90,
                  color: AppColors.tertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text('CONTACTS', style: AppTypography.labelCaps),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primaryContainer,
                    child: Text(
                      'SJ',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sarah Jenkins',
                        style: AppTypography.bodyMd.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text('Lead Designer', style: AppTypography.bodySm),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentChip extends StatelessWidget {
  const _RecentChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: const Icon(
        Icons.history,
        size: 14,
        color: AppColors.textSecondary,
      ),
      label: Text(label),
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

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.label, required this.meta, required this.done});
  final String label;
  final String meta;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          done ? Icons.check_box : Icons.check_box_outline_blank,
          size: 20,
          color: done ? AppColors.tertiary : AppColors.outline,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.textPrimary,
                  decoration: done ? TextDecoration.lineThrough : null,
                  decorationColor: AppColors.textSecondary,
                ),
              ),
              Text(meta, style: AppTypography.bodySm),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoadmapCard extends StatelessWidget {
  const _RoadmapCard({
    required this.title,
    required this.percent,
    required this.color,
  });
  final String title;
  final double percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: LinearProgressIndicator(
                value: percent,
                minHeight: 4,
                backgroundColor: AppColors.surfaceContainerHigh,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${(percent * 100).round()}% Complete',
              style: AppTypography.bodySm,
            ),
          ],
        ),
      ),
    );
  }
}
