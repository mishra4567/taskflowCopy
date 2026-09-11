import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/extensions_screen.dart';
import '../screens/search_screen.dart';
import '../screens/more_screen.dart';
import '../theme/app_colors.dart';
import 'top_bar_menu.dart';
import 'quick_add_sheet.dart';

/// Bottom nav destinations. The center "+" button is a quick-add action,
/// not a page, so it isn't part of this enum's page set.
enum _NavPage { home, extensions, search, more }

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  _NavPage _page = _NavPage.home;

  static const _titles = {
    _NavPage.home: 'TaskFlow',
    _NavPage.extensions: 'TaskFlow',
    _NavPage.search: 'TaskFlow',
    _NavPage.more: 'TaskFlow',
  };

  void _onMenuAction(TopBarMenuAction action) {
    final label = switch (action) {
      TopBarMenuAction.sync => 'Syncing…',
      TopBarMenuAction.theme => 'Theme settings',
      TopBarMenuAction.addExtension => 'Add Extension',
      TopBarMenuAction.toggleLightDark => 'Toggled Light / Dark',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(label)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: _page == _NavPage.search
          ? null
          : AppBar(
              title: Text(_titles[_page]!),
              actions: [
                IconButton(
                  icon: const Icon(
                    Icons.notifications_none,
                    color: AppColors.onSurface,
                  ),
                  onPressed: () {},
                ),
                TopBarMenu(onSelected: _onMenuAction),
                const SizedBox(width: 4),
              ],
            ),
      body: IndexedStack(
        index: _NavPage.values.indexOf(_page),
        children: const [
          HomeScreen(),
          ExtensionsScreen(),
          SearchScreen(),
          MoreScreen(),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        current: _page,
        onSelect: (p) => setState(() => _page = p),
        onQuickAdd: () => showQuickAddSheet(
          context,
          onCreateTodo: () => ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Create TODO'))),
          onAddRoadmapItem: () => ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Add Roadmap Item'))),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.current,
    required this.onSelect,
    required this.onQuickAdd,
  });

  final _NavPage current;
  final ValueChanged<_NavPage> onSelect;
  final VoidCallback onQuickAdd;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _NavIcon(
                icon: Icons.format_list_bulleted,
                selected: current == _NavPage.home,
                onTap: () => onSelect(_NavPage.home),
              ),
              _NavIcon(
                icon: Icons.grid_view_rounded,
                selected: current == _NavPage.extensions,
                onTap: () => onSelect(_NavPage.extensions),
              ),
              _CenterButton(onTap: onQuickAdd),
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
        ),
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
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(
          icon,
          color: selected
              ? AppColors.primaryContainer
              : AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _CenterButton extends StatelessWidget {
  const _CenterButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: AppColors.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.add, color: AppColors.onPrimary),
      ),
    );
  }
}
