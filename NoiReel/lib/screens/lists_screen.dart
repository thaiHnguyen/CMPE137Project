import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../auth/auth_controller.dart';
import '../widgets/dialogs.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/poster_card.dart';
import 'list_detail_screen.dart';
import 'login_screen.dart';
import 'new_list_screen.dart';
import 'register_screen.dart';

/// The Lists tab: Favorite, List and Watchlist along the top.
///
/// List shows the user's own lists, with a + button above the nav bar to
/// make a new one. Favorite and Watchlist come later
class ListsScreen extends StatefulWidget {
  /// Creates the Lists tab
  const ListsScreen({super.key, required this.api, required this.auth});

  final ApiClient api;        // Connection to the server
  final AuthController auth;  // Who is logged in

  @override
  State<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends State<ListsScreen>
    with SingleTickerProviderStateMixin {
  /// Tab order along the top
  static const _tabs = ['Favorite', 'List', 'Watchlist'];
  static const _listTab = 1;

  late final _tabController = TabController(
    length: _tabs.length,
    initialIndex: _listTab,
    vsync: this,
  )..addListener(() => setState(() {})); // shows or hides the + button

  // Bumped to reload the user's lists, e.g. after making one
  final _reload = ValueNotifier<int>(0);

  @override
  void dispose() {
    _tabController.dispose();
    _reload.dispose();
    super.dispose();
  }

  Future<void> _newList() async {
    if (!widget.auth.isLoggedIn) {
      final choice = await askGuestToSignIn(context, 'to create a list');
      if (choice == null || !mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => choice == GuestChoice.signIn
              ? LoginScreen(auth: widget.auth)
              : RegisterScreen(auth: widget.auth),
        ),
      );
      return;
    }
    if (widget.auth.value!.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Admin accounts can't have lists.")),
      );
      return;
    }

    final created = await Navigator.of(context).push<UserListDetails>(
      MaterialPageRoute(
        builder: (_) => NewListScreen(api: widget.api, auth: widget.auth),
      ),
    );
    if (created == null || !mounted) return;
    _reload.value++;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('"${created.name}" created.')));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('NOIREEL'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: colors.onSecondary,
          unselectedLabelColor: colors.onSecondary.withValues(alpha: 0.6),
          indicatorColor: colors.onSecondary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w900),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          dividerColor: Colors.transparent,
          tabs: [for (final t in _tabs) Tab(text: t)],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const _ComingSoon(
            icon: Icons.favorite_outline,
            text: 'Titles you add to your favorites will show up here.',
          ),
          _MyLists(api: widget.api, auth: widget.auth, reload: _reload),
          const _ComingSoon(
            icon: Icons.bookmark_outline,
            text: 'Titles you add to your watchlist will show up here.',
          ),
        ],
      ),
      // The + sits in the middle, just above the nav bar
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _tabController.index == _listTab
          ? FloatingActionButton.small(
              tooltip: 'New list',
              onPressed: _newList,
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              shape: const CircleBorder(),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

/// The List tab: the user's lists, or a sign-in note for a guest
class _MyLists extends StatefulWidget {
  const _MyLists({required this.api, required this.auth, required this.reload});

  final ApiClient api;
  final AuthController auth;
  final ValueNotifier<int> reload; // Changes when the lists should reload

  @override
  State<_MyLists> createState() => _MyListsState();
}

class _MyListsState extends State<_MyLists> {
  Future<List<UserListSummary>>? _lists;
  String? _token; // Whose lists are loaded

  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_onAuthChanged);
    widget.reload.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    widget.auth.removeListener(_onAuthChanged);
    widget.reload.removeListener(_load);
    super.dispose();
  }

  // Logging in or out shows that person's lists, or none
  void _onAuthChanged() {
    if (widget.auth.value?.token != _token) _load();
  }

  void _load() {
    final token = widget.auth.value?.token;
    setState(() {
      _token = token;
      _lists = token == null ? null : widget.api.getMyLists(token);
    });
  }

  Future<void> _refresh() async {
    _load();
    await _lists?.catchError((_) => <UserListSummary>[]);
  }

  void _open(UserListSummary list) {
    final token = _token;
    if (token == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ListDetailScreen(
          api: widget.api,
          token: token,
          summary: list,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lists = _lists;
    if (lists == null) {
      return const _Message(
        icon: Icons.list_alt,
        text: 'Register or sign in to create lists of movies and shows. '
            'Tap + to get started.',
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<UserListSummary>>(
        future: lists,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _Message(
              icon: Icons.cloud_off,
              text: '${snapshot.error}',
              onRetry: _load,
            );
          }
          final mine = snapshot.data!;
          if (mine.isEmpty) {
            return const _Message(
              icon: Icons.playlist_add,
              text: "You haven't made any lists yet. Tap + to create one.",
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            // Bottom room so the + button never covers the last list
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: mine.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) => FadeSlideIn.staggered(
              index: i < 8 ? i : 0,
              child: _ListCard(list: mine[i], onTap: () => _open(mine[i])),
            ),
          );
        },
      ),
    );
  }
}

/// One list on the List tab: a strip of its first posters, its name,
/// how many entries it has, and its description
class _ListCard extends StatelessWidget {
  const _ListCard({required this.list, required this.onTap});

  final UserListSummary list;
  final VoidCallback onTap;

  static const _posterWidth = 56.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final border = Theme.of(context).colorScheme.onSurface;
    final count = list.entryCount;

    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: border.withValues(alpha: 0.35), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Up to 4 posters, overlapping like a fanned stack
              SizedBox(
                width: _posterWidth + 3 * 22,
                height: _posterWidth * 1.5,
                child: Stack(
                  children: [
                    for (var i = 3; i >= 0; i--)
                      Positioned(
                        left: i * 22.0,
                        width: _posterWidth,
                        child: i < list.posterUrls.length
                            ? PosterImage(
                                url: list.posterUrls[i],
                                type: 'movie',
                              )
                            : Opacity(
                                opacity: 0.35,
                                child: PosterImage(url: null, type: 'movie'),
                              ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      list.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$count ${count == 1 ? 'entry' : 'entries'}',
                      style: text.bodySmall,
                    ),
                    if (list.description != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        list.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) =>
      _Message(icon: icon, text: '$text\nComing soon.');
}

/// Centered icon and text, with an optional Try again
class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.onRetry});

  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).textTheme.bodyMedium?.color;
    // Scrollable so pull-to-refresh works on it too
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 64, 32, 96),
      children: [
        FadeSlideIn(
          child: Column(
            children: [
              Icon(icon, size: 56, color: color),
              const SizedBox(height: 12),
              Text(text, textAlign: TextAlign.center),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: onRetry,
                  child: const Text('Try again'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
