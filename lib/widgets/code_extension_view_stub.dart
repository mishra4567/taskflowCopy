import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

/// Web fallback — flutter_eval is not bundled on web (avoids release build
/// issues and keeps the bundle smaller). JSON/data extensions still work.
class CodeExtensionView extends StatelessWidget {
  const CodeExtensionView({
    super.key,
    required this.source,
    this.entryFunction = 'buildExtension',
  });

  final String source;
  final String entryFunction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.phone_android, size: 40, color: colors.textSecondary),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Code extensions on web',
              style: AppTypography.bodyMd.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Dynamic Dart extensions run on Android, iOS, and desktop. '
              'On web, use extensions that provide JSON data only.',
              style: AppTypography.bodySm.copyWith(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
