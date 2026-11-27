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
  });

  /// Reads one mood tag or vote total from the server's JSON
  factory TitleMood.fromJson(Map<String, dynamic> json) => TitleMood(
    id: json['moodId'] as int,
    name: json['name'] as String,
    votes: json['votes'] as int,
  );

  final int id; // `moodId`
  final String name; // Mood name. Matches a theme name
  final int votes; // Users who voted for this mood on this title
}

/// Everything on the title details page, from `GET /titles/:id` (GU-03).
/// Empty fields are null or empty lists, so the page can hide them
class TitleDetails {
  /// Creates a [TitleDetails]
  const TitleDetails({
    required this.card,
    this.originalName,
    this.backdropUrl,
    this.synopsis,
    this.runtimeMin,
    this.seasons,
    this.episodes,
    this.avgRating,
    this.ratingCount = 0,
    this.ratingHistogram = const [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
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
      originalName: json['originalName'] as String?,
      backdropUrl: json['backdropUrl'] as String?,
      synopsis: json['synopsis'] as String?,
      runtimeMin: json['runtimeMin'] as int?,
      seasons: json['seasons'] as int?,
      episodes: json['episodes'] as int?,
      avgRating: (json['avgRating'] as num?)?.toDouble(),
      ratingCount: json['ratingCount'] as int,
      // Older servers don't send it: treat as no ratings
      ratingHistogram: switch (json['ratingHistogram']) {
        final List<dynamic> counts when counts.length == 10 =>
          counts.cast<int>(),
        _ => const [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      },
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
  final String? originalName; // Title in its own language, if different
  final String? backdropUrl; // Wide still behind the page header
  final String? synopsis; // Plot summary
  final int? runtimeMin; // Movie length, or TV episode length, in minutes
  final int? seasons; // TV only
  final int? episodes; // TV only
  final double? avgRating; // Average star rating, 0.5 to 5
  final int ratingCount; // Number of star ratings
  final List<int> ratingHistogram; // Ratings at 0.5, 1.0, ... 5.0 stars
  final List<String> genres; // Genre names
  final List<Person> directors; // Movies
  final List<Person> creators; // TV shows
  final List<Person> cast; // Top 10, in billing order
  final TitleMood? primaryMood; // Mood with the most votes (genre fit before any votes)
  final List<TitleMood> secondaryMoods; // Next moods, in order of votes
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

/// What the server sends after signing up or logging in
class AuthResult {
  /// Creates an [AuthResult]
  const AuthResult({
    required this.token,
    required this.userId,
    required this.role,
  });

  /// Reads the server's JSON
  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
    token: json['token'] as String,
    userId: json['userId'] as int,
    role: json['role'] as String,
  );

  final String token; // Sent as `Authorization: Bearer <token>`
  final int userId;   // `user_accounts.user_id`
  final String role;  // `user` or `admin`
}

/// Who a session belongs to, from `GET /auth/session`
class SessionInfo {
  /// Creates a [SessionInfo]
  const SessionInfo({
    required this.userId,
    required this.username,
    required this.role,
  });

  /// Reads the server's JSON
  factory SessionInfo.fromJson(Map<String, dynamic> json) => SessionInfo(
    userId: json['userId'] as int,
    username: json['username'] as String,
    role: json['role'] as String,
  );

  final int userId;
  final String username;
  final String role; // `user` or `admin`
}

/// One of the user's lists, as shown on the Lists tab
class UserListSummary {
  /// Creates a [UserListSummary]
  const UserListSummary({
    required this.id,
    required this.name,
    this.description,
    required this.entryCount,
    this.posterUrls = const [],
  });

  /// Reads the server's JSON
  factory UserListSummary.fromJson(Map<String, dynamic> json) =>
      UserListSummary(
        id: json['listId'] as int,
        name: json['name'] as String,
        description: json['description'] as String?,
        entryCount: json['entryCount'] as int,
        posterUrls: (json['posterUrls'] as List<dynamic>? ?? []).cast<String>(),
      );

  final int id;                  // `listId`
  final String name;
  final String? description;
  final int entryCount;          // Titles in the list
  final List<String> posterUrls; // First few posters, for the list's card
}

/// A list with all its entries, in the order they were added
class UserListDetails {
  /// Creates a [UserListDetails]
  const UserListDetails({
    required this.id,
    required this.name,
    this.description,
    this.entries = const [],
  });

  /// Reads the server's JSON
  factory UserListDetails.fromJson(Map<String, dynamic> json) =>
      UserListDetails(
        id: json['listId'] as int,
        name: json['name'] as String,
        description: json['description'] as String?,
        entries: [
          for (final e in json['entries'] as List<dynamic>)
            TitleCard.fromJson(e as Map<String, dynamic>),
        ],
      );

  final int id;                  // `listId`
  final String name;
  final String? description;
  final List<TitleCard> entries; // In the order they were added
}

/// The logged-in user's own profile (Profile tab and Profile Settings)
class Profile {
  /// Creates a [Profile]
  const Profile({
    required this.userId,
    required this.username,
    required this.email,
    this.role = 'user',
    this.displayName,
    this.bio,
    this.pronoun,
    this.avatarUrl,
    this.goat = const [null, null, null, null, null],
  });

  /// Reads the server's JSON
  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    userId: json['userId'] as int,
    username: json['username'] as String,
    email: json['email'] as String,
    role: json['role'] as String? ?? 'user',
    displayName: json['displayName'] as String?,
    bio: json['bio'] as String?,
    pronoun: json['pronoun'] as String?,
    avatarUrl: json['avatarUrl'] as String?,
    goat: [
      for (final t in json['goat'] as List<dynamic>)
        t == null ? null : TitleCard.fromJson(t as Map<String, dynamic>),
    ],
  );

  /// How many Greatest Of All Time slots a profile has
  static const goatSlots = 5;

  /// Pronouns the server accepts, with how the app shows them
  static const pronouns = {
    'he/him': 'He / him',
    'she/her': 'She / her',
    'they/them': 'They / them',
    'he/they': 'He / they',
    'she/they': 'She / they',
    'xe/xem': 'Xe / xem',
    'ze/hir': 'Ze / hir',
    'it/its': 'It / its',
  };

  final int userId;
  final String username;        // Can't be changed
  final String email;
  final String role;            // `user` or `admin`
  final String? displayName;    // Null shows the username instead
  final String? bio;
  final String? pronoun;        // A key of [pronouns], or null
  final String? avatarUrl;      // Server path like `/avatars/7-123.jpg`
  final List<TitleCard?> goat;  // Greatest Of All Time: 5 slots, null = empty

  /// The name to show: the display name, or the username without one
  String get shownName => displayName ?? username;

  /// The pronoun as shown, e.g. "She / her", or null
  String? get pronounLabel => pronoun == null ? null : pronouns[pronoun];

  /// A copy with a different Greatest Of All Time
  Profile withGoat(List<TitleCard?> goat) => Profile(
    userId: userId,
    username: username,
    email: email,
    role: role,
    displayName: displayName,
    bio: bio,
    pronoun: pronoun,
    avatarUrl: avatarUrl,
    goat: goat,
  );
}

/// The two built-in lists every user has
enum Collection {
  /// Titles marked with the heart
  favorites('favorites', 'Favorites'),

  /// Titles to watch later
  watchlist('watchlist', 'Watchlist');

  const Collection(this.path, this.label);

  final String path;  // URL word: /me/favorites, /me/titles/:id/favorite
  final String label; // Shown in the app
}

/// The user's review and log of one title: watch date, star rating,
/// review and mood votes. Every field can be empty
class TitleEntry {
  /// Creates a [TitleEntry]
  const TitleEntry({
    this.watchedOn,
    this.stars,
    this.review,
    this.spoiler = false,
    this.moodIds = const [],
    this.reviewId,
  });

  /// Reads the server's JSON
  factory TitleEntry.fromJson(Map<String, dynamic> json) {
    final date = json['watchedOn'] as String?;
    return TitleEntry(
      watchedOn: date == null ? null : DateTime.parse(date),
      stars: (json['stars'] as num?)?.toDouble(),
      review: json['review'] as String?,
      spoiler: json['spoiler'] as bool? ?? false,
      moodIds: [for (final id in json['moodIds'] as List<dynamic>) id as int],
      reviewId: json['reviewId'] as int?,
    );
  }

  final DateTime? watchedOn; // Date only (no time)
  final double? stars;       // 0.5 to 5 in half stars
  final String? review;
  final bool spoiler;        // The review gives away the plot
  final List<int> moodIds;   // Up to 3 moods voted on this title
  final int? reviewId;       // The review's id, or null with no review

  /// The date as the server wants it: `YYYY-MM-DD`
  String? get watchedOnText {
    final d = watchedOn;
    if (d == null) return null;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }
}

/// The user's status on one title, for its 3 dots menu
class TitleStatus {
  /// Creates a [TitleStatus]
  const TitleStatus({
    required this.titleId,
    this.favorite = false,
    this.watchlist = false,
    this.logged = false,
    this.entry = const TitleEntry(),
  });

  /// Reads the server's JSON
  factory TitleStatus.fromJson(Map<String, dynamic> json) => TitleStatus(
    titleId: json['titleId'] as int,
    favorite: json['favorite'] as bool,
    watchlist: json['watchlist'] as bool,
    logged: json['logged'] as bool,
    entry: TitleEntry.fromJson(json['entry'] as Map<String, dynamic>),
  );

  final int titleId;
  final bool favorite;   // In Favorites
  final bool watchlist;  // In Watchlist
  final bool logged;     // Has a date, rating or review
  final TitleEntry entry;

  /// True if the title is in [c]
  bool inCollection(Collection c) =>
      c == Collection.favorites ? favorite : watchlist;

  /// A copy with the title added to or taken out of [c]
  TitleStatus withCollection(Collection c, bool inIt) => TitleStatus(
    titleId: titleId,
    favorite: c == Collection.favorites ? inIt : favorite,
    watchlist: c == Collection.watchlist ? inIt : watchlist,
    logged: logged,
    entry: entry,
  );
}

/// Who wrote a review or comment
class Author {
  /// Creates an [Author]
  const Author({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl,
  });

  /// Reads the server's JSON
  factory Author.fromJson(Map<String, dynamic> json) => Author(
    id: json['userId'] as int,
    username: json['username'] as String,
    displayName: json['displayName'] as String?,
    avatarUrl: json['avatarUrl'] as String?,
  );

  final int id;
  final String username;
  final String? displayName;
  final String? avatarUrl; // Server path, e.g. /avatars/7-123.jpg

  /// The name to show
  String get shownName => displayName ?? username;
}

/// A review, in a list or on its own page
class Review {
  /// Creates a [Review]
  const Review({
    required this.id,
    required this.author,
    required this.title,
    required this.body,
    required this.createdAt,
    this.spoiler = false,
    this.edited = false,
    this.stars,
    this.watchedOn,
    this.favorite = false,
    this.likeCount = 0,
    this.commentCount = 0,
    this.likedByMe = false,
    this.isMine = false,
  });

  /// Reads the server's JSON
  factory Review.fromJson(Map<String, dynamic> json) {
    final date = json['watchedOn'] as String?;
    return Review(
      id: json['reviewId'] as int,
      author: Author.fromJson(json['author'] as Map<String, dynamic>),
      title: TitleCard.fromJson(json['title'] as Map<String, dynamic>),
      body: json['body'] as String,
      spoiler: json['spoiler'] as bool? ?? false,
      edited: json['edited'] as bool? ?? false,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (json['createdAt'] as int) * 1000,
      ),
      stars: (json['stars'] as num?)?.toDouble(),
      watchedOn: date == null ? null : DateTime.parse(date),
      favorite: json['favorite'] as bool? ?? false,
      likeCount: json['likeCount'] as int? ?? 0,
      commentCount: json['commentCount'] as int? ?? 0,
      likedByMe: json['likedByMe'] as bool? ?? false,
      isMine: json['isMine'] as bool? ?? false,
    );
  }

  final int id;
  final Author author;
  final TitleCard title;
  final String body;
  final DateTime createdAt;
  final bool spoiler;      // Hidden behind a warning for other people
  final bool edited;
  final double? stars;     // The author's rating
  final DateTime? watchedOn;
  final bool favorite;     // In the author's Favorites (the heart)
  final int likeCount;
  final int commentCount;
  final bool likedByMe;
  final bool isMine;

  /// A copy with new like numbers
  Review withLikes({required int count, required bool mine}) => Review(
    id: id,
    author: author,
    title: title,
    body: body,
    createdAt: createdAt,
    spoiler: spoiler,
    edited: edited,
    stars: stars,
    watchedOn: watchedOn,
    favorite: favorite,
    likeCount: count,
    commentCount: commentCount,
    likedByMe: mine,
    isMine: isMine,
  );
}

/// A comment under a review
class ReviewComment {
  /// Creates a [ReviewComment]
  const ReviewComment({
    required this.id,
    required this.author,
    required this.body,
    required this.createdAt,
    this.likeCount = 0,
    this.likedByMe = false,
    this.isMine = false,
  });

  /// Reads the server's JSON
  factory ReviewComment.fromJson(Map<String, dynamic> json) => ReviewComment(
    id: json['commentId'] as int,
    author: Author.fromJson(json['author'] as Map<String, dynamic>),
    body: json['body'] as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      (json['createdAt'] as int) * 1000,
    ),
    likeCount: json['likeCount'] as int? ?? 0,
    likedByMe: json['likedByMe'] as bool? ?? false,
    isMine: json['isMine'] as bool? ?? false,
  );

  final int id;
  final Author author;
  final String body;
  final DateTime createdAt;
  final int likeCount;
  final bool likedByMe;
  final bool isMine;

  /// A copy with new like numbers
  ReviewComment withLikes({required int count, required bool mine}) =>
      ReviewComment(
        id: id,
        author: author,
        body: body,
        createdAt: createdAt,
        likeCount: count,
        likedByMe: mine,
        isMine: isMine,
      );
}

/// One page of a title's reviews
class ReviewPage {
  /// Creates a [ReviewPage]
  const ReviewPage({required this.reviews, required this.total});

  /// Reads the server's JSON
  factory ReviewPage.fromJson(Map<String, dynamic> json) => ReviewPage(
    reviews: [
      for (final r in json['reviews'] as List<dynamic>)
        Review.fromJson(r as Map<String, dynamic>),
    ],
    total: json['total'] as int,
  );

  final List<Review> reviews;
  final int total; // Across all pages
}
