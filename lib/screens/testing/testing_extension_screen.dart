/// screens/testing/testing_extension_screen.dart
///
/// Placeholder for the Contacts/Testing extension while the real
/// implementation is on hold. onBack stays nullable so this screen keeps
/// working whether or not a caller has a "previous page" to return to.
import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/quick_add/quick_add_sheet.dart'
    show QuickAddAction, QuickAddRegistry;

class TestingExtensionScreen extends StatelessWidget {
  const TestingExtensionScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(
        leading: onBack == null
            ? null
            : IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack),
        title: const Text('Contacts Extension'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.construction_outlined,
              size: 40,
              color: colors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              'Coming soon',
              style: AppTypography.bodyLg.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'The Contacts extension isn\'t ready yet.',
              style: AppTypography.bodySm.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Registers "Add Contact" as a quick-add card. [onTap] is nullable on
/// purpose: call this now with no argument to get a working card that
/// tells the user the feature is coming soon, and later — once a real
/// add-contact flow exists — call it again passing a real callback. The
/// call site (e.g. MainShell.initState) doesn't need to change either
/// way, just the argument.
void registerQuickAddContact({void Function(BuildContext context)? onTap}) {
  QuickAddRegistry.register(
    QuickAddAction(
      icon: Icons.person_add_alt,
      title: 'Add Contact',
      subtitle: 'Save a name and number',
      onTap: (context) {
        Navigator.of(context).pop();
        if (onTap != null) {
          onTap(context);
        } else {
          showAppSnackBar(context, 'Contacts extension coming soon');
        }
      },
    ),
  );
}
