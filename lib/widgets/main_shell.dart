// widgets/main_shell
import 'package:flutter/material.dart';
import 'package:taskflow/screens/calendar_screen.dart';
import '../screens/home_screen.dart';
import '../screens/extensions_screen.dart';
import '../screens/search_screen.dart';
import '../screens/more_screen.dart';
import '../screens/notifications_screen.dart';
import '../theme/app_palette.dart';
import 'top_bar_menu.dart';
import 'quick_add_sheet.dart';
import 'app_snackbar.dart';
import 'slide_page_route.dart';

/// Bottom nav destinations. `extensions` isn't a bottom-nav icon (Calendar
/// took its slot) but stays in the enum since the top-bar "Add Extension"
/// menu item still navigates there. The center FAB is a quick-add action,
/// not a page, so it isn't part of this set either.
enum _NavPage { home, extensions, calendar, search, more }

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  _NavPage _page = _NavPage.home;
  _NavPage _previousPage = _NavPage.home;

  static const _titles = {
    _NavPage.home: 'TaskFlow',
    _NavPage.extensions: 'TaskFlow',
    _NavPage.calendar: 'TaskFlow',
    _NavPage.search: 'TaskFlow',
    _NavPage.more: 'TaskFlow',
  };

  void _selectPage(_NavPage page) {
    if (page == _page) return;
    setState(() {
      _previousPage = _page;
      _page = page;
    });
  }

  /// Slide direction follows the tabs' declared order, so moving toward
  /// the end of the list slides one way and moving back slides the other.
  bool get _movingForward =>
      _NavPage.values.indexOf(_page) >= _NavPage.values.indexOf(_previousPage);

  void _onMenuAction(TopBarMenuAction action) {
    switch (action) {
      case TopBarMenuAction.theme:
        _selectPage(_NavPage.more);
        return;

      case TopBarMenuAction.addExtension:
        _selectPage(_NavPage.extensions);
        return;

      case TopBarMenuAction.sync:
        showAppSnackBar(context, 'Syncing…');
    }
  }

  void _onQuickAdd() => showQuickAddSheet(
    context,
    onCreateTodo: () => showAppSnackBar(context, 'Create TODO'),
    onAddRoadmapItem: () => showAppSnackBar(context, 'Add Roadmap Item'),
  );

  Widget _buildPage(_NavPage page) {
    switch (page) {
      case _NavPage.home:
        return HomeScreen(onOpenCalendar: () => _selectPage(_NavPage.calendar));
      case _NavPage.calendar:
        return const CalendarScreen();
      case _NavPage.extensions:
        return const ExtensionsScreen();
      case _NavPage.search:
        return const SearchScreen();
      case _NavPage.more:
        return const MoreScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: _page == _NavPage.search
          ? null
          : AppBar(
              // main_shell.dart — back arrow now shown on Calendar (and Extensions)
              leading:
                  (_page == _NavPage.extensions || _page == _NavPage.calendar)
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => _selectPage(_previousPage),
                    )
                  : null,
              title: Text(_titles[_page]!),
              actions: [
                IconButton(
                  icon: Icon(Icons.notifications_none, color: colors.onSurface),
                  onPressed: () => Navigator.of(
                    context,
                  ).push(slidePageRoute((_) => const NotificationsScreen())),
                ),
                TopBarMenu(onSelected: _onMenuAction),
                const SizedBox(width: 4),
              ],
            ),
      // AnimatedSwitcher + a directional slide/fade replaces the old
      // IndexedStack. Trade-off: each tab rebuilds fresh on switch (no
      // more free scroll-position retention) in exchange for the
      // animation. Fine for now since screens are simple/static.
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) {
          final offsetTween = Tween<Offset>(
            begin: Offset(_movingForward ? 0.06 : -0.06, 0),
            end: Offset.zero,
          );
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: animation.drive(offsetTween),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(key: ValueKey(_page), child: _buildPage(_page)),
      ),
      floatingActionButton: _QuickAddFab(onTap: _onQuickAdd),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _BottomBar(current: _page, onSelect: _selectPage),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.current, required this.onSelect});

  final _NavPage current;
  final ValueChanged<_NavPage> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return BottomAppBar(
      color: colors.surfaceContainer,
      shape: const CircularNotchedRectangle(),
      notchMargin: 10,
      elevation: 0,
      height: 64,
      padding: EdgeInsets.zero,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavIcon(
            icon: Icons.format_list_bulleted,
            selected: current == _NavPage.home,
            onTap: () => onSelect(_NavPage.home),
          ),
          _NavIcon(
            icon: Icons.calendar_month_outlined,
            selected: current == _NavPage.calendar,
            onTap: () => onSelect(_NavPage.calendar),
          ),
          const SizedBox(width: 56),
          _NavIcon(
            icon: Icons.search,
            selected: current == _NavPage.search,
            onTap: () => onSelect(_NavPage.search),
          ),
          _NavIcon(
            icon: Icons.menu,
            selected: current == _NavPage.more,
            onTap: () => onSelect(_NavPage.more),
          ),
        ],
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(
          icon,
          color: selected ? colors.primaryContainer : colors.textSecondary,
        ),
      ),
    );
  }
}

class _QuickAddFab extends StatelessWidget {
  const _QuickAddFab({required this.onTap});

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
