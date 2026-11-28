// widgets/sync_snackbar
import 'package:flutter/material.dart';

import '../services/sync/sync_service.dart';
import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

/// Runs a sync from the top-bar menu and shows it in the bottom bar: a
/// progress line with what's happening ("Sending 3 changes…") while it
/// runs, then a result message in its place — what moved, or what went
/// wrong with a Retry (or Sign in) button.
///
/// [onSignIn] is what the "Sign in" button does when this phone isn't
/// linked to an account yet (MainShell sends the person to the More tab).
Future<void> runSyncWithSnackBar(
  BuildContext context, {
  VoidCallback? onSignIn,
}) async {
  // Taken before the first await: the messenger outlives this call, the
  // context may not.
  final messenger = ScaffoldMessenger.of(context);
  final sync = SyncService.instance;

  void say(SnackBar bar) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(bar);
  }

  if (sync.isSyncing) {
    say(const SnackBar(content: Text('Already syncing…')));
    return;
  }

  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(_progressBar());

  final outcome = await sync.syncNow();

  switch (outcome) {
    case SyncOutcome.done:
      say(SnackBar(content: Text(_doneMessage(sync))));
    case SyncOutcome.busy:
      say(const SnackBar(content: Text('Already syncing…')));
    case SyncOutcome.notSignedIn:
      say(
        SnackBar(
          content: const Text('Sign in to sync your data.'),
          action: onSignIn == null
              ? null
              : SnackBarAction(label: 'Sign in', onPressed: onSignIn),
        ),
      );
    case SyncOutcome.failed:
      say(
        SnackBar(
          content: Text(sync.lastError ?? "Couldn't sync. Try again."),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () {
              if (context.mounted) {
                runSyncWithSnackBar(context, onSignIn: onSignIn);
              }
            },
          ),
        ),
      );
  }
}

String _doneMessage(SyncService sync) {
  final parts = <String>[
    if (sync.lastSent > 0) 'sent ${sync.lastSent}',
    if (sync.lastReceived > 0) 'received ${sync.lastReceived}',
  ];
  return parts.isEmpty
      ? 'Everything is up to date'
      : 'Synced · ${parts.join(', ')}';
}

/// The in-progress bar. Stays until the sync finishes (a day is just
/// "longer than any sync"); runSyncWithSnackBar replaces it with the
/// result. Rebuilds from SyncService, so the text and the bar follow the
/// sync's own progress.
SnackBar _progressBar() {
  return SnackBar(
    duration: const Duration(days: 1),
    content: ListenableBuilder(
      listenable: SyncService.instance,
      builder: (context, _) {
        final colors = context.colors;
        final sync = SyncService.instance;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sync.phase.isEmpty ? 'Syncing…' : sync.phase,
              style: AppTypography.bodySm.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: LinearProgressIndicator(
                // null = "working, amount unknown" (animated); a number is
                // the share of changes sent so far.
                value: sync.progress,
                minHeight: 4,
                color: colors.primaryContainer,
                backgroundColor: colors.surfaceContainerHigh,
              ),
            ),
          ],
        );
      },
    ),
  );
}
