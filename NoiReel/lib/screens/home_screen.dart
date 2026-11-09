import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../theme/theme_controller.dart';
import '../widgets/mood_row.dart';
import '../widgets/theme_picker.dart';

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

  void _comingSoon(String what) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$what is coming soon.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NOIREEL')),
      bottomNavigationBar: _NavBar(
        onSearch: () => _comingSoon('Search'),
        onAccount: () => _comingSoon('Your account'),
      ),
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
                _MoodPicker(themes: widget.themes),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (snapshot.hasError)
                  _Notice(text: '${snapshot.error}', onRetry: _reload)
                else if (moods.isEmpty)
                  const _Notice(
                    text: 'No moods yet. Run db/seed_moods.sql on the server.',
                  )
                else
                  for (final mood in moods)
                    MoodRow(
                      key: ValueKey('${mood.id}-$_reloads'),
                      mood: mood,
                      api: widget.api,
                      onTitleTap: (title) =>
                          _comingSoon('The details page for ${title.name}'),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The theme section at the top of the home page.
class _MoodPicker extends StatelessWidget {
  const _MoodPicker({required this.themes});

  final ThemeController themes;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Align(
        alignment: Alignment.centerRight,
        child: ElevatedButton(
          onPressed: () => showThemePicker(context, themes),
          child: Text('Theme: ${themes.value.name}'),
        ),
      ),
    );
  }
}

/// The rounded navigation bar at the bottom, as in the mockups.
class _NavBar extends StatelessWidget {
  const _NavBar({required this.onSearch, required this.onAccount});

  final VoidCallback onSearch;
  final VoidCallback onAccount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    Widget item(IconData icon, String label, VoidCallback? onTap) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: colors.onSecondary),
                Text(
                  label,
                  style: TextStyle(
                    color: colors.onSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Container(
        decoration: BoxDecoration(
          color: colors.secondary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            item(Icons.home, 'Home', null),
            item(Icons.search, 'Search', onSearch),
            item(Icons.person, 'Account', onAccount),
          ],
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