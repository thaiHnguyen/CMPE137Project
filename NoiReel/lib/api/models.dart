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
