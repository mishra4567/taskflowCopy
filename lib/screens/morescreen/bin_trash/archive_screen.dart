// screens/morescreen/archive_screen.dart
import 'package:flutter/material.dart';
import 'package:taskflow/services/archive_trash_service.dart';
import 'package:taskflow/services/todo_refresh_bus.dart';
import 'package:taskflow/theme/app_palette.dart';
import 'package:taskflow/theme/app_tokens.dart';
import 'package:taskflow/theme/app_typography.dart';
import 'bin_task_tile.dart';

/// Archived tasks: finished-and-tucked-away, or archived by hand. Nothing
/// here is ever deleted automatically.
class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  List<BinEntry>? _entries;

  @override
  void initState() {
    super.initState();
    _load();
    // Every TaskBinService change fires this, so the list stays current
    // without reloading by hand after each action.
    TodoRefreshBus.tick.addListener(_load);
  }

  @override
  void dispose() {
    TodoRefreshBus.tick.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final entries = await TaskBinService.instance.archived();
    if (!mounted) return;
    setState(() => _entries = entries);
  }

  void _snack(String message, {VoidCallback? undo}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: undo == null
              ? null
              : SnackBarAction(label: 'Undo', onPressed: undo),
        ),
      );
  }

  Future<void> _unarchive(BinEntry entry) async {
    await TaskBinService.instance.unarchive(entry.task.id);
    _snack(
      'Moved back to your list',
      undo: () => TaskBinService.instance.archive(entry.task.id),
    );
  }

  Future<void> _moveToTrash(BinEntry entry) async {
    await TaskBinService.instance.moveToTrash(entry.task.id);
    _snack(
      'Moved to Trash',
      undo: () => TaskBinService.instance.restoreFromTrash(entry.task.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final entries = _entries;
    final days = TaskBinService.autoArchiveAfter.inDays;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Archive'),
        actions: const [BackupNowButton()],
      ),
      body: entries == null
          ? const Center(child: CircularProgressIndicator())
          : entries.isEmpty
          ? BinEmptyState(
              icon: Icons.inventory_2_outlined,
              message:
                  'Nothing archived yet.\nCompleted tasks move here '
                  'automatically after $days days.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.containerMargin,
                AppSpacing.md,
                AppSpacing.containerMargin,
                AppSpacing.lg,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Text(
                    'Completed tasks move here after $days days. '
                    'They stay until you delete them.',
                    style: AppTypography.bodySm.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                for (final entry in entries)
                  BinTaskTile(
                    task: entry.task,
                    caption: 'Archived ${formatBinDate(entry.archivedAt!)}',
                    actions: [
                      BinAction(
                        icon: Icons.unarchive_outlined,
                        tooltip: 'Move back to list',
                        onPressed: () => _unarchive(entry),
                      ),
                      BinAction(
                        icon: Icons.delete_outline,
                        tooltip: 'Move to Trash',
                        destructive: true,
                        onPressed: () => _moveToTrash(entry),
                      ),
                    ],
                  ),
              ],
            ),
    );
  }
}
