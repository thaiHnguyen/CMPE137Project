import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/poster_card.dart';
import 'title_details_screen.dart';

/// The Search tab: find movies and shows by title, director, creator or
/// cast (GU-02). Results appear as you type, best match first, and more
/// load as you scroll
class SearchScreen extends StatefulWidget {
  /// Creates the Search tab
  const SearchScreen({super.key, required this.api});

  final ApiClient api; // Connection to the server

  /// Wait this long after the last keystroke before searching, so typing
  /// "inception" sends one request, not nine
  static const typingPause = Duration(milliseconds: 350);


  static const pageSize = 20;   // Results per page (GU-02.02)
  static const maxLength = 100; // Longest search the server accepts

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  Timer? _typing;

  String _query = ''; // What the results are for
  List<TitleCard> _results = [];
  int _total = 0; // Results across all pages
  int _page = 0; // Pages loaded so far
  bool _loading = false; // First page is loading
  bool _loadingMore = false; // A later page is loading
  String? _error;

  // Bumped for every new search. A reply that comes back for an older
  // search (the user kept typing) is thrown away
  int _searchId = 0;

  bool get _hasMore => _results.length < _total;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _typing?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _typing?.cancel();
    setState(() {}); // shows or hides the clear button
    _typing = Timer(SearchScreen.typingPause, () => _search(text));
  }

  void _clear() {
    _typing?.cancel();
    _input.clear();
    _search('');
  }

  /// Starts a new search for [text], replacing the current results
  Future<void> _search(String text) async {
    final query = text.trim();
    _typing?.cancel();
    if (query == _query && _error == null) return; // nothing new

    final id = ++_searchId;
    setState(() {
      _query = query;
      _results = [];
      _total = 0;
      _page = 0;
      _error = null;
      _loading = query.isNotEmpty;
      _loadingMore = false;
    });
    if (query.isEmpty) return;
    if (_scroll.hasClients) _scroll.jumpTo(0);

    try {
      final page = await widget.api.search(query, limit: SearchScreen.pageSize);
      if (!mounted || id != _searchId) return; // an older search
      setState(() {
        _results = page.titles;
        _total = page.total;
        _page = 1;
      });
    } on ApiException catch (e) {
      if (!mounted || id != _searchId) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted && id == _searchId) setState(() => _loading = false);
    }
  }

  /// Loads the next page when the user scrolls near the end
  void _onScroll() {
    if (!_scroll.hasClients || _loading || _loadingMore || !_hasMore) return;
    if (_error != null) return;
    final position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent - 400) _loadMore();
  }

  Future<void> _loadMore() async {
    final id = _searchId;
    setState(() => _loadingMore = true);
    try {
      final page = await widget.api.search(
        _query,
        page: _page + 1,
        limit: SearchScreen.pageSize,
      );
      if (!mounted || id != _searchId) return;
      setState(() {
        // Skip any title already shown, in case the catalog changed
        final shown = {for (final t in _results) t.id};
        _results = [
          ..._results,
          ...page.titles.where((t) => !shown.contains(t.id)),
        ];
        _total = page.total;
        _page++;
      });
    } on ApiException catch (e) {
      if (!mounted || id != _searchId) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted && id == _searchId) setState(() => _loadingMore = false);
    }
  }

  void _open(TitleCard title) {
    FocusScope.of(context).unfocus(); // hide the keyboard
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TitleDetailsScreen(api: widget.api, title: title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NOIREEL')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _input,
                  onChanged: _onChanged,
                  onSubmitted: _search, // Enter searches right away
                  textInputAction: TextInputAction.search,
                  maxLength: SearchScreen.maxLength,
                  decoration: InputDecoration(
                    hintText: 'Title, director or cast',
                    counterText: '', // hide the "0/100" counter
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _input.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear',
                            icon: const Icon(Icons.close),
                            onPressed: _clear,
                          ),
                  ),
                ),
              ),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_query.isEmpty) {
      return const _Notice(
        icon: Icons.search,
        title: 'Find a movie or show',
        text: 'Search by title, director or cast.',
      );
    }
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _Notice(
        icon: Icons.cloud_off,
        title: "Couldn't search",
        text: _error!,
        onRetry: () => _search(_input.text),
      );
    }
    if (_results.isEmpty) {
      // GU-02.04
      return _Notice(
        icon: Icons.search_off,
        title: 'No results for "$_query"',
        text:
            'Check the spelling, or try fewer or different words, '
            'like just a last name.',
      );
    }

    final text = Theme.of(context).textTheme;
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      // The count line, the results, then a spinner while more load
      itemCount: _results.length + 1 + (_hasMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '$_total ${_total == 1 ? 'result' : 'results'}',
              style: text.bodySmall,
            ),
          );
        }
        final index = i - 1;
        if (index == _results.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return FadeSlideIn.staggered(
          // Only the first screenful staggers; later pages appear at once
          key: ValueKey('$_searchId-${_results[index].id}'),
          index: index < 10 ? index : 0,
          step: const Duration(milliseconds: 40),
          distance: 16,
          child: _ResultTile(
            title: _results[index],
            onTap: () => _open(_results[index]),
          ),
        );
      },
    );
  }
}

/// One search result: poster, name, year and Movie/TV (GU-02.03)
class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.title, required this.onTap});

  final TitleCard title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final facts = [
      if (title.year != null) '${title.year}',
      title.type == 'tv' ? 'TV show' : 'Movie',
    ];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              child: PosterImage(url: title.posterUrl, type: title.type),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(facts.join('  ·  '), style: text.bodyMedium),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: text.bodyMedium?.color),
          ],
        ),
      ),
    );
  }
}

/// Centered icon, heading and text, e.g. before searching or no results
class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.title,
    required this.text,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: FadeSlideIn(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: theme.bodyMedium?.color),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
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
      ),
    );
  }
}
