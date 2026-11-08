import 'package:mysql_client/mysql_client.dart';

/// One active mood from `moods` (RU-05.01).
class Mood {
  /// Builds a [Mood] from a row selected by `MoodDao`.
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

  /// `moods.mood_id`.
  final int id;

  /// Display name, such as "Calm".
  final String name;

  /// Short description, if any.
  final String? description;

  /// Fallback color for a mood the app's themes don't know yet.
  final String? colorHex;

  /// Opposite moods, used by Regulate mode (RU-07.03).
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

/// One mood on one title, with its vote total (GU-03.03).
class TitleMood {
  /// Builds a [TitleMood] from a `title_mood_tags` or `title_mood_votes` row.
  TitleMood.fromRow(ResultSetRow row)
      : id = int.parse(row.colByName('mood_id')!),
        name = row.colByName('mood_name')!,
        colorHex = row.colByName('color_hex'),
        votes = int.parse(row.colByName('votes')!),
        isConfirmed = row.colByName('is_confirmed') == '1';

  /// `moods.mood_id`.
  final int id;

  /// Display name.
  final String name;

  /// Fallback color for a mood the app's themes don't know yet.
  final String? colorHex;

  /// Users who voted for this mood on this title.
  final int votes;

  /// True once the majority rule has adopted this mood for the title.
  final bool isConfirmed;

  /// JSON sent to the app.
  Map<String, dynamic> toJson() => {
        'moodId': id,
        'name': name,
        'colorHex': colorHex,
        'votes': votes,
        'isConfirmed': isConfirmed,
      };
}
