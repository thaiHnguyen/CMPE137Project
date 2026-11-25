import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../widgets/dialogs.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/poster_card.dart';
import 'title_details_screen.dart';

/// One of the user's lists: its name, description, and entries in a poster
/// grid like Home's, in the order they were added
class ListDetailScreen extends StatefulWidget {
  /// Creates the page for [summary]
  const ListDetailScreen({
    super.key,
    required this.api,
    required this.token,
    required this.summary,
  });

  final ApiClient api;             // Connection to the server
  final String token;              // The owner's login token
  final UserListSummary summary;   // The tapped card, shown while loading

  @override
  State<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends State<ListDetailScreen> {
  late Future<UserListDetails> _list = _load();

  Future<UserListDetails> _load() =>
      widget.api.getMyList(widget.token, widget.summary.id);

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

    return Scaffold(
      appBar: AppBar(
        leadingWidth: BackTextButton.width,
        leading: const BackTextButton(),
        title: const Text('NOIREEL'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<UserListDetails>(
          future: _list,
          builder: (context, snapshot) {
            final list = snapshot.data;
            final name = list?.name ?? widget.summary.name;
            final description = list?.description ?? widget.summary.description;
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
