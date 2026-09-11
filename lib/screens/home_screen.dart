// screens/home_screen
import 'package:flutter/material.dart';
import 'package:taskflow/extensions/extension_manager.dart';
import 'package:taskflow/screens/todo_screen.dart';
// import 'package:taskflow/screens/roadmap_screen.dart';
import 'package:taskflow/screens/contacts_screen.dart';
// import 'package:taskflow/screens/timeline_screen.dart';
import 'package:taskflow/widgets/slide_page_route.dart';
import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

/// Home page — the entry list of built-in + extension-provided modules
/// (TODO list, TODO Roadmap, Contacts, …).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onOpenCalendar});

  /// Calendar lives on the bottom nav, so tapping its card here switches
  /// the shell's active tab instead of pushing a new route.
  final VoidCallback onOpenCalendar;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  Set<String> _installedIds = {};

  @override
  void initState() {
    super.initState();
    _refreshExtensions();
  }

  Future<void> _refreshExtensions() async {
    try {
      final installed = await ExtensionManager.instance.loadInstalled();
      if (!mounted) return;
      setState(() {
        _installedIds = installed.map((e) => e.manifest.id).toSet();
        _loading = false;
      });
    } catch (_) {
      // If the extensions folder can't be read for some reason, fail
      // toward "nothing installed" rather than leaving Home stuck loading.
      if (!mounted) return;
      setState(() {
        _installedIds = {};
        _loading = false;
      });
    }
  }

  /// Re-check installed extensions whenever the user comes back to Home —
  /// e.g. after installing Contacts from the Extensions page and pressing
  /// back — so the card appears without needing an app restart.
  Future<void> _navigateAndRefresh(Widget screen) async {
    await Navigator.of(context).push(slidePageRoute((_) => screen));
    _refreshExtensions();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final contactsInstalled = _installedIds.contains('contacts');

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.containerMargin,
        AppSpacing.md,
        AppSpacing.containerMargin,
        140,
      ),
      children: [
        _ModuleCard(
          icon: Icons.check_circle_outline,
          iconColor: colors.primary,
          title: 'TODO List',
          subtitle: '3 tasks due this week',
          trailing: const _CountBadge(count: 3),
          onTap: () => _navigateAndRefresh(const TodoScreen()),
        ),
        const SizedBox(height: AppSpacing.sm),
        _ModuleCard(
          icon: Icons.calendar_month_outlined,
          iconColor: colors.primary,
          title: 'Calendar',
          subtitle: 'Two-way sync with Google Calendar',
          onTap: widget.onOpenCalendar,
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'EXTENSIONS',
          style: AppTypography.labelCaps.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        _ModuleCard(
          icon: Icons.map_outlined,
          iconColor: colors.tertiary,
          title: 'TODO Roadmap',
          subtitle: 'Product V2 · 45% complete',
          trailing: _ProgressBadge(percent: 0.45, color: colors.primary),

          /// onTap: () => _navigateAndRefresh(const RoadmapScreen()),
        ),
        const SizedBox(height: AppSpacing.md),
        _ModuleCard(
          icon: Icons.view_timeline_outlined,
          iconColor: colors.tertiary,
          title: 'TIME Stamp',
          subtitle: 'Add Your · Timeline',
          trailing: const _CountBadge(count: 3),

          /// onTap: () => _navigateAndRefresh(const TimelineScreen()),
        ),

        // Only shown once the Contacts extension is actually installed —
        // no dead-end card pointing at a feature that won't work yet.
        if (!_loading && contactsInstalled) ...[
          const SizedBox(height: AppSpacing.md),
          _ModuleCard(
            icon: Icons.people_outline,
            iconColor: colors.secondary,
            title: 'Contacts',
            subtitle: '12 people',
            onTap: () => _navigateAndRefresh(const ContactsScreen()),
          ),
        ],
      ],
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.container),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppRadius.standard),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.bodyMd.copyWith(
                        fontWeight: FontWeight.w600,
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
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        '$count',
        style: AppTypography.bodySm.copyWith(color: colors.onSurface),
      ),
    );
  }
}

class _ProgressBadge extends StatelessWidget {
  const _ProgressBadge({required this.percent, required this.color});
  final double percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: percent,
            strokeWidth: 3,
            backgroundColor: colors.surfaceContainerHigh,
            valueColor: AlwaysStoppedAnimation(color),
          ),
          Text(
            '${(percent * 100).round()}',
            style: AppTypography.monoUtility.copyWith(
              fontSize: 10,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
