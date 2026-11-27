import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../widgets/dialogs.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/poster_card.dart';
import 'title_details_screen.dart';

/// "Similar mood": titles that feel like [title], in a poster grid. They
/// share its main mood, or at least 3 of its mood tags; the most alike
/// come first. More load as you scroll
class SimilarTitlesScreen extends StatefulWidget {
  /// Creates the page for titles like [title]
  const SimilarTitlesScreen({
    super.key,
    required this.api,
    required this.title,
  });

  final ApiClient api;    // Connection to the server
  final TitleCard title;  // The title to find others like

  /// Titles per page loaded from the server
  static const pageSize = 30;

  @override
  State<SimilarTitlesScreen> createState() => _SimilarTitlesScreenState();
}

class _SimilarTitlesScreenState extends State<SimilarTitlesScreen> {
  final _scroll = ScrollController();

  List<TitleCard> _titles = [];
  int _total = 0;
  int _page = 0;            // Pages loaded so far
  bool _loading = true;     // First page
  bool _loadingMore = false;
  String? _error;

  bool get _hasMore => _titles.length < _total;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadFirst();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadFirst() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.api.getSimilar(
        widget.title.id,
        limit: SimilarTitlesScreen.pageSize,
      );
      if (!mounted) return;
      setState(() {
        _titles = page.titles;
        _total = page.total;
        _page = 1;
      });
      _fillScreen();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// A page may not fill a wide screen; check again after each load
  void _fillScreen() =>
      WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());

  void _onScroll() {
    if (!_scroll.hasClients || _loading || _loadingMore || !_hasMore) return;
    final position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent - 600) _loadMore();
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final page = await widget.api.getSimilar(
        widget.title.id,
        page: _page + 1,
        limit: SimilarTitlesScreen.pageSize,
      );
      if (!mounted) return;
      setState(() {
        final shown = {for (final t in _titles) t.id};
        _titles = [
          ..._titles,
          ...page.titles.where((t) => !shown.contains(t.id)),
        ];
        _total = page.total;
        _page++;
      });
      _fillScreen();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
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
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: BackTextButton.width,
        leading: const BackTextButton(),
        title: const Text('Similar mood'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadFirst,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: FadeSlideIn(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                  child: Text.rich(
                    TextSpan(
                      text: 'Titles that feel like ',
                      children: [
                        TextSpan(
                          text: widget.title.name,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    style: text.titleMedium,
                  ),
                ),
              ),
            ),
            if (!_loading && _error == null && _total > 0)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Text(
                    '$_total ${_total == 1 ? 'title' : 'titles'}',
                    style: text.bodySmall,
                  ),
                ),
              ),
            ..._grid(),
          ],
        ),
      ),
    );
  }

  List<Widget> _grid() {
    if (_loading) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ];
    }
    final error = _error;
    if (error != null || _titles.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: FadeSlideIn(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    error ??
                        'No titles with a similar mood yet. As more '
                            'people vote on moods, more will show up here.',
                    textAlign: TextAlign.center,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loadFirst,
                      child: const Text('Try again'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverGrid.builder(
          gridDelegate: posterGridDelegate,
          itemCount: _titles.length,
          itemBuilder: (context, i) => FadeSlideIn.staggered(
            key: ValueKey(_titles[i].id),
            index: i < 12 ? i : 0, // first screenful staggers
            step: const Duration(milliseconds: 40),
            distance: 16,
            child: GridPoster(
              title: _titles[i],
              onTap: () => _open(_titles[i]),
            ),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Center(
            child: _loadingMore
                ? const CircularProgressIndicator()
                : const SizedBox(height: 36),
          ),
        ),
      ),
    ];
  }
}
