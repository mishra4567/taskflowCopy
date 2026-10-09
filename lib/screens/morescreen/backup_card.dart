// screens/morescreen/backup_card.dart
import 'package:flutter/material.dart';
import '../../services/backup_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_typography.dart';

/// Settings card for backup/restore. "Back up now" zips a JSON dump of
/// the database and lets the user choose where to save it; "Restore"
/// picks a .zip back in and merges its tasks in (skipping anything
/// already present by id). Mirrors AlarmSoundCard's layout (icon,
/// title/subtitle, action row) so Settings keeps reading as one
/// consistent list.
class BackupCard extends StatefulWidget {
  const BackupCard({super.key});

  @override
  State<BackupCard> createState() => _BackupCardState();
}

class _BackupCardState extends State<BackupCard> {
  bool _exporting = false;
  bool _restoring = false;

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final savedPath = await BackupService.exportToZip();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            savedPath == null ? 'Backup cancelled' : 'Backup saved',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't create the backup")),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _restore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore from backup?'),
        content: const Text(
          'This adds tasks from the backup that you don\'t already have. '
          'Anything already in TaskFlow is left exactly as it is.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Choose backup file'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _restoring = true);
    try {
      final summary = await BackupService.importFromZip();
      if (!mounted) return;
      if (summary.cancelled) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Restore cancelled')));
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added ${summary.todosAdded}, skipped ${summary.todosSkipped} '
            '(already present)',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't restore from that file")),
      );
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.backup_outlined,
                  size: 20,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Backup',
                        style: AppTypography.bodyMd.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Export or restore your tasks as a .zip',
                        style: AppTypography.bodySm.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _actionsRow(colors),
          ],
        ),
      ),
    );
  }

  Widget _actionsRow(AppPalette colors) {
    return Wrap(
      spacing: AppSpacing.sm,
      children: [
        _exporting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton.icon(
                onPressed: _export,
                icon: const Icon(Icons.backup_outlined, size: 18),
                label: const Text('Back up now'),
              ),
        _restoring
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton.icon(
                onPressed: _restore,
                icon: const Icon(Icons.restore_page_outlined, size: 18),
                label: const Text('Restore'),
              ),
      ],
    );
  }
}
