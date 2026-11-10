import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../theme/noireel_theme.dart';
import '../widgets/poster_card.dart';

/// The details page for one movie or show (GU-03): poster and facts,
/// mood tags with community vote results, synopsis, and credits
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NOIREEL')),
      body: FutureBuilder<TitleDetails>(
        future: _details,
        builder: (context, snapshot) {
          final details = snapshot.data;
          final loading = snapshot.connectionState != ConnectionState.done;

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              // Keeps lines readable on a wide Chrome window
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                children: [
                  _Header(
                    card: details?.card ?? widget.title,
                    details: details,
                  ),
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (snapshot.hasError)
                    _ErrorMessage(error: snapshot.error, onRetry: _retry)
                  else ...[
                    _MoodSection(details: details!),
                    if (details.synopsis?.trim().isNotEmpty ?? false)
                      _Section(
                        title: 'Overview',
                        child: Text(details.synopsis!.trim()),
                      ),
                    if (details.directors.isNotEmpty)
                      _Section(
                        title: 'Directed by',
                        child: Text(_names(details.directors)),
                      ),
                    if (details.creators.isNotEmpty)
                      _Section(
                        title: 'Created by',
                        child: Text(_names(details.creators)),
                      ),
                    if (details.cast.isNotEmpty)
                      _Section(
                        title: 'Cast',
                        child: _CastList(cast: details.cast),
                      ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static String _names(List<Person> people) =>
      people.map((p) => p.name).join(', ');
}

/// Poster beside the name, year, type, length, rating and genres.
/// Shows the tapped poster's info right away, then fills in the rest
class _Header extends StatelessWidget {
  const _Header({required this.card, this.details});

  final TitleCard card;
  final TitleDetails? details; // Null while loading

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final d = details;

    final facts = [
      if (card.year != null) '${card.year}',
      card.type == 'tv' ? 'TV show' : 'Movie',
      if (d != null) ..._lengthFacts(d),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: PosterImage(url: card.posterUrl, type: card.type),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                card.name,
                style: text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(facts.join('  ·  '), style: text.bodyMedium),
              if (d != null && d.ratingCount > 0 && d.avgRating != null) ...[
                const SizedBox(height: 6),
                Text(
                  '★ ${d.avgRating!.toStringAsFixed(1)}  ·  '
                  '${d.ratingCount} ${d.ratingCount == 1 ? 'rating' : 'ratings'}',
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
              if (d != null && d.genres.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [for (final g in d.genres) _GenreChip(label: g)],
                ),
              ],
            ],
          ),
        ),
      ],
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

/// Mood tags, then the community vote results, like Fragrantica's
/// accords and "according to your votes" panel (GU-03.03)
class _MoodSection extends StatelessWidget {
  const _MoodSection({required this.details});

  final TitleDetails details;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final primary = details.primaryMood;
    final votes = details.votes;

    if (primary == null && votes.isEmpty) {
      return const _Section(title: 'Moods', child: Text('No mood tags yet.'));
    }

    // Bars are relative to the mood with the most votes, so the top
    // mood always fills its bar
    final topVotes = votes.isEmpty ? 1 : votes.first.votes;

    return _Section(
      title: 'Moods',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (primary != null)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _MoodTag(mood: primary, isPrimary: true),
                for (final m in details.secondaryMoods) _MoodTag(mood: m),
              ],
            ),
          if (votes.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'Community votes  ·  ${details.voters} '
              '${details.voters == 1 ? 'voter' : 'voters'}',
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            for (final v in votes) _VoteBar(mood: v, topVotes: topVotes),
            const SizedBox(height: 4),
            Text(
              '✓ = most voters picked this mood, so it shows as a tag.',
              style: text.bodySmall,
            ),
          ] else ...[
            const SizedBox(height: 10),
            Text(
              'No votes yet. These tags come from the genres.',
              style: text.bodySmall,
            ),
          ],
        ],
      ),
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
              '${mood.votes}${mood.isConfirmed ? ' ✓' : ''}',
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

/// A heading with content under it
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
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
