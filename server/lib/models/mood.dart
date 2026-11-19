import 'package:mysql_client/mysql_client.dart';

/// One active mood from `moods` (RU-05.01)
class Mood {
  /// Builds a [Mood] from a row selected by `MoodDao`
  Mood.fromRow(ResultSetRow row)
      : id = int.parse(row.colByName('mood_id')!),
        name = row.colByName('name')!,
        description = row.colByName('description'),
        colorHex = row.colByName('color_hex'),
        counterMoodIds = (row.colByName('counter_ids') ?? '')
            .split(',')
            .where((id) => id.isNotEmpty)
            .map(int.parse)
            .toList();

  /// `moods.mood_id`
  final int id;
  /// Display name, such as "Calm"
  final String name;
  /// Short description, if any
  final String? description;
  /// Fallback color for a mood the app's themes don't know yet
  final String? colorHex;
  /// Opposite moods, used by Regulate mode (RU-07.03)
  final List<int> counterMoodIds;

  /// JSON sent to the app.
  Map<String, dynamic> toJson() => {
        'moodId': id,
        'name': name,
        'description': description,
        'colorHex': colorHex,
        'counterMoodIds': counterMoodIds,
      };
}

/// One mood on one title, with its vote total (GU-03.03)
class TitleMood {
  /// Builds a [TitleMood] from a `title_mood_tags` or `title_mood_votes` row
  TitleMood.fromRow(ResultSetRow row)
      : id = int.parse(row.colByName('mood_id')!),
        name = row.colByName('mood_name')!,
        colorHex = row.colByName('color_hex'),
        votes = int.parse(row.colByName('votes')!);

  /// `moods.mood_id`
  final int id;
  /// Display name
  final String name;   
  /// Fallback color for a mood the app's themes 
  final String? colorHex;   
  /// Users who voted for this mood on this title
  final int votes;      

  /// JSON sent to the app
  Map<String, dynamic> toJson() => {
        'moodId': id,
        'name': name,
        'colorHex': colorHex,
        'votes': votes,
      };
}

/// A title's mood tags and vote results (GU-03.03, RU-11)
class TitleMoods {
  /// Creates a [TitleMoods]
  const TitleMoods({
    required this.tags,
    required this.votes,
    required this.voters,
  });

  /// Mood tags, most votes first. The first one is the primary tag.
  /// Before anyone votes, they come from the title's genres
  final List<TitleMood> tags;

  /// Every mood with at least one vote, most votes first
  final List<TitleMood> votes;

  /// Distinct users who voted any mood on this title
  final int voters;

  /// The `moods` object sent to the app
  Map<String, dynamic> toJson() => {
        'primary': tags.isEmpty ? null : tags.first.toJson(),
        'secondary': [for (final t in tags.skip(1)) t.toJson()],
        'voters': voters,
        'votes': [for (final v in votes) v.toJson()],
      };
}
