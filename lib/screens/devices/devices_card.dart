// screens/morescreen/devices_card
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/api/device_session.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_typography.dart';
import '../../widgets/slide_page_route.dart';
import '../devices/link_this_phone_screen.dart';
import '../devices/scan_to_link_screen.dart';

/// Two ways to link phones, always both visible:
///  * Link this phone — shows a QR for an already-linked phone to scan.
///  * Link another phone — opens the camera to scan a new phone's QR.
/// A row that can't work right now still responds, with a reason, instead
/// of disappearing.
class DevicesCard extends StatefulWidget {
  const DevicesCard({super.key});

  @override
  State<DevicesCard> createState() => _DevicesCardState();
}

class _DevicesCardState extends State<DevicesCard> {
  late Future<bool> _connected = DeviceSession.instance.isSignedIn;

  void _refresh() {
    if (!mounted) return;
    setState(() => _connected = DeviceSession.instance.isSignedIn);
  }

  void _say(String message, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), action: action));
  }

  Future<void> _linkThisPhone() async {
    // A fresh read, not the cached future: the state may have changed
    // since the card was built.
    if (await DeviceSession.instance.isSignedIn) {
      _say(
        'This phone is already linked. To add a new phone, use '
        'Link another phone.',
      );
      _refresh();
      return;
    }
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(slidePageRoute((_) => const LinkThisPhoneScreen()));
    _refresh();
  }

  Future<void> _linkAnotherPhone() async {
    if (!await DeviceSession.instance.isSignedIn) {
      _say(
        "This phone isn't linked to an account yet, so it can't approve "
        'another one. Use Link this phone first.',
      );
      return;
    }

    // Ask for the camera first, so a "no" gets a real explanation
    // instead of a black preview.
    var status = await Permission.camera.status;
    if (!status.isGranted) status = await Permission.camera.request();
    if (!mounted) return;

    if (!status.isGranted) {
      final forever = status.isPermanentlyDenied;
      _say(
        forever
            ? 'Camera permission is off in Settings.'
            : 'TaskFlow needs the camera to scan a code.',
        action: forever
            ? SnackBarAction(label: 'Open Settings', onPressed: openAppSettings)
            : null,
      );
      return;
    }

    await Navigator.of(
      context,
    ).push(slidePageRoute((_) => const ScanToLinkScreen()));
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Card(
      child: FutureBuilder<bool>(
        future: _connected,
        builder: (context, snapshot) {
          // Nothing about the status until it's known, so a wrong badge
          // never flashes up first. The two rows don't depend on it.
          final connected = snapshot.data;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.devices_outlined,
                      size: 20,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'Devices',
                        style: AppTypography.bodyMd.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    if (connected != null) _StatusBadge(linked: connected),
                  ],
                ),
              ),
              Divider(height: 1, color: colors.borderSubtle),
              _LinkRow(
                icon: Icons.qr_code_2_outlined,
                title: 'Link this phone',
                subtitle: 'Show a code for another phone to scan',
                onTap: _linkThisPhone,
              ),
              Divider(height: 1, indent: 56, color: colors.borderSubtle),
              _LinkRow(
                icon: Icons.qr_code_scanner,
                title: 'Link another phone',
                subtitle: 'Scan the code shown on the new phone',
                onTap: _linkAnotherPhone,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.linked});
  final bool linked;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = linked ? colors.tertiary : colors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        linked ? 'LINKED' : 'NOT LINKED',
        style: AppTypography.labelCaps.copyWith(color: color, fontSize: 10),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: colors.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodyMd.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.bodySm.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: colors.outline),
          ],
        ),
      ),
    );
  }
}
