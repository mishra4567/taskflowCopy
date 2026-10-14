// screens/morescreen/more_screen.dart
import 'package:flutter/material.dart';
import 'package:taskflow/services/archive_trash_service.dart'; // ARCHIVE
import 'package:taskflow/services/todo_refresh_bus.dart'; // ARCHIVE
import 'package:taskflow/theme/app_palette.dart';
import 'package:taskflow/theme/app_tokens.dart';
import 'package:taskflow/theme/app_typography.dart';
import 'package:taskflow/theme/theme_controller.dart';
import 'package:taskflow/widgets/slide_page_route.dart';
import 'package:taskflow/widgets/theme_picker_dialog.dart';
import 'package:taskflow/screens/morescreen/bin_trash/archive_screen.dart'; // ARCHIVE
import 'package:taskflow/screens/morescreen/settings_screen.dart'; // ← adjust if settings_screen.dart lives elsewhere
import 'package:taskflow/screens/morescreen/bin_trash/trash_screen.dart'; // ARCHIVE


/// More page — Archive, Trash, Settings, Theme, Account.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.containerMargin,
        AppSpacing.md,
        AppSpacing.containerMargin,
        140,
      ),
      children: [
        Text(
          'More',
          style: AppTypography.headlineMd.copyWith(color: colors.textPrimary),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'DATA MANAGEMENT',
          style: AppTypography.labelCaps.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        // ARCHIVE: was a const _SectionCard with two inert rows and a
        // hardcoded red dot. Now real counts, real navigation.
        const _BinRows(),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'PREFERENCES',
          style: AppTypography.labelCaps.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Rebuilds just this row when the theme mode changes, so the
        // trailing label (Dark (OLED) / Light / System) stays in sync.
        ValueListenableBuilder<ThemeMode>(
          valueListenable: themeController,
          builder: (context, mode, _) {
            return _SectionCard(
              rows: [
                _RowSpec(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  onTap: () => Navigator.of(
                    context,
                  ).push(slidePageRoute((_) => const SettingsScreen())),
                ),
                _RowSpec(
                  icon: Icons.system_update,
                  label: 'APP Update',
                  trailingText: '1.0.1',
                  showBadge: true,
                ),
                _RowSpec(
                  icon: Icons.palette_outlined,
                  label: 'Theme',
                  trailingText: ThemeController.label(mode),
                  onTap: () => showThemePickerDialog(context),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'ACCOUNT',
          style: AppTypography.labelCaps.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: colors.surfaceContainerHigh,
                  child: Icon(Icons.person, color: colors.onSurfaceVariant),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'John Doe',
                        style: AppTypography.bodyMd.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        'john.doe@example.com',
                        style: AppTypography.bodySm.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: colors.outline),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ARCHIVE: Archive + Trash Can rows with live counts. Reloads whenever
// TaskBinService (or anything else) fires TodoRefreshBus.
class _BinRows extends StatefulWidget {
  const _BinRows();

  @override
  State<_BinRows> createState() => _BinRowsState();
}

class _BinRowsState extends State<_BinRows> {
  int _archived = 0;
  int _trashed = 0;

  @override
  void initState() {
    super.initState();
    _load();
    TodoRefreshBus.tick.addListener(_load);
  }

  @override
  void dispose() {
    TodoRefreshBus.tick.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final archived = await TaskBinService.instance.archivedCount();
    final trashed = await TaskBinService.instance.trashedCount();
    if (!mounted) return;
    setState(() {
      _archived = archived;
      _trashed = trashed;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      rows: [
        _RowSpec(
          icon: Icons.inventory_2_outlined,
          label: 'Archive',
          trailingText: _archived == 0 ? null : '$_archived',
          onTap: () => Navigator.of(
            context,
          ).push(slidePageRoute((_) => const ArchiveScreen())),
        ),
        _RowSpec(
          icon: Icons.delete_outline,
          label: 'Trash Can',
          trailingText: _trashed == 0 ? null : '$_trashed',
          onTap: () => Navigator.of(
            context,
          ).push(slidePageRoute((_) => const TrashScreen())),
        ),
      ],
    );
  }
}

class _RowSpec {
  const _RowSpec({
    required this.icon,
    required this.label,
    this.trailingText,
    this.onTap,
    this.showBadge = false,
  });
  final IconData icon;
  final String label;
  final String? trailingText;
  final VoidCallback? onTap;
  final bool showBadge;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.rows});
  final List<_RowSpec> rows;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _MoreRow(spec: rows[i]),
            if (i != rows.length - 1)
              Divider(height: 1, indent: 56, color: colors.borderSubtle),
          ],
        ],
      ),
    );
  }
}

class _MoreRow extends StatelessWidget {
  const _MoreRow({required this.spec});
  final _RowSpec spec;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: spec.onTap ?? () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(spec.icon, size: 20, color: colors.onSurfaceVariant),
                if (spec.showBadge)
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
              child: Text(
                spec.label,
                style: AppTypography.bodyMd.copyWith(color: colors.textPrimary),
              ),
            ),
            if (spec.trailingText != null)
              Text(
                spec.trailingText!,
                style: AppTypography.bodySm.copyWith(color: colors.primary),
              ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: colors.outline),
          ],
        ),
      ),
    );
  }
}
