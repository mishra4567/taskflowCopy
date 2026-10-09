// screens/morescreen/alarm_sound_card.dart
import 'package:flutter/material.dart';
import '../../services/alarm_sound_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_typography.dart';

/// Settings card for the alarm ringtone — shows the current choice
/// (default, or an uploaded/built-in/system file's name), lets the user
/// preview it, upload a new one, or reset to the phone's default alarm
/// sound. Mirrors PermissionsCard's layout so Settings reads as one
/// consistent list rather than a one-off design.
class AlarmSoundCard extends StatefulWidget {
  const AlarmSoundCard({super.key});

  @override
  State<AlarmSoundCard> createState() => _AlarmSoundCardState();
}

class _AlarmSoundCardState extends State<AlarmSoundCard> {
  late Future<List<BuiltInSoundAsset>> _builtInSoundsFuture;

  @override
  void initState() {
    super.initState();
    AlarmSoundService.instance.load();
    _builtInSoundsFuture = AlarmSoundService.instance.listBuiltInSoundAssets();
  }

  Future<void> _upload() async {
    final service = AlarmSoundService.instance;
    final result = await service.pickAndImport();
    if (!mounted) return;
    if (result.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.error!)));
    } else if (result.changed) {
      await NotificationService.instance.rescheduleAllAlarms();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Alarm sound set to "${service.current.name}"')),
      );
    }
  }

  Future<void> _selectBuiltIn(BuiltInSoundAsset sound) async {
    final service = AlarmSoundService.instance;
    final result = await service.selectBuiltInAsset(sound);
    if (!mounted) return;
    if (result.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.error!)));
      return;
    }
    await NotificationService.instance.rescheduleAllAlarms();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Alarm sound set to "${sound.displayName}"')),
    );
  }

  Future<void> _pickFromPhone() async {
    final service = AlarmSoundService.instance;
    final result = await service.pickSystemRingtone();
    if (!mounted) return;
    if (result.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.error!)));
    } else if (result.changed) {
      await NotificationService.instance.rescheduleAllAlarms();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Alarm sound set to "${service.current.name}"')),
      );
    }
  }

  Future<void> _togglePreview() async {
    final service = AlarmSoundService.instance;
    if (service.isPreviewing) {
      await service.stopPreview();
      return;
    }
    final error = await service.preview();
    if (!mounted || error == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  Future<void> _reset() async {
    await AlarmSoundService.instance.resetToDefault();
    await NotificationService.instance.rescheduleAllAlarms();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reset to the default alarm sound')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Card(
      child: AnimatedBuilder(
        animation: AlarmSoundService.instance,
        builder: (context, _) {
          final service = AlarmSoundService.instance;
          final sound = service.current;
          final previewing = service.isPreviewing;

          return Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.alarm, size: 20, color: colors.onSurfaceVariant),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Alarm sound',
                            style: AppTypography.bodyMd.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            sound.name,
                            style: AppTypography.bodySm.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: previewing ? 'Stop preview' : 'Preview',
                      icon: Icon(
                        previewing
                            ? Icons.stop_circle_outlined
                            : Icons.play_circle_outline,
                        color: colors.primaryContainer,
                      ),
                      onPressed: _togglePreview,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    TextButton.icon(
                      onPressed: _pickFromPhone,
                      icon: const Icon(Icons.library_music_outlined, size: 18),
                      label: const Text('Choose from phone'),
                    ),
                    TextButton.icon(
                      onPressed: _upload,
                      icon: const Icon(Icons.upload_file_outlined, size: 18),
                      label: const Text('Upload sound'),
                    ),
                    if (sound.isCustom)
                      TextButton.icon(
                        onPressed: _reset,
                        icon: const Icon(Icons.restore_outlined, size: 18),
                        label: const Text('Reset to default'),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'BUILT-IN',
                  style: AppTypography.labelCaps.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                FutureBuilder<List<BuiltInSoundAsset>>(
                  future: _builtInSoundsFuture,
                  builder: (context, snapshot) {
                    final sounds = snapshot.data;
                    if (sounds == null) {
                      return const SizedBox(
                        height: 32,
                        child: Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    }
                    if (sounds.isEmpty) {
                      return Text(
                        'No built-in sounds bundled.',
                        style: AppTypography.bodySm.copyWith(
                          color: colors.textSecondary,
                        ),
                      );
                    }
                    return Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final builtIn in sounds)
                          _BuiltInChip(
                            label: builtIn.displayName,
                            // A built-in selection is always ownedByApp
                            // (it's imported into MediaStore on pick), so
                            // checking the name alone can't be confused
                            // with a same-named uploaded or system sound
                            // that isn't ownedByApp.
                            selected:
                                sound.ownedByApp &&
                                sound.name == builtIn.displayName,
                            onTap: () => _selectBuiltIn(builtIn),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Selectable chip for one built-in sound — same selected/unselected
/// treatment as _FilterChip in todo_screen.dart, so this reads as the
/// same control language elsewhere in the app rather than a one-off.
class _BuiltInChip extends StatelessWidget {
  const _BuiltInChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = colors.primaryContainer;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.2)
              : colors.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? accent : colors.borderSubtle),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check, size: 14, color: accent),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: AppTypography.bodySm.copyWith(
                color: selected ? accent : colors.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
