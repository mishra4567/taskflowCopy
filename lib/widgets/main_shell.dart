// widgets/main_shell
import 'package:flutter/material.dart';
import 'package:taskflow/screens/calendar_screen.dart';
import 'package:taskflow/screens/extension_runner_screen.dart';
import 'package:taskflow/screens/contactscreen/contact_screen.dart'
    show ContactScreen, registerQuickAddContact;

import '../screens/home_screen.dart';
import '../screens/todoscreen/todo_screen.dart';
import '../screens/extensions_screen.dart';
import '../screens/search_screen.dart';
import '../screens/morescreen/more_screen.dart';
import '../screens/notifications_screen.dart';
import '../theme/app_palette.dart';
import 'top_bar_menu.dart';
import 'quick_add/quick_add_sheet.dart';
import 'quick_add/quick_add_fab.dart';
import 'app_snackbar.dart';
import 'slide_page_route.dart';

/// Bottom nav destinations. `extensions`, `todo`, `testing`, `contacts`,
/// and `extensionRunner` aren't bottom-nav icons (Calendar took one slot,
/// the rest are opened from Home cards) but they live in this enum so
/// they render *inside* the shell — that's what keeps the bottom bar and
/// FAB visible on those pages instead of being covered by a pushed
/// route. The center FAB is a quick-add action, not a page, so it isn't
/// part of this set either.
enum _NavPage {
  home,
  todo,
  testing,
  extensionRunner,
  extensions,
  calendar,
  contacts,
  search,
  more,
}

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

  /// Which installed extension the generic extensionRunner tab shows —
  /// set right before switching to it, the same pattern as
  /// _todoDateFilter. Unlike TODO/Testing/Contacts (one fixed screen
  /// each), the runner is reused across however many extensions are
  /// installed, so it needs to know which one to load.
  String? _activeExtensionType;
  String? _activeExtensionTitle;

  /// True only on Home — every other _page is "internal" navigation the
  /// OS back button/gesture doesn't know about (see PopScope in build()),
  /// since these pages are swapped via state, not pushed Navigator routes.
  bool get _isTopLevel => _page == _NavPage.home;

  @override
  void initState() {
    super.initState();
    // Registers the "Add Contact" quick-add card exactly once for the
    // app's lifetime. Must run before the FAB's sheet can ever be
    // opened — MainShell is the right place since it's what builds the
    // FAB and calls showQuickAddSheet via _onQuickAdd.
    registerQuickAddContact();
  }

  static const _titles = {
    _NavPage.home: 'TaskFlow',
    _NavPage.todo: 'TaskFlow',
    _NavPage.testing: 'TaskFlow',
    _NavPage.extensionRunner: 'TaskFlow',
    _NavPage.extensions: 'TaskFlow',
    _NavPage.calendar: 'TaskFlow',
    _NavPage.contacts: 'TaskFlow',
    _NavPage.search: 'TaskFlow',
    _NavPage.more: 'TaskFlow',
  };

  /// Pages that supply their own AppBar (title + their own actions),
  /// so the shell hides its bar entirely for them.
  static const _hidesShellAppBar = {
    _NavPage.search,
    _NavPage.todo,
    _NavPage.testing,
    _NavPage.contacts,
    _NavPage.extensionRunner,
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

  void _openTesting() => _selectPage(_NavPage.testing);

  /// Opens the generic extension-runner tab for one installed extension.
  void _openExtension(String extensionType, String title) {
    setState(() {
      _activeExtensionType = extensionType;
      _activeExtensionTitle = title;
      _previousPage = _page;
      _page = _NavPage.extensionRunner;
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
          onOpenContact: () => _selectPage(_NavPage.contacts),
          onOpenTesting: _openTesting,
          onOpenExtension: _openExtension,
        );
      case _NavPage.todo:
        // TODO supplies its own AppBar (title + add button), so the shell
        // hides its own — same arrangement SearchScreen already uses.
        return TodoScreen(
          onBack: () => _selectPage(_previousPage),
          initialDateFilter: _todoDateFilter,
        );
      case _NavPage.testing:
        return ContactScreen(onBack: () => _selectPage(_previousPage));
      case _NavPage.extensionRunner:
        // Only reachable via _openExtension, which always sets both
        // fields together — the ! is safe here.
        return ExtensionRunnerScreen(
          extensionType: _activeExtensionType!,
          title: _activeExtensionTitle!,
          onBack: () => _selectPage(_previousPage),
        );
      case _NavPage.calendar:
        return CalendarScreen(
          onViewDateInTodo: (date) => _openTodo(dateFilter: date),
        );
      case _NavPage.contacts:
        return ContactScreen(onBack: () => _selectPage(_previousPage));
      case _NavPage.extensions:
        return ExtensionsScreen(onOpenExtension: _openExtension);
      case _NavPage.search:
        return const SearchScreen();
      case _NavPage.more:
        return const MoreScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // PopScope intercepts the system back button/gesture. These "pages"
    // are swapped via _page state, not pushed Navigator routes, so the
    // OS has no route to pop on its own — without this, back on any
    // non-Home page falls through to closing the app entirely. Only
    // Home allows the default pop (i.e. actually exiting/backgrounding).
    return PopScope(
      canPop: _isTopLevel,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _selectPage(_previousPage);
      },
      child: Scaffold(
        appBar: _hidesShellAppBar.contains(_page)
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
                    icon: Icon(
                      Icons.notifications_none,
                      color: colors.onSurface,
                    ),
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
        floatingActionButton: QuickAddFab(onTap: _onQuickAdd),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: _BottomBar(current: _page, onSelect: _selectPage),
      ),
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
            // Home and TODO share this icon's highlight so the bar
            // doesn't look "unselected" while on either one. The
            // testing/extensionRunner tabs are reached only from Home
            // cards, not this bar, so they're left out of every icon's
            // "selected" check on purpose.
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
