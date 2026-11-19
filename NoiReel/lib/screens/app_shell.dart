import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api_client.dart';
import '../auth/auth_controller.dart';
import '../theme/theme_controller.dart';
import '../widgets/nav_bar.dart';
import 'coming_soon_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

/// The app's frame: the tabs, with the navigation bar at the bottom
///
/// A page opened from a tab (e.g. a title's details) opens above the bar, and switching tabs and
/// back returns to the same page and scroll position
class AppShell extends StatefulWidget {
  /// Creates the shell
  const AppShell({
    super.key,
    required this.api,
    required this.themes,
    required this.auth,
  });

  final ApiClient api;           // Connection to the server
  final ThemeController themes;  // The app's current theme
  final AuthController auth;     // Who is logged in

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _current = 0; // Index into navTabs

  // One page history per tab
  final _navigators = List.generate(
    navTabs.length,
    (_) => GlobalKey<NavigatorState>(),
  );

  void _selectTab(int index) {
    if (index == _current) {
      // Tapping the open tab again goes back to its first page
      _navigators[index].currentState?.popUntil((route) => route.isFirst);
      return;
    }
    setState(() => _current = index);
  }

  /// Android back button: go back within the tab first, then to Home,
  /// then leave the app
  void _onBack() {
    final tab = _navigators[_current].currentState;
    if (tab != null && tab.canPop()) {
      tab.pop();
    } else if (_current != 0) {
      setState(() => _current = 0);
    } else {
      SystemNavigator.pop();
    }
  }

  /// The first page of each tab, in the same order as navTabs
  Widget _rootPage(int index) {
    final tab = navTabs[index];
    return switch (index) {
      0 => HomeScreen(api: widget.api, themes: widget.themes),
      1 => ComingSoonScreen(
          title: 'Search',
          icon: tab.icon,
          description: 'Find movies and shows by title, director or cast.',
        ),
      2 => ComingSoonScreen(
          title: 'Mood',
          icon: tab.icon,
          description: 'Tell NoiReel how you feel and how much time you '
              'have, and get picks that match.',
        ),
      3 => ComingSoonScreen(
          title: 'Lists',
          icon: tab.icon,
          description: 'Your watchlists and everything you have watched.',
        ),
      _ => ProfileScreen(auth: widget.auth),
    };
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        body: IndexedStack(
          index: _current,
          children: [
            for (var i = 0; i < navTabs.length; i++)
              _TabEntrance(
                active: i == _current,
                child: Navigator(
                  key: _navigators[i],
                  onGenerateRoute: (_) => MaterialPageRoute<void>(
                    builder: (_) => _rootPage(i),
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: NoiReelNavBar(
          currentIndex: _current,
          onTap: _selectTab,
        ),
      ),
    );
  }
}

/// Fades a tab in while sliding it up each time it's switched to.
/// The tab's pages stay alive in between, so their scroll position and
/// history are kept
class _TabEntrance extends StatefulWidget {
  const _TabEntrance({required this.active, required this.child});

  final bool active; // True for the tab being shown
  final Widget child;

  @override
  State<_TabEntrance> createState() => _TabEntranceState();
}

class _TabEntranceState extends State<_TabEntrance>
    with SingleTickerProviderStateMixin {
  // The first tab shown at launch starts finished; its content has its
  // own entrance animation
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    value: 1,
  );

  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void didUpdateWidget(_TabEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    final reducedMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.active && !oldWidget.active && !reducedMotion) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _progress.value,
        child: Transform.translate(
          offset: Offset(0, (1 - _progress.value) * 24),
          child: child,
        ),
      ),
    );
  }
}
