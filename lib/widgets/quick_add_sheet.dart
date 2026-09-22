// widgets/quick_add_sheet
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show Value;
import '../data/app_database.dart';
import '../models/todo_task.dart';
import '../services/notification_service.dart';
import '../services/todo_refresh_bus.dart';
import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import 'todo_task_sheet.dart';

/// The center FAB's quick-add sheet. "Create TODO" hands off to the real
/// task sheet and persists straight to AppDatabase — same write path
/// TodoScreen uses — so a task created from here shows up there without
/// any state passing through MainShell. "Add Roadmap Item" stays a
/// callback since Roadmap doesn't have a real screen yet.
Future<void> showQuickAddSheet(
  BuildContext context, {
  required VoidCallback onAddRoadmapItem,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _QuickAddSheet(onAddRoadmapItem: onAddRoadmapItem),
  );
}

Future<void> _persistNewTodo(TodoTask task) async {
  await AppDatabase.instance.upsertTodo(
    TodosCompanion.insert(
      id: task.id,
      title: task.title,
      category: task.category,
      priority: task.priority.name,
      dueDate: Value(task.dueDate),
      isDone: Value(task.isDone),
      notificationEnabled: Value(task.notificationEnabled),
      alarmEnabled: Value(task.alarmEnabled),
    ),
  );
  // A brand-new task from quick-add never has subtasks yet, so there's
  // nothing to replace here — unlike TodoScreen._persistTask, which also
  // handles edits to an existing task's subtask list.

  if (task.notificationEnabled && task.dueDate != null) {
    await NotificationService.instance.scheduleTaskNotification(task);
  }

  // TodoScreen may already be open with this task missing from its
  // in-memory list (it wasn't the one that wrote it) — tell it to reload.
  TodoRefreshBus.notify();
}

class _QuickAddSheet extends StatelessWidget {
  const _QuickAddSheet({required this.onAddRoadmapItem});

  final VoidCallback onAddRoadmapItem;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.container),
        ),
        border: Border.all(color: colors.borderSubtle),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.borderSubtle,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
          ),
          Text(
            'Quick add',
            style: AppTypography.bodyLg.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _QuickAddCard(
            icon: Icons.check_circle_outline,
            iconColor: colors.primary,
            title: 'Create TODO',
            subtitle: 'Add a task to your list',
            onTap: () {
              Navigator.of(context).pop();
              showTodoTaskSheet(context, onSave: _persistNewTodo);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          _QuickAddCard(
            icon: Icons.map_outlined,
            iconColor: colors.tertiary,
            title: 'Add Roadmap Item',
            subtitle: 'Add a milestone to TODO Roadmap',
            onTap: () {
              Navigator.of(context).pop();
              onAddRoadmapItem();
            },
          ),
        ],
      ),
    );
  }
}

/// Same card treatment as HomeScreen's _ModuleCard — Card + InkWell,
/// 44x44 icon box, title/subtitle — so quick-add actions read as the
/// same kind of tappable module the rest of the app already uses.
class _QuickAddCard extends StatelessWidget {
  const _QuickAddCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.container),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHigh,
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
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.bodySm.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: colors.outline),
            ],
          ),
        ),
      ),
    );
  }
}
