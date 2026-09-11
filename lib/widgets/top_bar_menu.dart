import 'package:flutter/material.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';

enum TopBarMenuAction { sync, theme, addExtension }

/// The triple-dot overflow menu in the top app bar.
/// Options: Sync, Theme, Add Extension.
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
        _item(context, TopBarMenuAction.sync, Icons.sync, 'Sync'),
        _item(context, TopBarMenuAction.theme, Icons.palette_outlined, 'Theme', ),
        _item(
          context,
          TopBarMenuAction.addExtension,
          Icons.extension_outlined,
          'Add Extension',
        ),
      ],
    );
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
