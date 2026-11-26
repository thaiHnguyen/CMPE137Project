import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../auth/auth_scope.dart';
import '../theme/noireel_theme.dart';
import '../widgets/dialogs.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/poster_card.dart';
import 'login_screen.dart';
import 'register_screen.dart';

/// The details page for one movie or show (GU-03), laid out like
/// Letterboxd's: a wide still fading into the page, round Back and 3 dots
/// buttons over it, then the name, original name, year, director and
/// length beside the poster (tap it to zoom), the overview, mood tags,
/// and the Ratings chart. Community votes, cast and genres follow.
/// Empty fields are hidden (GU-03.04)
class TitleDetailsScreen extends StatefulWidget {
  /// Creates the details page for [title]
  const TitleDetailsScreen({super.key, required this.api, required this.title});

  final ApiClient api; // Used to load the details
  final TitleCard title; // The poster that was tapped, shown while loading

  @override
  State<TitleDetailsScreen> createState() => _TitleDetailsScreenState();
}

class _TitleDetailsScreenState extends State<TitleDetailsScreen> {
  late Future<TitleDetails> _details = _load();

  Future<TitleDetails> _load() => widget.api.getTitle(widget.title.id);

  void _retry() => setState(() => _details = _load());

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Opens the poster full screen; it grows out of the small one
  void _zoomPoster(TitleCard card) {
    if (card.posterUrl == null) return;
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black87,
        barrierDismissible: true,
        barrierLabel: 'Close poster',
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, _, _) => _PosterViewer(card: card),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  /// ⋮ → Add to a list: pick one of your lists and add this title at the
  /// end. A guest is asked to sign in first
  Future<void> _addToList() async {
    final auth = AuthScope.maybeOf(context);
    final session = auth?.value;
    if (auth == null || session == null) {
      final choice = await askGuestToSignIn(
        context,
        'to add titles to a list',
      );
      if (choice == null || !mounted || auth == null) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => choice == GuestChoice.signIn
              ? LoginScreen(auth: auth)
              : RegisterScreen(auth: auth),
        ),
      );
      return;
    }
    if (session.isAdmin) {
      _snack("Admin accounts can't have lists.");
      return;
    }

    final picked = await showModalBottomSheet<UserListSummary>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _ListPicker(api: widget.api, token: session.token),
    );
    if (picked == null || !mounted) return;

    try {
      final list = await widget.api.getMyList(session.token, picked.id);
      if (list.entries.any((t) => t.id == widget.title.id)) {
        _snack('Already in "${list.name}".');
        return;
      }
      await widget.api.updateList(
        session.token,
        list.id,
        name: list.name,
        description: list.description,
        titleIds: [for (final t in list.entries) t.id, widget.title.id],
      );
      _snack('Added to "${list.name}".');
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<TitleDetails>(
        future: _details,
        builder: (context, snapshot) {
          final details = snapshot.data;
          final loading = snapshot.connectionState != ConnectionState.done;
          final card = details?.card ?? widget.title;

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _Backdrop(
                      url: details?.backdropUrl,
                      // No still: a blurred poster stands in
                      fallbackUrl: card.posterUrl,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _Centered(
                      child: _Header(
                        card: card,
                        details: details,
                        onPosterTap: () => _zoomPoster(card),
                      ),
                    ),
                  ),
                  if (loading)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    )
                  else if (snapshot.hasError)
                    SliverToBoxAdapter(
                      child: _Centered(
                        child: FadeSlideIn(
                          child: _ErrorMessage(
                            error: snapshot.error,
                            onRetry: _retry,
                          ),
                        ),
                      ),
                    )
                  else
                    SliverList.list(
                      children: [
                        for (final (i, section)
                            in _sections(details!).indexed)
                          FadeSlideIn.staggered(
                            index: i,
                            step: const Duration(milliseconds: 80),
                            child: section,
                          ),
                        const SizedBox(height: 40),
                      ],
                    ),
                ],
              ),
              // Back and 3 dots stay put over the page while it scrolls
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      _RoundButton(
                        icon: Icons.arrow_back,
                        tooltip: 'Back',
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const Spacer(),
                      _MoreMenu(onAddToList: _addToList),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// The parts of the page below the header, skipping empty ones
  /// (GU-03.04)
  static List<Widget> _sections(TitleDetails details) {
    final synopsis = details.synopsis?.trim() ?? '';
    final primary = details.primaryMood;
    return [
      if (synopsis.isNotEmpty)
        _Centered(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: _Synopsis(text: synopsis),
          ),
        ),
      if (primary != null)
        _Centered(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _MoodTag(mood: primary, isPrimary: true),
                for (final m in details.secondaryMoods) _MoodTag(mood: m),
              ],
            ),
          ),
        ),
      const SizedBox(height: 28),
      const _FullDivider(),
      _Panel(title: 'Ratings', child: _RatingsChart(details: details)),
      if (details.votes.isNotEmpty) ...[
        const _FullDivider(),
        _Panel(
          title: 'Community moods',
          trailing:
              '${details.voters} ${details.voters == 1 ? 'voter' : 'voters'}',
          child: Column(
            children: [
              for (final v in details.votes)
                _VoteBar(mood: v, topVotes: details.votes.first.votes),
            ],
          ),
        ),
      ],
      if (details.cast.isNotEmpty) ...[
        const _FullDivider(),
        _Panel(title: 'Cast', child: _CastList(cast: details.cast)),
      ],
      if (details.genres.isNotEmpty) ...[
        const _FullDivider(),
        _Panel(
          title: 'Genres',
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final g in details.genres) _GenreChip(label: g)],
          ),
        ),
      ],
    ];
  }
}

/// Keeps content a readable width on a wide Chrome window
class _Centered extends StatelessWidget {
  const _Centered({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: child,
    ),
  );
}

/// The wide still at the top, fading into the page background at the
/// bottom. Without one, a blurred copy of the poster stands in
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.url, required this.fallbackUrl});

  final String? url;         // The still, or null
  final String? fallbackUrl; // Poster to blur when there's no still

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).scaffoldBackgroundColor;
    final width = MediaQuery.sizeOf(context).width;
    final url = this.url;
    final fallback = fallbackUrl;

    // Room for the Back and 3 dots buttons even with no picture at all
    if (url == null && fallback == null) {
      return SizedBox(height: MediaQuery.paddingOf(context).top + 72);
    }

    final height = (width * 9 / 16).clamp(200.0, 340.0);
    final Widget image = url != null
        ? Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          )
        : ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Image.network(
              fallback!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          );

    return SizedBox(
      height: height,
      width: double.infinity,
      child: ExcludeSemantics(
        child: Stack(
          fit: StackFit.expand,
          children: [
            FadeSlideIn(distance: 0, child: image),
            // Fades the bottom into the page, like Letterboxd's
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, 0.45, 1],
                  colors: [
                    background.withValues(alpha: url == null ? 0.35 : 0),
                    background.withValues(alpha: url == null ? 0.5 : 0.1),
                    background,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A round, see-through button over the picture (Back, 3 dots)
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.45),
        foregroundColor: Colors.white,
        fixedSize: const Size(48, 48),
      ),
    );
  }
}

/// The ⋮ button and its menu
class _MoreMenu extends StatelessWidget {
  const _MoreMenu({required this.onAddToList});

  final VoidCallback onAddToList;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'More options',
      color: Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (choice) {
        if (choice == 'list') onAddToList();
      },
      icon: const Icon(Icons.more_vert),
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.45),
        foregroundColor: Colors.white,
        fixedSize: const Size(48, 48),
      ),
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'list',
          child: ListTile(
            leading: Icon(Icons.playlist_add),
            title: Text('Add to a list'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}

/// Name, original name, year and director on the left; poster on the
/// right. Shows the tapped poster's info right away, then fills in the
/// rest
class _Header extends StatelessWidget {
  const _Header({
    required this.card,
    required this.details,
    required this.onPosterTap,
  });

  final TitleCard card;
  final TitleDetails? details; // Null while loading
  final VoidCallback onPosterTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final bodyText = Theme.of(context).colorScheme.onSurface;
    final d = details;
    final isTv = card.type == 'tv';
    final makers = d == null
        ? const <Person>[]
        : (isTv ? d.creators : d.directors);
    final length = d == null ? const <String>[] : _lengthFacts(d);
    final original = d?.originalName;

    final byline = [
      if (card.year != null) '${card.year}',
      if (makers.isNotEmpty)
        isTv ? 'CREATED BY' : 'DIRECTED BY'
      else
        isTv ? 'TV SHOW' : 'MOVIE',
    ].join('  ·  ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.name,
                  style: text.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                if (original != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    original,
                    style: text.titleMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: bodyText.withValues(alpha: 0.75),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  byline,
                  style: text.labelLarge?.copyWith(
                    letterSpacing: 1.3,
                    color: bodyText.withValues(alpha: 0.8),
                  ),
                ),
                if (makers.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    makers.map((p) => p.name).join(', '),
                    style: text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                if (length.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(length.join('  ·  '), style: text.bodyLarge),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 118,
            child: Semantics(
              button: card.posterUrl != null,
              label: card.posterUrl == null ? null : 'View poster',
              child: GestureDetector(
                onTap: onPosterTap,
                child: Hero(
                  tag: _PosterViewer.heroTag(card),
                  child: PosterImage(url: card.posterUrl, type: card.type),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// "2h 10m" for a movie; seasons, episodes and episode length for TV
  static List<String> _lengthFacts(TitleDetails d) {
    final runtime = d.runtimeMin;
    if (d.card.type != 'tv') {
      return [if (runtime != null && runtime > 0) formatRuntime(runtime)];
    }
    return [
      if (d.seasons != null) _count(d.seasons!, 'season'),
      if (d.episodes != null) _count(d.episodes!, 'episode'),
      if (runtime != null && runtime > 0) '${formatRuntime(runtime)} each',
    ];
  }

  static String _count(int n, String word) => '$n $word${n == 1 ? '' : 's'}';
}

/// The poster full screen. Pinch or double-tap to zoom; tap outside it
/// or x to close
class _PosterViewer extends StatefulWidget {
  const _PosterViewer({required this.card});

  final TitleCard card;

  /// Shared by the small poster and this one so it grows between them
  static String heroTag(TitleCard card) => 'poster-${card.id}';

  @override
  State<_PosterViewer> createState() => _PosterViewerState();
}

class _PosterViewerState extends State<_PosterViewer>
    with SingleTickerProviderStateMixin {
  final _zoom = TransformationController();
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );
  Animation<Matrix4>? _zoomAnimation;
  TapDownDetails? _doubleTap;

  @override
  void initState() {
    super.initState();
    _animation.addListener(() {
      final value = _zoomAnimation?.value;
      if (value != null) _zoom.value = value;
    });
  }

  @override
  void dispose() {
    _zoom.dispose();
    _animation.dispose();
    super.dispose();
  }

  /// Double-tap zooms in on that spot, or back out
  void _toggleZoom() {
    final zoomedIn = _zoom.value.getMaxScaleOnAxis() > 1.01;
    final at = _doubleTap?.localPosition ?? Offset.zero;
    // Zoom 2.5x, keeping the tapped point where it was
    final target = zoomedIn
        ? Matrix4.identity()
        : (Matrix4.translationValues(-at.dx * 1.5, -at.dy * 1.5, 0)
            ..multiply(Matrix4.diagonal3Values(2.5, 2.5, 1)));
    _zoomAnimation = Matrix4Tween(begin: _zoom.value, end: target).animate(
      CurvedAnimation(parent: _animation, curve: Curves.easeOutCubic),
    );
    _animation.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = (size.width * 0.85).clamp(0.0, size.height * 0.8 * 2 / 3);

    return Stack(
      children: [
        Center(
          child: GestureDetector(
            onDoubleTapDown: (details) => _doubleTap = details,
            onDoubleTap: _toggleZoom,
            child: InteractiveViewer(
              transformationController: _zoom,
              maxScale: 4,
              child: SizedBox(
                width: width.toDouble(),
                child: Hero(
                  tag: _PosterViewer.heroTag(widget.card),
                  child: PosterImage(
                    url: widget.card.posterUrl,
                    type: widget.card.type,
                  ),
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _RoundButton(
                icon: Icons.close,
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The overview, a little larger and lighter than body text
class _Synopsis extends StatelessWidget {
  const _Synopsis({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodyLarge?.copyWith(
        height: 1.5,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
      ),
    );
  }
}

/// An edge-to-edge line between sections, in the theme's text color
class _FullDivider extends StatelessWidget {
  const _FullDivider();

  @override
  Widget build(BuildContext context) {
    final bodyText = Theme.of(context).colorScheme.onSurface;
    return Divider(
      color: bodyText.withValues(alpha: 0.25),
      height: 1.5,
      thickness: 1.5,
    );
  }
}

/// A section under a divider: a small spaced-out caption ("RATINGS"),
/// optional text on the right, then its content
class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.trailing});

  final String title;
  final String? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final bodyText = Theme.of(context).colorScheme.onSurface;
    final caption = text.labelLarge?.copyWith(
      letterSpacing: 1.4,
      color: bodyText.withValues(alpha: 0.8),
    );
    return _Centered(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title.toUpperCase(), style: caption)),
                if (trailing != null) Text(trailing!, style: caption),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

/// Letterboxd's ratings chart: a bar for each half star from 0.5 to 5,
/// with the average and five stars on the right
class _RatingsChart extends StatelessWidget {
  const _RatingsChart({required this.details});

  final TitleDetails details;

  static const _barsHeight = 64.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final bodyText = theme.colorScheme.onSurface;
    final star = theme.colorScheme.primary;
    final counts = details.ratingHistogram;
    final most = counts.fold(0, (a, b) => a > b ? a : b);
    final count = details.ratingCount;
    final average = details.avgRating;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Icon(Icons.star, size: 16, color: star),
            const SizedBox(width: 6),
            Expanded(
              child: SizedBox(
                height: _barsHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final (i, n) in counts.indexed)
                      Expanded(
                        child: Tooltip(
                          message:
                              '$n ${n == 1 ? 'rating' : 'ratings'} of '
                              '${_stars(i)}',
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            // An empty half star still shows a thin line
                            height: most == 0
                                ? 2
                                : (n / most * _barsHeight).clamp(
                                    2.0,
                                    _barsHeight,
                                  ),
                            decoration: BoxDecoration(
                              color: bodyText.withValues(alpha: 0.3),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  average == null || count == 0
                      ? '–'
                      : average.toStringAsFixed(1),
                  style: text.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w300,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 5; i++)
                      Icon(Icons.star, size: 14, color: star),
                  ],
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          count == 0
              ? 'No ratings yet.'
              : '$count ${count == 1 ? 'rating' : 'ratings'}',
          style: text.bodySmall,
        ),
      ],
    );
  }

  /// Bar [i] (0-9) as "½ star", "1 star", ... "5 stars"
  static String _stars(int i) {
    final halves = i + 1;
    if (halves == 1) return '½ star';
    final whole = halves ~/ 2;
    final label = halves.isOdd ? '$whole½' : '$whole';
    return '$label ${halves == 2 ? 'star' : 'stars'}';
  }
}

/// Your lists to pick from, for "3 dots" -> Add to a list
class _ListPicker extends StatelessWidget {
  const _ListPicker({required this.api, required this.token});

  final ApiClient api;
  final String token;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.6,
        ),
        child: FutureBuilder<List<UserListSummary>>(
          future: api.getMyLists(token),
          builder: (context, snapshot) {
            Widget body;
            if (snapshot.connectionState != ConnectionState.done) {
              body = const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              );
            } else if (snapshot.hasError) {
              body = Padding(
                padding: const EdgeInsets.all(24),
                child: Text('${snapshot.error}', textAlign: TextAlign.center),
              );
            } else if (snapshot.data!.isEmpty) {
              body = const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  "You haven't made any lists yet. Make one from the List "
                  'tab on your Profile.',
                  textAlign: TextAlign.center,
                ),
              );
            } else {
              final lists = snapshot.data!;
              body = Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final list in lists)
                      ListTile(
                        leading: const Icon(Icons.list_alt),
                        title: Text(
                          list.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${list.entryCount} '
                          '${list.entryCount == 1 ? 'entry' : 'entries'}',
                        ),
                        onTap: () => Navigator.pop(context, list),
                      ),
                  ],
                ),
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Add to a list',
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                body,
                const SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Minutes as "45m", "2h" or "2h 10m"
String formatRuntime(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

class _GenreChip extends StatelessWidget {
  const _GenreChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final bodyText = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: bodyText.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

/// A mood tag in that mood theme's own header colors
class _MoodTag extends StatelessWidget {
  const _MoodTag({required this.mood, this.isPrimary = false});

  final TitleMood mood;
  final bool isPrimary; // The primary tag is bigger

  @override
  Widget build(BuildContext context) {
    final palette = NoiReelPalette.byName(mood.name);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isPrimary ? 16 : 12,
        vertical: isPrimary ? 8 : 5,
      ),
      decoration: BoxDecoration(
        color: palette.navBar,
        border: Border.all(color: palette.swatchBorder, width: 2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        mood.name,
        style: TextStyle(
          color: palette.navText,
          fontWeight: FontWeight.w800,
          fontSize: isPrimary ? 18 : 14,
        ),
      ),
    );
  }
}

/// One row of the vote results: mood name, a bar, and the vote count
class _VoteBar extends StatelessWidget {
  const _VoteBar({required this.mood, required this.topVotes});

  final TitleMood mood;
  final int topVotes; // Votes of the most-voted mood

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final bodyText = Theme.of(context).colorScheme.onSurface;
    final palette = NoiReelPalette.byName(mood.name);
    final share = topVotes == 0 ? 0.0 : mood.votes / topVotes;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              mood.name,
              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Container(
              height: 16,
              decoration: BoxDecoration(
                color: bodyText.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: share.clamp(0.04, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: palette.navBar,
                    border: Border.all(color: palette.swatchBorder, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              '${mood.votes}',
              textAlign: TextAlign.right,
              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Top cast: name, then the character they play
class _CastList extends StatelessWidget {
  const _CastList({required this.cast});

  final List<Person> cast;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final p in cast)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: p.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (p.character?.trim().isNotEmpty ?? false)
                    TextSpan(text: '  as ${p.character!.trim()}'),
                ],
              ),
              style: text.bodyMedium,
            ),
          ),
      ],
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final notFound =
        error is ApiException && (error! as ApiException).statusCode == 404;
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        children: [
          Text(
            notFound ? "This title isn't in the catalog anymore." : '$error',
            textAlign: TextAlign.center,
          ),
          if (!notFound) ...[
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ],
      ),
    );
  }
}
