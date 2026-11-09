import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import 'poster_card.dart';

/// One mood row on the home page: the mood's name, then a sideways list
/// of its titles, best mood fit first (GU-01)
class MoodRow extends StatefulWidget {
  /// Creates a [MoodRow].
  const MoodRow({
    super.key,
    required this.mood,
    required this.api,
    this.onTitleTap,
  });

  final Mood mood;      // The mood this row shows
  final ApiClient api;  // Used to load the row's titles

  // Called when a poster is tapped
  final void Function(TitleCard title)? onTitleTap;

  @override
  State<MoodRow> createState() => _MoodRowState();
}

class _MoodRowState extends State<MoodRow> {
  late Future<TitlePage> _titles = _load();

  Future<TitlePage> _load() => widget.api.getMoodTitles(widget.mood.id);

  void _retry() => setState(() => _titles = _load());

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Row(
            children: [
              Text(
                widget.mood.name,
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
        SizedBox(
          // Poster (180) + gap + 2 lines of title + year, with spare room
          height: 265,
          child: FutureBuilder<TitlePage>(
            future: _titles,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _Message(
                  text: '${snapshot.error}',
                  action: ElevatedButton(
                    onPressed: _retry,
                    child: const Text('Try again'),
                  ),
                );
              }
              final titles = snapshot.data!.titles;
              if (titles.isEmpty) {
                return const _Message(text: 'No titles for this mood yet.');
              }
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: titles.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) => PosterCard(
                  title: titles[i],
                  onTap: widget.onTitleTap == null
                      ? null
                      : () => widget.onTitleTap!(titles[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    );
  }
}