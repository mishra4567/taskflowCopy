// lib/widgets/top_bar_menu.dart
import 'package:flutter/material.dart';
import '../services/sync/sync_service.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';

enum TopBarMenuAction { sync, theme, addExtension }

// The triple-dot overflow menu in the top app bar.
// Options: Sync, Theme, Add Extension.
class TopBarMenu extends StatelessWidget {
  const TopBarMenu({super.key, required this.onSelected});

  final ValueChanged<TopBarMenuAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PopupMenuButton<TopBarMenuAction>(
      icon: Icon(Icons.more_vert, color: colors.onSurface),
      onSelected: onSelected,
      itemBuilder: (context) => [
        _syncItem(context),
        _item(context, TopBarMenuAction.theme, Icons.palette_outlined, 'Theme'),
        _item(
          context,
          TopBarMenuAction.addExtension,
          Icons.extension_outlined,
          'Add Extension',
        ),
      ],
    );
  }

  /// The Sync row: a spinner and "Syncing…" (and not tappable) while a
  /// sync is already running, otherwise "Sync" with when it last worked.
  PopupMenuItem<TopBarMenuAction> _syncItem(BuildContext context) {
    final colors = context.colors;
    final sync = SyncService.instance;
    final syncing = sync.isSyncing;
    final last = sync.lastSyncedAt;

    return PopupMenuItem(
      value: TopBarMenuAction.sync,
      enabled: !syncing,
      child: Row(
        children: [
          syncing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(Icons.sync, size: 18, color: colors.onSurfaceVariant),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                syncing ? 'Syncing…' : 'Sync',
                style: AppTypography.bodyMd.copyWith(color: colors.onSurface),
              ),
              if (!syncing && last != null)
                Text(
                  'Last synced ${_ago(last)}',
                  style: AppTypography.bodySm.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _ago(DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    return '${diff.inDays} d ago';
  }

  PopupMenuItem<TopBarMenuAction> _item(
    BuildContext context,
    TopBarMenuAction action,
    IconData icon,
    String label,
  ) {
    final colors = context.colors;
    return PopupMenuItem(
      value: action,
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.onSurfaceVariant),
          const SizedBox(width: 12),
          Text(
            label,
            style: AppTypography.bodyMd.copyWith(color: colors.onSurface),
          ),
        ],
      ),
    );
  }
}
