// What the server sends back. Field names match server/API.md

/// One mood from `GET /moods`
class Mood {
  /// Creates a [Mood].
  const Mood({
    required this.id,
    required this.name,
    this.description,
    this.counterMoodIds = const [],
  });

  /// Reads one mood from the server's JSON
  factory Mood.fromJson(Map<String, dynamic> json) => Mood(
    id: json['moodId'] as int,
    name: json['name'] as String,
    description: json['description'] as String?,
    counterMoodIds: (json['counterMoodIds'] as List<dynamic>? ?? [])
        .cast<int>(),
  );

  final int id;                   /// `moodId`, used in `/moods/:id/titles`
  final String name;              /// Mood name. Matches a theme name
  final String? description;      /// Short description, if any
  final List<int> counterMoodIds; /// Opposite moods, for Regulate mode later
}

/// A title as shown on a poster card.
class TitleCard {
  /// Creates a [TitleCard].
  const TitleCard({
    required this.id,
    required this.type,
    required this.name,
    this.year,
    this.posterUrl,
  });

  /// Reads one title from the server's JSON
  factory TitleCard.fromJson(Map<String, dynamic> json) => TitleCard(
    id: json['titleId'] as int,
    type: json['type'] as String,
    name: json['name'] as String,
    year: json['year'] as int?,
    posterUrl: json['posterUrl'] as String?,
  );

  final int id;               /// `titleId`, used in `/titles/:id`
  final String type;          /// `movie` or `tv`
  final String name;          /// Title name
  final int? year;            /// Release year, if known
  final String? posterUrl;   /// Poster image. Null means show a placeholder (GU-02.03)
}

/// One page of titles, plus how many there are in total
class TitlePage {
  /// Creates a [TitlePage].
  const TitlePage({required this.titles, required this.total});

  /// Reads a page from the server's JSON.
  factory TitlePage.fromJson(Map<String, dynamic> json) => TitlePage(
    titles: [
      for (final t in json['titles'] as List<dynamic>)
        TitleCard.fromJson(t as Map<String, dynamic>),
    ],
    total: json['total'] as int,
  );


  final List<TitleCard> titles;   /// The titles on this page
  final int total;                /// Titles across all pages
}

/// A person credited on a title: a director, a creator, or a cast member
class Person {
  /// Creates a [Person]
  const Person({required this.id, required this.name, this.character});

  /// Reads one person from the server's JSON
  factory Person.fromJson(Map<String, dynamic> json) => Person(
    id: json['personId'] as int,
    name: json['name'] as String,
    character: json['character'] as String?,
  );

  final int id; // `personId`
  final String name; // Person's name
  final String? character; // Character played. Cast only
}

/// One mood on one title, with how many users voted for it
class TitleMood {
  /// Creates a [TitleMood]
  const TitleMood({
    required this.id,
    required this.name,
    required this.votes,
    required this.isConfirmed,
  });

  /// Reads one mood tag or vote total from the server's JSON
  factory TitleMood.fromJson(Map<String, dynamic> json) => TitleMood(
    id: json['moodId'] as int,
    name: json['name'] as String,
    votes: json['votes'] as int,
    isConfirmed: json['isConfirmed'] as bool,
  );

  final int id; // `moodId`
  final String name; // Mood name. Matches a theme name
  final int votes; // Users who voted for this mood on this title
  final bool isConfirmed; // True once most voters picked this mood
}

/// Everything on the title details page, from `GET /titles/:id` (GU-03).
/// Empty fields are null or empty lists, so the page can hide them
class TitleDetails {
  /// Creates a [TitleDetails]
  const TitleDetails({
    required this.card,
    this.synopsis,
    this.runtimeMin,
    this.seasons,
    this.episodes,
    this.avgRating,
    this.ratingCount = 0,
    this.genres = const [],
    this.directors = const [],
    this.creators = const [],
    this.cast = const [],
    this.primaryMood,
    this.secondaryMoods = const [],
    this.voters = 0,
    this.votes = const [],
  });

  /// Reads a title's details from the server's JSON
  factory TitleDetails.fromJson(Map<String, dynamic> json) {
    final moods = json['moods'] as Map<String, dynamic>;
    final primary = moods['primary'] as Map<String, dynamic>?;
    return TitleDetails(
      card: TitleCard.fromJson(json),
      synopsis: json['synopsis'] as String?,
      runtimeMin: json['runtimeMin'] as int?,
      seasons: json['seasons'] as int?,
      episodes: json['episodes'] as int?,
      avgRating: (json['avgRating'] as num?)?.toDouble(),
      ratingCount: json['ratingCount'] as int,
      genres: (json['genres'] as List<dynamic>).cast<String>(),
      directors: _people(json['directors']),
      creators: _people(json['creators']),
      cast: _people(json['cast']),
      primaryMood: primary == null ? null : TitleMood.fromJson(primary),
      secondaryMoods: _moods(moods['secondary']),
      voters: moods['voters'] as int,
      votes: _moods(moods['votes']),
    );
  }

  final TitleCard card; // Id, type, name, year and poster
  final String? synopsis; // Plot summary
  final int? runtimeMin; // Movie length, or TV episode length, in minutes
  final int? seasons; // TV only
  final int? episodes; // TV only
  final double? avgRating; // Average star rating, 0.5 to 5
  final int ratingCount; // Number of star ratings
  final List<String> genres; // Genre names
  final List<Person> directors; // Movies
  final List<Person> creators; // TV shows
  final List<Person> cast; // Top 10, in billing order
  final TitleMood? primaryMood; // The title's main mood tag
  final List<TitleMood> secondaryMoods; // Supporting mood tags
  final int voters; // Users who voted any mood on this title
  final List<TitleMood> votes; // Vote results, highest first

  static List<Person> _people(Object? list) => [
    for (final p in list as List<dynamic>)
      Person.fromJson(p as Map<String, dynamic>),
  ];

  static List<TitleMood> _moods(Object? list) => [
    for (final m in list as List<dynamic>)
      TitleMood.fromJson(m as Map<String, dynamic>),
  ];
}
