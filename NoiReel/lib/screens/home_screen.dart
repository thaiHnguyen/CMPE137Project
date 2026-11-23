import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../theme/theme_controller.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/poster_card.dart';
import '../widgets/theme_picker.dart';
import 'title_details_screen.dart';

/// The home page: the theme button, then "Discovery", a grid of random
/// posters like Letterboxd's home. The grid reshuffles every time Home is
/// tapped in the nav bar, and when pulled down
class HomeScreen extends StatefulWidget {
  /// Creates the home page.
  const HomeScreen({
    super.key,
    required this.api,
    required this.themes,
    this.reshuffle,
  });

  final ApiClient api;            // Used to load the posters
  final ThemeController themes;   // The app's current theme
  final Listenable? reshuffle;    // Fires when Home is tapped in the nav bar

  /// Posters in the grid: 10 rows of 3 on a phone
  static const gridSize = 30;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scroll = ScrollController();
  late Future<List<TitleCard>> _titles = _load();

  // Bumped on every reshuffle, so the posters animate in again
  int _shuffle = 0;

  Future<List<TitleCard>> _load() =>
      widget.api.discover(limit: HomeScreen.gridSize);

  @override
  void initState() {
    super.initState();
    widget.reshuffle?.addListener(_onHomeTapped);
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reshuffle != widget.reshuffle) {
      oldWidget.reshuffle?.removeListener(_onHomeTapped);
      widget.reshuffle?.addListener(_onHomeTapped);
    }
  }

  @override
  void dispose() {
    widget.reshuffle?.removeListener(_onHomeTapped);
    _scroll.dispose();
    super.dispose();
  }

  void _onHomeTapped() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _reshuffle();
  }

  /// Loads a new random set of posters
  Future<void> _reshuffle() async {
    final titles = _load();
    setState(() {
      _titles = titles;
      _shuffle++;
    });
    await titles.catchError((_) => <TitleCard>[]);
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
      appBar: AppBar(title: const Text('NOIREEL')),
      body: RefreshIndicator(
        onRefresh: _reshuffle,
        child: FutureBuilder<List<TitleCard>>(
          future: _titles,
          builder: (context, snapshot) {
            final loading = snapshot.connectionState != ConnectionState.done;
            final titles = snapshot.data ?? const <TitleCard>[];

            return CustomScrollView(
              controller: _scroll,
              // Lets pull-to-refresh work even when the grid is short
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: FadeSlideIn(
                    child: _ThemeButton(themes: widget.themes),
                  ),
                ),
                SliverToBoxAdapter(
                  child: FadeSlideIn.staggered(
                    index: 1,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Text(
                        'Discovery',
                        style: text.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
                if (loading)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (snapshot.hasError)
                  SliverToBoxAdapter(
                    child: FadeSlideIn(
                      child: _Notice(
                        text: '${snapshot.error}',
                        onRetry: _reshuffle,
                      ),
                    ),
                  )
                else if (titles.isEmpty)
                  const SliverToBoxAdapter(
                    child: FadeSlideIn(
                      child: _Notice(
                        text: 'No titles yet. Run bin/import_tmdb.dart '
                            'on the server.',
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverGrid.builder(
                      // 3 posters across on a phone, more on wider screens
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 160,
                            childAspectRatio: 2 / 3,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                      itemCount: titles.length,
                      itemBuilder: (context, i) => FadeSlideIn.staggered(
                        key: ValueKey('$_shuffle-${titles[i].id}'),
                        index: i < 12 ? i : 0, // first screenful staggers
                        step: const Duration(milliseconds: 40),
                        distance: 16,
                        child: _GridPoster(
                          title: titles[i],
                          onTap: () => _open(titles[i]),
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

/// One poster in the Discovery grid. Posters only, like Letterboxd; the
/// name is read by screen readers and shown on the details page
class _GridPoster extends StatelessWidget {
  const _GridPoster({required this.title, required this.onTap});

  final TitleCard title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title.year == null ? title.name : '${title.name}, ${title.year}',
      excludeSemantics: true,
      child: Tooltip(
        message: title.name,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: PosterImage(url: title.posterUrl, type: title.type),
        ),
      ),
    );
  }
}

/// The theme button at the top of the home page
class _ThemeButton extends StatelessWidget {
  const _ThemeButton({required this.themes});

  final ThemeController themes;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Align(
        alignment: Alignment.centerRight,
        // Rebuilds by itself when the theme changes, since the home page
        // lives inside its tab's own Navigator
        child: ValueListenableBuilder(
          valueListenable: themes,
          builder: (context, palette, _) => ElevatedButton(
            onPressed: () => showThemePicker(context, themes),
            child: Text('Theme: ${palette.name}'),
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
