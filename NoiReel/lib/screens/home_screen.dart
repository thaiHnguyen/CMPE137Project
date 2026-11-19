import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../theme/theme_controller.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/mood_row.dart';
import '../widgets/theme_picker.dart';
import 'title_details_screen.dart';

/// The home page: the mood/theme picker, then one row per mood (GU-01)
class HomeScreen extends StatefulWidget {
  /// Creates the home page.
  const HomeScreen({super.key, required this.api, required this.themes});

  final ApiClient api;            // Used to load moods and titles
  final ThemeController themes;   // The app's current theme

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Mood>> _moods = widget.api.getMoods();

  // Changing this rebuilds the mood rows, so they reload their titles.
  int _reloads = 0;

  Future<void> _reload() async {
    final moods = widget.api.getMoods();
    setState(() {
      _moods = moods;
      _reloads++;
    });
    await moods.catchError((_) => <Mood>[]);
  }

  @override
  Widget build(BuildContext context) {
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
                FadeSlideIn(child: _MoodPicker(themes: widget.themes)),
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
                      index: i + 1, // after the theme button
                      step: const Duration(milliseconds: 90),
                      child: MoodRow(
                        mood: mood,
                        api: widget.api,
                        onTitleTap: (title) => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => TitleDetailsScreen(
                              api: widget.api,
                              title: title,
                            ),
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

/// The theme section at the top of the home page
class _MoodPicker extends StatelessWidget {
  const _MoodPicker({required this.themes});

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
