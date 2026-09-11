import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

/// The overlay that appears when the center "+" nav button is tapped.
/// Shows quick-create pills (Create TODO, Add Roadmap Item) — the list
/// of actions can grow as extensions register their own creators.
Future<void> showQuickAddSheet(
  BuildContext context, {
  required VoidCallback onCreateTodo,
  required VoidCallback onAddRoadmapItem,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Quick add',
    barrierColor: Colors.black.withValues(alpha: 0.6),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _QuickAddContent(
        onCreateTodo: onCreateTodo,
        onAddRoadmapItem: onAddRoadmapItem,
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.92, end: 1.0).animate(curved),
          alignment: Alignment.bottomCenter,
          child: child,
        ),
      );
    },
  );
}

class _QuickAddContent extends StatelessWidget {
  const _QuickAddContent({
    required this.onCreateTodo,
    required this.onAddRoadmapItem,
  });

  final VoidCallback onCreateTodo;
  final VoidCallback onAddRoadmapItem;

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 110),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _QuickAddPill(
                icon: Icons.map_outlined,
                iconColor: AppColors.tertiary,
                label: 'Add Roadmap Item',
                background: AppColors.surfaceContainerHighest,
                labelColor: AppColors.onSurface,
                onTap: () {
                  Navigator.of(context).pop();
                  onAddRoadmapItem();
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              _QuickAddPill(
                icon: Icons.check_circle,
                iconColor: AppColors.onPrimaryContainer,
                label: 'Create TODO',
                background: AppColors.primary,
                labelColor: AppColors.onPrimaryContainer,
                onTap: () {
                  Navigator.of(context).pop();
                  onCreateTodo();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAddPill extends StatelessWidget {
  const _QuickAddPill({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.background,
    required this.labelColor,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final Color background;
  final Color labelColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.full),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: Colors.black.withValues(alpha: 0.15),
                child: Icon(icon, size: 14, color: iconColor),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: AppTypography.bodyMd.copyWith(
                  color: labelColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
