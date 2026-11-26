import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../auth/auth_controller.dart';
import '../widgets/dialogs.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/library_events.dart';
import '../widgets/poster_card.dart';
import 'list_detail_screen.dart';
import 'login_screen.dart';
import 'new_list_screen.dart';
import 'register_screen.dart';
import 'title_details_screen.dart';

// Pieces of the Profile tab's Favorite, List and Watchlist tabs (they
// used to be their own Lists tab in the nav bar).
//
// MyListsView shows the user's lists; startNewList is what the + button
// does; CollectionView shows Favorites or the Watchlist

/// The + button: a guest is asked to sign in, an admin is told admins
/// can't have lists, and anyone else gets the New List page. A list made
/// there bumps [reload] so [MyListsView] shows it
Future<void> startNewList(
  BuildContext context, {
  required ApiClient api,
  required AuthController auth,
  required ValueNotifier<int> reload,
}) async {
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);

  if (!auth.isLoggedIn) {
    final choice = await askGuestToSignIn(context, 'to create a list');
    if (choice == null) return;
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => choice == GuestChoice.signIn
            ? LoginScreen(auth: auth)
            : RegisterScreen(auth: auth),
      ),
    );
    return;
  }
  if (auth.value!.isAdmin) {
    messenger.showSnackBar(
      const SnackBar(content: Text("Admin accounts can't have lists.")),
    );
    return;
  }

  final created = await navigator.push<UserListDetails>(
    MaterialPageRoute(builder: (_) => NewListScreen(api: api, auth: auth)),
  );
  if (created == null) return;
  reload.value++;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('"${created.name}" created.')));
}

/// The List tab: the user's lists, or a sign-in note for a guest
class MyListsView extends StatefulWidget {
  /// Creates the List tab's contents
  const MyListsView({
    super.key,
    required this.api,
    required this.auth,
    required this.reload,
  });

  final ApiClient api;
  final AuthController auth;
  final ValueNotifier<int> reload; // Changes when the lists should reload

  @override
  State<MyListsView> createState() => _MyListsViewState();
}

class _MyListsViewState extends State<MyListsView> {
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

  Future<void> _open(UserListSummary list) async {
    final token = _token;
    if (token == null) return;
    final change = await Navigator.of(context).push<ListChange>(
      MaterialPageRoute(
        builder: (_) => ListDetailScreen(
          api: widget.api,
          auth: widget.auth,
          token: token,
          summary: list,
        ),
      ),
    );
    if (change == null || !mounted) return;
    _load(); // new name, order or posters, or one list fewer
    if (change == ListChange.deleted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('"${list.name}" deleted.')));
    }
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

/// The Favorite or Watchlist tab on Profile: its titles in a poster grid
/// in their saved order, with Edit to reorder, remove or add titles (the
/// same editor as a list, without a name or description). Titles get here
/// from the 3 dots sheet on a title's page
class CollectionView extends StatefulWidget {
  /// Creates the tab for [collection]
  const CollectionView({
    super.key,
    required this.api,
    required this.auth,
    required this.collection,
  });

  final ApiClient api;
  final AuthController auth;
  final Collection collection;

  @override
  State<CollectionView> createState() => _CollectionViewState();
}

class _CollectionViewState extends State<CollectionView> {
  Future<UserListDetails>? _list;
  String? _token; // Whose collection is loaded

  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_onAuthChanged);
    libraryChanged.addListener(_load); // changed on a title's page
    _load();
  }

  @override
  void dispose() {
    widget.auth.removeListener(_onAuthChanged);
    libraryChanged.removeListener(_load);
    super.dispose();
  }

  void _onAuthChanged() {
    if (widget.auth.value?.token != _token) _load();
  }

  void _load() {
    final session = widget.auth.value;
    setState(() {
      _token = session?.token;
      _list = session == null || session.isAdmin
          ? null
          : widget.api.getCollection(session.token, widget.collection);
    });
  }

  Future<void> _refresh() async {
    _load();
    await _list?.catchError(
      (_) => UserListDetails(id: 0, name: widget.collection.label),
    );
  }

  Future<void> _edit(UserListDetails list) async {
    final saved = await Navigator.of(context).push<UserListDetails>(
      MaterialPageRoute(
        builder: (_) => NewListScreen(
          api: widget.api,
          auth: widget.auth,
          editing: list,
          collection: widget.collection,
        ),
      ),
    );
    if (saved == null || !mounted) return;
    setState(() => _list = Future.value(saved));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('${widget.collection.label} saved.')),
      );
  }

  void _open(TitleCard title) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TitleDetailsScreen(api: widget.api, title: title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final favorites = widget.collection == Collection.favorites;
    final icon = favorites ? Icons.favorite_outline : Icons.more_time;
    final session = widget.auth.value;

    if (session == null) {
      return _Message(
        icon: icon,
        text: favorites
            ? 'Register or sign in to keep your favorite movies and shows.'
            : 'Register or sign in to keep a watchlist.',
      );
    }
    if (session.isAdmin) {
      return _Message(
        icon: icon,
        text: "Admin accounts don't have a ${widget.collection.label}.",
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<UserListDetails>(
        future: _list,
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
          final list = snapshot.data!;
          final titles = list.entries;
          if (titles.isEmpty) {
            return _Message(
              icon: icon,
              text: favorites
                  ? 'Titles you favorite will show up here. On a title\'s '
                        'page, tap the 3 dots, then Favorite.'
                  : 'Titles you want to watch will show up here. On a '
                        "title's page, tap the 3 dots, then Watchlist.",
            );
          }
          return _CollectionGrid(
            titles: titles,
            onOpen: _open,
            onEdit: () => _edit(list),
          );
        },
      ),
    );
  }
}

/// The titles in a poster grid with a count and Edit above
class _CollectionGrid extends StatelessWidget {
  const _CollectionGrid({
    required this.titles,
    required this.onOpen,
    required this.onEdit,
  });

  final List<TitleCard> titles;
  final ValueChanged<TitleCard> onOpen;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final n = titles.length;
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$n ${n == 1 ? 'title' : 'titles'}',
                    style: text.bodyMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          sliver: SliverGrid.builder(
            gridDelegate: posterGridDelegate,
            itemCount: n,
            itemBuilder: (context, i) => FadeSlideIn.staggered(
              index: i < 12 ? i : 0,
              step: const Duration(milliseconds: 40),
              distance: 16,
              child: GridPoster(
                title: titles[i],
                onTap: () => onOpen(titles[i]),
              ),
            ),
          ),
        ),
      ],
    );
  }
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
