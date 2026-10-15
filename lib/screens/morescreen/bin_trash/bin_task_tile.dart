// screens/morescreen/bin_task_tile.dart
import 'package:flutter/material.dart';
import 'package:taskflow/models/todo_task.dart';
import 'package:taskflow/services/backUp/backup_service.dart';
import 'package:taskflow/theme/app_palette.dart';
import 'package:taskflow/theme/app_tokens.dart';
import 'package:taskflow/theme/app_typography.dart';

/// One tappable action on a [BinTaskTile] (restore, delete forever, ...).
class BinAction {
  const BinAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.destructive = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool destructive;
}

String formatBinDate(DateTime d) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

/// Yes/no dialog for anything that can't be undone.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: dialogContext.colors.error,
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// AppBar icon for the Archive and Trash pages that runs the same
/// "Back up now" as Settings → Backup (BackupService.exportToZip), so
/// there is one backup, reachable from all three places. Shows a spinner
/// while it runs (the save dialog and the zip take a moment) and reports
/// the result in a snackbar — including "cancelled", so closing the save
/// dialog doesn't look like nothing happened.
class BackupNowButton extends StatefulWidget {
  const BackupNowButton({super.key});

  @override
  State<BackupNowButton> createState() => _BackupNowButtonState();
}

class _BackupNowButtonState extends State<BackupNowButton> {
  bool _busy = false;

  Future<void> _backUp() async {
    if (_busy) return;
    setState(() => _busy = true);

    String message;
    try {
      final savedPath = await BackupService.exportToZip();
      message = savedPath == null
          ? 'Backup cancelled'
          : 'Backup saved to $savedPath';
    } on BackupException catch (e) {
      message = e.message;
    } catch (e) {
      message = 'Backup failed: $e';
    }

    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return IconButton(
      tooltip: 'Back up now',
      onPressed: _busy ? null : _backUp,
      icon: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(Icons.backup_outlined, color: colors.onSurfaceVariant),
    );
  }
}

class BinEmptyState extends StatelessWidget {
  const BinEmptyState({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: colors.outline),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodySm.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class BinTaskTile extends StatelessWidget {
  const BinTaskTile({
    super.key,
    required this.task,
    required this.caption,
    required this.actions,
  });

  final TodoTask task;

  /// e.g. "Archived 3 Oct 2026" — shown after the category.
  final String caption;
  final List<BinAction> actions;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(
              task.isDone ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 22,
              color: task.isDone
                  ? colors.tertiary
                  : task.priority.color(colors),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMd.copyWith(
                      fontWeight: FontWeight.w600,
                      color: task.isDone
                          ? colors.textSecondary
                          : colors.textPrimary,
                      decoration: task.isDone
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${task.category} · $caption',
                    style: AppTypography.bodySm.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            for (final action in actions)
              IconButton(
                tooltip: action.tooltip,
                onPressed: action.onPressed,
                icon: Icon(
                  action.icon,
                  size: 22,
                  color: action.destructive
                      ? colors.error
                      : colors.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
