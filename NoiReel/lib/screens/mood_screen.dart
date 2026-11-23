import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/mood_row.dart';
import 'title_details_screen.dart';

/// The Mood tab: one row of posters per mood, ranked by how well each title
/// fits the mood (GU-01). Pull down to reload
///
/// Mood discovery by feeling and available time (RU-05) will go above the
/// rows later
class MoodScreen extends StatefulWidget {
  /// Creates the Mood tab
  const MoodScreen({super.key, required this.api});

  final ApiClient api; // Used to load moods and titles

  @override
  State<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends State<MoodScreen> {
  late Future<List<Mood>> _moods = widget.api.getMoods();

  // Changing this rebuilds the mood rows, so they reload their titles
  int _reloads = 0;

  Future<void> _reload() async {
    final moods = widget.api.getMoods();
    setState(() {
      _moods = moods;
      _reloads++;
    });
    await moods.catchError((_) => <Mood>[]);
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
        onRefresh: _reload,
        child: FutureBuilder<List<Mood>>(
          future: _moods,
          builder: (context, snapshot) {
            final loading = snapshot.connectionState != ConnectionState.done;
            final moods = snapshot.data ?? const <Mood>[];

            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                FadeSlideIn(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: Text(
                      'Browse by mood',
                      style: text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (snapshot.hasError)
                  FadeSlideIn(
                    child: _Notice(text: '${snapshot.error}', onRetry: _reload),
                  )
                else if (moods.isEmpty)
                  const FadeSlideIn(
                    child: _Notice(
                      text: 'No moods yet. '
                          'Run db/seed_moods.sql on the server.',
                    ),
                  )
                else
                  for (final (i, mood) in moods.indexed)
                    FadeSlideIn.staggered(
                      key: ValueKey('${mood.id}-$_reloads'),
                      index: i + 1, // after the heading
                      step: const Duration(milliseconds: 90),
                      child: MoodRow(
                        mood: mood,
                        api: widget.api,
                        onTitleTap: _open,
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
