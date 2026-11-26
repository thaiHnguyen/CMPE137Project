import 'package:mysql_client/mysql_client.dart';
import 'package:server/models/mood.dart';

/// A title as shown in a mood row or search result (GU-01.04, GU-02.03)
class TitleCard {
  /// Builds a [TitleCard] from a row selected by `TitleDao`
  TitleCard.fromRow(ResultSetRow row)
      : id = int.parse(row.colByName('title_id')!),
        type = row.colByName('type')!,
        name = row.colByName('name')!,
        year = _int(row.colByName('release_year')),
        posterUrl = row.colByName('poster_url');

  /// `titles.title_id`
  final int id;

  /// `movie` or `tv`
  final String type;

  /// Title name
  final String name;

  /// Release year, if known
  final int? year;

  /// Poster image. Null means the app shows a placeholder
  final String? posterUrl;

  /// JSON sent to the app
  Map<String, dynamic> toJson() => {
        'titleId': id,
        'type': type,
        'name': name,
        'year': year,
        'posterUrl': posterUrl,
      };
}
/// One page of titles, plus how many there are in total
typedef TitlePage = ({List<TitleCard> titles, int total});

/// A person credited on a title
class Credit {
  /// Builds a [Credit] from a row selected by `TitleDao`
  Credit.fromRow(ResultSetRow row)
      : personId = int.parse(row.colByName('person_id')!),
        name = row.colByName('name')!,
        role = row.colByName('role')!,
        character = row.colByName('character_name');

  /// `people.person_id`
  final int personId;

  /// Person's name
  final String name;

  /// `director`, `creator` or `cast`
  final String role;

  /// Character played. Cast only
  final String? character;

  /// JSON for a director or creator
  Map<String, dynamic> toJson() => {'personId': personId, 'name': name};

  /// JSON for a cast member
  Map<String, dynamic> toCastJson() => {...toJson(), 'character': character};
}

/// Everything on the title details page (GU-03)
/// Empty fields are null or empty so the app can hide them (GU-03.04)
class TitleDetails {
  /// Builds [TitleDetails] from a `titles` row and its related rows
  TitleDetails.fromRow(
    ResultSetRow row, {
    required this.genres,
    required this.credits,
    required this.moods,
    required this.ratingHistogram,
  })  : card = TitleCard.fromRow(row),
        originalName = row.colByName('original_name'),
        backdropUrl = row.colByName('backdrop_url'),
        synopsis = row.colByName('synopsis'),
        runtimeMin = _int(row.colByName('runtime_min')),
        seasons = _int(row.colByName('num_seasons')),
        episodes = _int(row.colByName('num_episodes')),
        avgRating = _double(row.colByName('avg_rating')),
        ratingCount = int.parse(row.colByName('rating_count')!);

  /// Poster, name, year and type.
  final TitleCard card;

  /// The title in its own language, only when it differs
  /// from [card]'s name.
  final String? originalName;

  /// Wide still shown behind the details page header
  final String? backdropUrl;
  /// Plot summary
  final String? synopsis;
  /// Movie length, or TV episode length, in minutes
  final int? runtimeMin;
  /// TV seasons
  final int? seasons;
  /// TV episodes
  final int? episodes;
  /// Average star rating
  final double? avgRating;
  /// Number of star ratings.
  final int ratingCount;
  /// Ratings at each star value
  final List<int> ratingHistogram;
  /// Genre names
  final List<String> genres;
  /// Directors or creators, then cast in billing order
  final List<Credit> credits;
  /// Mood tags and vote results
  final TitleMoods moods;

  /// JSON sent to the app
  Map<String, dynamic> toJson() => {
        ...card.toJson(),
        'originalName': originalName,
        'backdropUrl': backdropUrl,
        'synopsis': synopsis,
        'runtimeMin': runtimeMin,
        'seasons': seasons,
        'episodes': episodes,
        'avgRating': avgRating,
        'ratingCount': ratingCount,
        'ratingHistogram': ratingHistogram,
        'genres': genres,
        'directors': _named('director'),
        'creators': _named('creator'),
        'cast': [
          for (final c in credits)
            if (c.role == 'cast') c.toCastJson(),
        ],
        'moods': moods.toJson(),
      };

  List<Map<String, dynamic>> _named(String role) => [
        for (final c in credits)
          if (c.role == role) c.toJson(),
      ];
}

int? _int(String? value) => value == null ? null : int.parse(value);

double? _double(String? value) => value == null ? null : double.parse(value);
