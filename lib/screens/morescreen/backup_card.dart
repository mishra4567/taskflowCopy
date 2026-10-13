// screens/morescreen/backup_card.dart
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../services/backUp/backup_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_typography.dart';

/// Settings card for backup/restore. "Back up now" builds the backup zip
/// and lets the user choose where to save it; "Restore" picks a backup
/// back in and merges it into the app. Mirrors AlarmSoundCard's layout
/// (icon, title/subtitle, action row) so Settings keeps reading as one
/// consistent list.
///
/// BackupService only deals in bytes (createBackup returns the zip,
/// restore takes it), so everything about *files* — the save dialog and
/// the file picker — lives here.
class BackupCard extends StatefulWidget {
  const BackupCard({super.key});

  @override
  State<BackupCard> createState() => _BackupCardState();
}

class _BackupCardState extends State<BackupCard> {
  bool _exporting = false;
  bool _restoring = false;

  /// e.g. 2026-10-13_1425 — so each backup gets its own file name
  /// instead of every one being called taskflow_backup.zip.
  String _stamp() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}-${two(n.month)}-${two(n.day)}_${two(n.hour)}${two(n.minute)}';
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final bytes = await BackupService.createBackup();

      // file_picker's saveFile writes the bytes wherever the person
      // picks — on Android that's the only way to get a file out of
      // app-private storage to somewhere they can find and share it.
      final saved = await FilePicker.saveFile(
        fileName: 'taskflow_backup_${_stamp()}.zip',
        bytes: bytes,
        dialogTitle: 'Save TaskFlow backup',
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      if (!mounted) return;
      _toast(saved == null ? 'Backup cancelled' : 'Backup saved');
    } on BackupException catch (e) {
      if (!mounted) return;
      _toast(e.message);
    } catch (_) {
      if (!mounted) return;
      _toast("Couldn't create the backup");
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
          'Tasks and contacts from the backup are added to what you '
          'already have. If a task from the backup is already here, the '
          "backup's version replaces it. Nothing else is removed.",
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
      // The service accepts the .zip, or a bare taskflow_backup.json.
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['zip', 'json'],
      );
      if (file == null || file.path == null) {
        if (!mounted) return;
        _toast('Restore cancelled');
        return;
      }

      final bytes = await File(file.path!).readAsBytes();
      final result = await BackupService.restore(bytes);
      if (!mounted) return;
      _toast(result.summary);
    } on BackupException catch (e) {
      // BackupException messages are written to be shown as-is.
      if (!mounted) return;
      _toast(e.message);
    } catch (_) {
      if (!mounted) return;
      _toast("Couldn't restore from that file");
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
                        'Export or restore your tasks and contacts as a .zip',
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
