// widgets/quick_add_fab
import 'package:flutter/material.dart';
import '../../theme/app_palette.dart';

/// The shell's center-docked quick-add button. Kept as its own widget
/// (rather than inline in MainShell) so it can grow to show extension-
/// contributed actions without bloating main_shell.dart.
class QuickAddFab extends StatelessWidget {
  const QuickAddFab({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: 64,
      height: 64,
      child: Material(
        color: colors.primaryContainer,
        shape: const CircleBorder(),
        elevation: 3,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Icon(Icons.add, color: colors.onPrimary, size: 30),
        ),
      ),
    );
  }
}
