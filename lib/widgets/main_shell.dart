// widgets/main_shell
import 'package:flutter/material.dart';
import 'package:taskflow/screens/calendar_screen.dart';
import '../screens/home_screen.dart';
import '../screens/todo_screen.dart';
import '../screens/extensions_screen.dart';
import '../screens/search_screen.dart';
import '../screens/more_screen.dart';
import '../screens/notifications_screen.dart';
import '../theme/app_palette.dart';
import 'top_bar_menu.dart';
import 'quick_add_sheet.dart';
import 'app_snackbar.dart';
import 'slide_page_route.dart';

/// Bottom nav destinations. `extensions` and `todo` aren't bottom-nav icons
/// (Calendar took one slot, and TODO is opened from the Home card) but they
/// live in this enum so they render *inside* the shell — that's what keeps
/// the bottom bar and FAB visible on those pages instead of being covered
/// by a pushed route. The center FAB is a quick-add action, not a page, so
/// it isn't part of this set either.
enum _NavPage { home, todo, extensions, calendar, search, more }

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  _NavPage _page = _NavPage.home;
  _NavPage _previousPage = _NavPage.home;

  /// Set right before switching to the TODO tab from Calendar's
  /// "View in TODO" action; cleared whenever TODO is opened any other
  /// way, so a stale date filter never carries over.
  DateTime? _todoDateFilter;

  static const _titles = {
    _NavPage.home: 'TaskFlow',
    _NavPage.todo: 'TaskFlow',
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

  /// Opens the TODO tab, optionally pre-filtered to a date (from
  /// Calendar) — explicitly passing null elsewhere (Home's TODO card)
  /// is what keeps a previous date filter from leaking back in.
  void _openTodo({DateTime? dateFilter}) {
    setState(() {
      _todoDateFilter = dateFilter;
      _previousPage = _page;
      _page = _NavPage.todo;
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
    // "Create TODO" now opens the real task sheet and saves straight to
    // AppDatabase from inside quick_add_sheet.dart, so there's nothing
    // left for MainShell to wire up for it.
    onAddRoadmapItem: () => showAppSnackBar(context, 'Add Roadmap Item'),
  );

  Widget _buildPage(_NavPage page) {
    switch (page) {
      case _NavPage.home:
        return HomeScreen(
          onOpenCalendar: () => _selectPage(_NavPage.calendar),
          onOpenTodo: () => _openTodo(),
        );
      case _NavPage.todo:
        // TODO supplies its own AppBar (title + add button), so the shell
        // hides its own — same arrangement SearchScreen already uses.
        return TodoScreen(
          onBack: () => _selectPage(_previousPage),
          initialDateFilter: _todoDateFilter,
        );
      case _NavPage.calendar:
        return CalendarScreen(
          onViewDateInTodo: (date) => _openTodo(dateFilter: date),
        );
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
      appBar: (_page == _NavPage.search || _page == _NavPage.todo)
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
            // Home and TODO share this icon's highlight so the bar doesn't
            // look "unselected" while you're on the TODO page.
            selected: current == _NavPage.home || current == _NavPage.todo,
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
