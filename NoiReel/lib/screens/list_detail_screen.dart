import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../auth/auth_controller.dart';
import '../widgets/dialogs.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/poster_card.dart';
import 'new_list_screen.dart';
import 'title_details_screen.dart';

/// What happened to a list while its page was open, returned when the
/// page closes so the List tab can refresh
enum ListChange {
  /// Renamed, reordered, or anything else saved from Edit
  edited,

  /// Deleted
  deleted,
}

/// One of the user's lists: its name, description, and entries in a poster
/// grid like Home's, in the order they were added. The ... menu at the top
/// right edits or deletes it
class ListDetailScreen extends StatefulWidget {
  /// Creates the page for [summary]
  const ListDetailScreen({
    super.key,
    required this.api,
    required this.auth,
    required this.token,
    required this.summary,
  });

  final ApiClient api;             // Connection to the server
  final AuthController auth;       // The owner (the editor needs it)
  final String token;              // The owner's login token
  final UserListSummary summary;   // The tapped card, shown while loading

  @override
  State<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends State<ListDetailScreen> {
  late Future<UserListDetails> _list = _load();
  UserListDetails? _loaded; // The list as last loaded or saved
  ListChange? _change;      // Returned when the page closes
  bool _deleting = false;

  Future<UserListDetails> _load() async {
    final list = await widget.api.getMyList(widget.token, widget.summary.id);
    _loaded = list;
    return list;
  }

  void _leave() => Navigator.of(context).pop(_change);

  Future<void> _edit() async {
    final list = _loaded;
    if (list == null) return; // still loading
    final saved = await Navigator.of(context).push<UserListDetails>(
      MaterialPageRoute(
        builder: (_) => NewListScreen(
          api: widget.api,
          auth: widget.auth,
          editing: list,
        ),
      ),
    );
    if (saved == null || !mounted) return;
    setState(() {
      _loaded = saved;
      _list = Future.value(saved);
      _change = ListChange.edited;
    });
  }

  Future<void> _delete() async {
    final name = _loaded?.name ?? widget.summary.name;
    if (!await confirmDeleteList(context, name) || !mounted) return;

    setState(() => _deleting = true);
    try {
      await widget.api.deleteList(widget.token, widget.summary.id);
      if (!mounted) return;
      _change = ListChange.deleted;
      _leave();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _refresh() async {
    final list = _load();
    setState(() => _list = list);
    await list.catchError((_) => const UserListDetails(id: 0, name: ''));
  }

  void _open(TitleCard title) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => TitleDetailsScreen(api: widget.api, title: title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    final navText = Theme.of(context).colorScheme.onSecondary;

    // Back hands the change (if any) to the List tab
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          leadingWidth: BackTextButton.width,
          leading: const BackTextButton(),
          title: const Text('NOIREEL'),
          actions: [
            if (_deleting)
              Padding(
                padding: const EdgeInsets.all(14),
                child: SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: navText,
                  ),
                ),
              )
            else
              PopupMenuButton<ListChange>(
                tooltip: 'List options',
                icon: Icon(Icons.more_horiz, color: navText),
                color: Theme.of(context).scaffoldBackgroundColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (choice) => choice == ListChange.edited
                    ? _edit()
                    : _delete(),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: ListChange.edited,
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: ListChange.deleted,
                    child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('Delete'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            const SizedBox(width: 4),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<UserListDetails>(
            future: _list,
            builder: (context, snapshot) {
              final list = snapshot.data;
              final name = list?.name ?? widget.summary.name;
              // Once loaded, the list's own (possibly cleared) description
              final description = list == null
                  ? widget.summary.description
                  : list.description;
              final count = list?.entries.length ?? widget.summary.entryCount;

              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: FadeSlideIn(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: text.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$count ${count == 1 ? 'entry' : 'entries'}',
                              style: text.bodySmall,
                            ),
                            if (description != null) ...[
                              const SizedBox(height: 10),
                              Text(description),
                            ],
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (snapshot.connectionState != ConnectionState.done)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(48),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    )
                  else if (snapshot.hasError)
                    SliverToBoxAdapter(
                      child: _Notice(
                        text: '${snapshot.error}',
                        onRetry: _refresh,
                      ),
                    )
                  else if (list!.entries.isEmpty)
                    const SliverToBoxAdapter(
                      child: _Notice(text: 'This list has no entries yet.'),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      sliver: SliverGrid.builder(
                        gridDelegate: posterGridDelegate,
                        itemCount: list.entries.length,
                        itemBuilder: (context, i) => FadeSlideIn.staggered(
                          index: i < 12 ? i : 0,
                          step: const Duration(milliseconds: 40),
                          distance: 16,
                          child: GridPoster(
                            title: list.entries[i],
                            onTap: () => _open(list.entries[i]),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: FadeSlideIn(
        child: Column(
          children: [
            Text(text, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
