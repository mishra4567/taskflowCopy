// widgets/permissions_card
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_typography.dart';

/// Live permission status for everything TaskFlow's notification/alarm
/// feature actually needs — not a static list, each row reflects the
/// device's real current grant state. Refreshes on tap and whenever the
/// app resumes (e.g. coming back from the system settings screen after
/// granting something there), so the status shown is never stale.
/// Shared between MoreScreen and SettingsScreen so both show the exact
/// same tracked permissions and logic rather than two copies drifting
/// apart.
const _trackedPermissions = [
  Permission.notification,
  Permission.scheduleExactAlarm,
];

String _permissionLabel(Permission permission) {
  if (permission == Permission.notification) return 'Notifications';
  if (permission == Permission.scheduleExactAlarm) return 'Exact Alarms';
  return permission.toString();
}

IconData _permissionIcon(Permission permission) {
  if (permission == Permission.notification) return Icons.notifications_none;
  if (permission == Permission.scheduleExactAlarm) return Icons.alarm;
  return Icons.lock_outline;
}

class PermissionsCard extends StatefulWidget {
  const PermissionsCard({super.key});

  @override
  State<PermissionsCard> createState() => _PermissionsCardState();
}

class _PermissionsCardState extends State<PermissionsCard>
    with WidgetsBindingObserver {
  final Map<Permission, PermissionStatus> _statuses = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Catches coming back from the OS settings screen after granting
    // (or revoking) a permission there.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    for (final permission in _trackedPermissions) {
      final status = await permission.status;
      if (!mounted) return;
      setState(() => _statuses[permission] = status);
    }
  }

  Future<void> _handleTap(Permission permission) async {
    final status = _statuses[permission];
    if (status != null && status.isPermanentlyDenied) {
      // The system won't show its own request dialog again once a
      // permission is permanently denied — only the app's own settings
      // page can change it from here.
      await openAppSettings();
    } else {
      await permission.request();
    }
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < _trackedPermissions.length; i++) ...[
            _PermissionRow(
              icon: _permissionIcon(_trackedPermissions[i]),
              label: _permissionLabel(_trackedPermissions[i]),
              status: _statuses[_trackedPermissions[i]],
              onTap: () => _handleTap(_trackedPermissions[i]),
            ),
            if (i != _trackedPermissions.length - 1)
              Divider(height: 1, indent: 56, color: colors.borderSubtle),
          ],
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.label,
    required this.status,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final PermissionStatus? status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final loading = status == null;
    final granted = status?.isGranted ?? false;

    return InkWell(
      onTap: granted ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: colors.onSurfaceVariant),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: AppTypography.bodyMd.copyWith(color: colors.textPrimary),
              ),
            ),
            if (loading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: (granted ? colors.tertiary : colors.error).withValues(
                    alpha: 0.16,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  granted ? 'Allowed' : 'Tap to allow',
                  style: AppTypography.labelCaps.copyWith(
                    color: granted ? colors.tertiary : colors.error,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
