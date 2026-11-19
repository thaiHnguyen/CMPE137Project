import 'package:flutter/material.dart';

/// One tab in the bottom navigation bar
class NavTab {
  /// Creates a [NavTab]
  const NavTab({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;         // Under the icon; read by screen readers
  final IconData icon;        // Outlined icon, when the tab isn't selected
  final IconData selectedIcon; // Filled icon, when the tab is selected
}

/// The app's tabs, left to right. Mood is in the center, like
/// Letterboxd's center button
const navTabs = [
  NavTab(
    label: 'Home',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
  ),
  NavTab(
    label: 'Search',
    icon: Icons.search_outlined,
    selectedIcon: Icons.search,
  ),
  NavTab(
    label: 'Mood',
    icon: Icons.theater_comedy_outlined,
    selectedIcon: Icons.theater_comedy,
  ),
  NavTab(
    label: 'Lists',
    icon: Icons.bookmarks_outlined,
    selectedIcon: Icons.bookmarks,
  ),
  NavTab(
    label: 'Profile',
    icon: Icons.person_outlined,
    selectedIcon: Icons.person,
  ),
];

/// The rounded bar at the bottom of every screen, in the current theme's
/// nav bar colors. The selected tab has a filled icon in full color; the
/// others have an outlined icon, dimmed
class NoiReelNavBar extends StatelessWidget {
  /// Creates the bar
  const NoiReelNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.tabs = navTabs,
  });

  /// Set to false to show icons only, like Letterboxd
  static const showLabels = true;

  /// How strong the unselected tabs are, from 0 (invisible) to 1 (full)
  static const unselectedOpacity = 0.55;

  final int currentIndex;         // The selected tab
  final ValueChanged<int> onTap;  // Called with the tapped tab's index
  final List<NavTab> tabs;        // The tabs to show

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: colors.secondary, // the theme's navBar
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            for (var i = 0; i < tabs.length; i++)
              Expanded(
                child: _NavItem(
                  tab: tabs[i],
                  selected: i == currentIndex,
                  onTap: () => onTap(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final NavTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final navText = Theme.of(context).colorScheme.onSecondary;
    final color = selected
        ? navText
        : navText.withValues(alpha: NoiReelNavBar.unselectedOpacity);

    return Semantics(
      selected: selected,
      button: true,
      label: tab.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? tab.selectedIcon : tab.icon,
                color: color,
                size: 26,
              ),
              if (NoiReelNavBar.showLabels) ...[
                const SizedBox(height: 2),
                Text(
                  tab.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
