// screens/morescreen/trash_screen.dart
import 'package:flutter/material.dart';
import 'package:taskflow/services/archive_trash_service.dart';
import 'package:taskflow/services/todo_refresh_bus.dart';
import 'package:taskflow/theme/app_palette.dart';
import 'package:taskflow/theme/app_tokens.dart';
import 'package:taskflow/theme/app_typography.dart';
import 'bin_task_tile.dart';

/// Deleted tasks. They stay here until the person empties the Trash
/// themselves — there is deliberately no automatic purge.
class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  List<BinEntry>? _entries;

  @override
  void initState() {
    super.initState();
    _load();
    TodoRefreshBus.tick.addListener(_load);
  }

  @override
  void dispose() {
    TodoRefreshBus.tick.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final entries = await TaskBinService.instance.trashed();
    if (!mounted) return;
    setState(() => _entries = entries);
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _restore(BinEntry entry) async {
    await TaskBinService.instance.restoreFromTrash(entry.task.id);
    // A task that was archived before it was deleted goes back to the
    // Archive, not the main list — restoring undoes the delete only.
    _snack(
      entry.archivedAt != null
          ? 'Restored to Archive'
          : 'Restored to your list',
    );
  }

  Future<void> _deleteForever(BinEntry entry) async {
    final ok = await confirmDestructive(
      context,
      title: 'Delete forever?',
      message: '"${entry.task.title}" will be permanently deleted.',
      confirmLabel: 'Delete',
    );
    if (!ok || !mounted) return;
    await TaskBinService.instance.deleteForever(entry.task.id);
    _snack('Deleted permanently');
  }

  Future<void> _emptyTrash() async {
    final count = _entries?.length ?? 0;
    if (count == 0) return;
    final ok = await confirmDestructive(
      context,
      title: 'Empty Trash?',
      message:
          "Permanently delete $count task${count == 1 ? '' : 's'}? "
          "This can't be undone.",
      confirmLabel: 'Empty Trash',
    );
    if (!ok || !mounted) return;
    final deleted = await TaskBinService.instance.emptyTrash();
    _snack('Deleted $deleted task${deleted == 1 ? '' : 's'} permanently');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final entries = _entries;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trash Can'),
        actions: [
          TextButton(
            onPressed: (entries == null || entries.isEmpty)
                ? null
                : _emptyTrash,
            child: const Text('Empty'),
          ),
        ],
      ),
      body: entries == null
          ? const Center(child: CircularProgressIndicator())
          : entries.isEmpty
          ? const BinEmptyState(
              icon: Icons.delete_outline,
              message:
                  'The Trash is empty.\n'
                  'Deleted tasks stay here until you empty it.',
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
                    'Tasks stay here until you empty the Trash.',
                    style: AppTypography.bodySm.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                for (final entry in entries)
                  BinTaskTile(
                    task: entry.task,
                    caption: 'Deleted ${formatBinDate(entry.deletedAt!)}',
                    actions: [
                      BinAction(
                        icon: Icons.restore_from_trash_outlined,
                        tooltip: 'Restore',
                        onPressed: () => _restore(entry),
                      ),
                      BinAction(
                        icon: Icons.delete_forever_outlined,
                        tooltip: 'Delete forever',
                        destructive: true,
                        onPressed: () => _deleteForever(entry),
                      ),
                    ],
                  ),
              ],
            ),
    );
  }
}
