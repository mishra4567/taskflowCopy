import 'package:flutter/material.dart';
import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

class _NotificationItem {
  const _NotificationItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
    this.unread = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String time;
  final bool unread;
}

const _notifications = [
  _NotificationItem(
    icon: Icons.check_circle_outline,
    title: 'Task due tomorrow',
    subtitle: '"Finalize Q3 Strategy Deck" is due tomorrow.',
    time: '2h ago',
    unread: true,
  ),
  _NotificationItem(
    icon: Icons.map_outlined,
    title: 'Roadmap milestone reached',
    subtitle: '"Product V2" just hit 45% complete.',
    time: '5h ago',
    unread: true,
  ),
  _NotificationItem(
    icon: Icons.sync,
    title: 'Sync complete',
    subtitle: 'Your tasks and roadmaps are up to date.',
    time: 'Yesterday',
  ),
  _NotificationItem(
    icon: Icons.system_update,
    title: 'Update available',
    subtitle: 'TaskFlow 1.0.1 is ready to install.',
    time: '2 days ago',
  ),
];

/// Pushed from the bell icon in the top bar — not part of the bottom nav,
/// so it gets its own Scaffold with a back-arrow AppBar.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () {},
            child: Text(
              'Mark all read',
              style: AppTypography.bodySm.copyWith(color: colors.primary),
            ),
          ),
        ],
      ),
      body: _notifications.isEmpty
          ? _EmptyState(colors: colors)
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.containerMargin,
                AppSpacing.md,
                AppSpacing.containerMargin,
                AppSpacing.xl,
              ),
              itemCount: _notifications.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) =>
                  _NotificationCard(item: _notifications[i]),
            ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item});
  final _NotificationItem item;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppRadius.standard),
                  ),
                  child: Icon(item.icon, size: 20, color: colors.primary),
                ),
                if (item.unread)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: colors.error,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colors.surfaceContainer,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: AppTypography.bodyMd.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style: AppTypography.bodySm.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.time,
                    style: AppTypography.monoUtility.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.colors});
  final AppPalette colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none, size: 40, color: colors.outline),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No notifications yet',
            style: AppTypography.bodyMd.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
