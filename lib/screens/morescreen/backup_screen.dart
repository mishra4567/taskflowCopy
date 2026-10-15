// screens/morescreen/backup_screen.dart
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../services/backUp/backup_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_typography.dart';

/// Backup & restore, as its own page (opened from the Backup row under
/// Data Management on the More screen).
///
/// BackupService only deals in bytes — createBackup returns the zip,
/// restore takes it — so everything about *files* (the save dialog and
/// the file picker) lives here.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _exporting = false;
  bool _restoring = false;

  /// One at a time: starting a restore in the middle of a backup (or the
  /// reverse) would have both reading and writing the database at once.
  bool get _busy => _exporting || _restoring;

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
    return Scaffold(
      appBar: AppBar(title: const Text('Backup')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.containerMargin,
          AppSpacing.md,
          AppSpacing.containerMargin,
          AppSpacing.xl,
        ),
        children: [
          Text(
            'Keep a copy of your tasks and contacts in a file, so you can '
            'bring them back on this phone or a new one.',
            style: AppTypography.bodySm.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          _ActionCard(
            icon: Icons.backup_outlined,
            title: 'Back up now',
            subtitle: 'Save a .zip of your tasks and contacts',
            busy: _exporting,
            onTap: _busy ? null : _export,
          ),
          const SizedBox(height: AppSpacing.sm),
          _ActionCard(
            icon: Icons.restore_page_outlined,
            title: 'Restore from backup',
            subtitle: 'Choose a backup file to add from',
            busy: _restoring,
            onTap: _busy ? null : _restore,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'WHAT\'S INCLUDED',
            style: AppTypography.labelCaps.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                'Tasks, with their subtasks, dates and reminder settings, '
                'and your contacts. App settings and alarm sounds are not '
                'included.',
                style: AppTypography.bodySm.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A tappable action row in the same style as the Home module cards: icon
/// box, title/subtitle, and a spinner in place of the chevron while it's
/// running. Dims when [onTap] is null because the *other* action is busy.
class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.busy,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Opacity(
      opacity: onTap == null && !busy ? 0.5 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.container),
        child: Card(
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
                  child: Icon(icon, color: colors.primary, size: 22),
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
                const SizedBox(width: AppSpacing.sm),
                busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: colors.outline,
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
