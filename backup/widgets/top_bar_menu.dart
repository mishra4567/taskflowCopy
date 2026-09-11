import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

enum TopBarMenuAction { sync, theme, addExtension, toggleLightDark }

/// The triple-dot overflow menu in the top app bar.
/// Options: Sync, Theme, Add Extension, Light / Dark.
class TopBarMenu extends StatelessWidget {
  const TopBarMenu({super.key, required this.onSelected});

  final ValueChanged<TopBarMenuAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<TopBarMenuAction>(
      icon: const Icon(Icons.more_vert, color: AppColors.onSurface),
      onSelected: onSelected,
      itemBuilder: (context) => [
        _item(TopBarMenuAction.sync, Icons.sync, 'Sync'),
        _item(TopBarMenuAction.theme, Icons.palette_outlined, 'Theme'),
        _item(
          TopBarMenuAction.addExtension,
          Icons.extension_outlined,
          'Add Extension',
        ),
        _item(
          TopBarMenuAction.toggleLightDark,
          Icons.dark_mode_outlined,
          'Light / Dark',
        ),
      ],
    );
  }

  PopupMenuItem<TopBarMenuAction> _item(
    TopBarMenuAction action,
    IconData icon,
    String label,
  ) {
    return PopupMenuItem(
      value: action,
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.onSurfaceVariant),
          const SizedBox(width: 12),
          Text(label, style: AppTypography.bodyMd),
        ],
      ),
    );
  }
}
