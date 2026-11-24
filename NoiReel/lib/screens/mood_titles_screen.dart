import 'dart:math';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../theme/noireel_theme.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/poster_card.dart';
import '../widgets/theme_picker.dart';
import 'title_details_screen.dart';

/// One mood's page, opened from its row on the Mood tab: every title of
/// that mood in a shuffled poster grid, like Home's Discovery grid but with
/// no limit. More load as you scroll; pulling down reshuffles
class MoodTitlesScreen extends StatefulWidget {
  /// Creates the page for [mood]
  const MoodTitlesScreen({super.key, required this.api, required this.mood});

  final ApiClient api; // Connection to the server
  final Mood mood;     // The mood whose titles to show

  /// Titles per page loaded from the server
  static const pageSize = 30;

  @override
  State<MoodTitlesScreen> createState() => _MoodTitlesScreenState();
}

class _MoodTitlesScreenState extends State<MoodTitlesScreen> {
  final _scroll = ScrollController();
  final _random = Random();

  // The server shuffles by this number. It stays the same while more pages
  // load, so nothing repeats; a reshuffle picks a new one
  late int _shuffle = _newShuffle();

  List<TitleCard> _titles = [];
  int _total = 0;
  int _page = 0;            // Pages loaded so far
  bool _loading = true;     // First page
  bool _loadingMore = false;
  String? _error;

  bool get _hasMore => _titles.length < _total;

  int _newShuffle() => _random.nextInt(0x7FFFFFFE) + 1; // 1 to 2147483647

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

  /// Loads the first page of a fresh shuffle
  Future<void> _loadFirst() async {
    final shuffle = _newShuffle();
    setState(() {
      _shuffle = shuffle;
      _titles = [];
      _total = 0;
      _page = 0;
      _loading = true;
      _loadingMore = false;
      _error = null;
    });
    try {
      final page = await widget.api.getMoodTitles(
        widget.mood.id,
        limit: MoodTitlesScreen.pageSize,
        shuffle: shuffle,
      );
      if (!mounted || shuffle != _shuffle) return;
      setState(() {
        _titles = page.titles;
        _total = page.total;
        _page = 1;
      });
      _fillScreen();
    } on ApiException catch (e) {
      if (!mounted || shuffle != _shuffle) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted && shuffle == _shuffle) setState(() => _loading = false);
    }
  }

  /// On a wide screen a page may not fill it, so there's nothing to scroll.
  /// After each load, check again whether more are needed
  void _fillScreen() =>
      WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());

  void _onScroll() {
    if (!_scroll.hasClients || _loading || _loadingMore || !_hasMore) return;
    final position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent - 600) _loadMore();
  }

  Future<void> _loadMore() async {
    final shuffle = _shuffle;
    setState(() => _loadingMore = true);
    try {
      final page = await widget.api.getMoodTitles(
        widget.mood.id,
        page: _page + 1,
        limit: MoodTitlesScreen.pageSize,
        shuffle: shuffle,
      );
      if (!mounted || shuffle != _shuffle) return;
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
      if (!mounted || shuffle != _shuffle) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted && shuffle == _shuffle) {
        setState(() => _loadingMore = false);
      }
    }
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
    final mood = widget.mood;

    return Scaffold(
      appBar: AppBar(
        title: const Text('NOIREEL'),
        // "< Back" in the top left, back to the Mood tab
        leadingWidth: 104,
        leading: TextButton.icon(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.chevron_left, size: 28),
          label: const Text('Back'),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSecondary,
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadFirst, // pull down to reshuffle
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: FadeSlideIn(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                  child: Row(
                    children: [
                      MoodSwatch(
                        palette: NoiReelPalette.byName(mood.name),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          mood.name,
                          style: text.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (mood.description?.trim().isNotEmpty ?? false)
              SliverToBoxAdapter(
                child: FadeSlideIn.staggered(
                  index: 1,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Text(mood.description!.trim()),
                  ),
                ),
              ),
            if (!_loading && _error == null && _total > 0)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
    if (_error != null) {
      return [
        SliverToBoxAdapter(
          child: FadeSlideIn(
            child: _Notice(text: _error!, onRetry: _loadFirst),
          ),
        ),
      ];
    }
    if (_titles.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: FadeSlideIn(
            child: _Notice(
              text: 'No ${widget.mood.name} titles yet. Vote for this mood '
                  'on a title, or import more titles on the server.',
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
            key: ValueKey('$_shuffle-${_titles[i].id}'),
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
            // A spinner only while the next page is loading. An idle
            // spinner would animate forever and look stuck
            child: _loadingMore
                ? const CircularProgressIndicator()
                : _hasMore
                ? const SizedBox(height: 36)
                : Text(
                    "That's every ${widget.mood.name} title. "
                    'Pull down to reshuffle.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
          ),
        ),
      ),
    ];
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
      child: Column(
        children: [
          Text(text, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ],
      ),
    );
  }
}
