import 'package:mysql_client/mysql_client.dart';
import 'package:server/browse/paging.dart';
import 'package:server/models/mood.dart';
import 'package:server/models/title.dart';

/// Reads the catalog for browsing: `titles`, their genres, credits and moods
class TitleDao {
  /// Creates a DAO on a connection pool (normally the shared `db`)
  TitleDao(this._db);

  final MySQLConnectionPool _db;

  /// Top cast shown on the details page (GU-03.02)
  static const topCast = 10;

  /// Mood tags shown on the details page (GU-03.03)
  static const _topTags = 5;

  // A mood row holds titles that fit the mood. Titles with 1-199 TMDB votes
  // are left out so rows don't fill up with unknown titles, unless the
  // community or an admin put them there. 0 votes means there is no TMDB
  // score to judge by (admin-created titles, or an older import)
  static const _moodRowFrom = '''
FROM title_moods tm
JOIN titles t ON t.title_id = tm.title_id
WHERE tm.mood_id = :mood AND tm.mood_score > 0
  AND (tm.is_confirmed OR tm.is_curated
        OR t.tmdb_vote_count = 0 OR t.tmdb_vote_count >= 200)''';

  // Mood fit decides the order. TMDB rating, then popularity, only break ties
  static const _moodRowTitles = '''
SELECT t.title_id, t.type, t.name, t.release_year, t.poster_url
$_moodRowFrom
ORDER BY tm.mood_score DESC, t.tmdb_vote_avg DESC, t.popularity DESC,
          t.title_id
LIMIT :limit OFFSET :offset''';

  static const _moodRowCount = 'SELECT COUNT(*) AS total $_moodRowFrom';

  /// GU-01: titles for a mood row, best mood fit first.
  Future<TitlePage> titlesForMood(int moodId, Paging paging) async {
    final count = await _db.execute(_moodRowCount, {'mood': moodId});
    final res = await _db.execute(_moodRowTitles, {
      'mood': moodId,
      'limit': paging.limit,
      'offset': paging.offset,
    });
    return (
      titles: res.rows.map(TitleCard.fromRow).toList(),
      total: int.parse(count.rows.first.colByName('total')!),
    );
  }

  static const _title = '''
SELECT title_id, type, name, synopsis, release_year, runtime_min, num_seasons,
        num_episodes, poster_url, avg_rating, rating_count, mood_voter_count
FROM titles WHERE title_id = :id''';

  static const _genres = '''
SELECT g.name
FROM title_genres tg JOIN genres g ON g.genre_id = tg.genre_id
WHERE tg.title_id = :id
ORDER BY g.name''';

  // `role` is an ENUM, so it sorts as director, creator, cast.
  static const _credits = '''
SELECT p.person_id, p.name, c.role, c.character_name
FROM title_credits c JOIN people p ON p.person_id = c.person_id
WHERE c.title_id = :id
ORDER BY c.role, c.billing_order IS NULL, c.billing_order, p.name''';

  static const _tags = '''
SELECT mood_id, mood_name, color_hex, votes, is_confirmed
FROM title_mood_tags
WHERE title_id = :id
ORDER BY tag_rank
LIMIT $_topTags''';

  static const _votes = '''
SELECT mood_id, mood_name, color_hex, votes, is_confirmed
FROM title_mood_votes
WHERE title_id = :id
ORDER BY votes DESC, mood_id''';

  /// GU-03: the details page for one title, or null if it doesn't exist
  Future<TitleDetails?> findDetails(int id) async {
    final params = {'id': id};
    final title = await _db.execute(_title, params);
    if (title.rows.isEmpty) return null;

    final genres = await _db.execute(_genres, params);
    final credits = await _db.execute(_credits, params);
    final tags = await _db.execute(_tags, params);
    final votes = await _db.execute(_votes, params);

    final people = credits.rows.map(Credit.fromRow).toList();
    return TitleDetails.fromRow(
      title.rows.first,
      genres: genres.rows.map((r) => r.colByName('name')!).toList(),
      credits: [
        ...people.where((c) => c.role != 'cast'),
        ...people.where((c) => c.role == 'cast').take(topCast),
      ],
      tags: tags.rows.map(TitleMood.fromRow).toList(),
      votes: votes.rows.map(TitleMood.fromRow).toList(),
    );
  }

  // LIKE instead of the FULLTEXT indexes: FULLTEXT skips short and common
  // words, so "Up" or "It" would never be found, and it can't match part of
  // a word while the user is still typing
  static const _searchFrom = '''
FROM titles t
WHERE t.name LIKE :contains
    OR EXISTS (SELECT 1
              FROM title_credits c JOIN people p ON p.person_id = c.person_id
              WHERE c.title_id = t.title_id AND p.name LIKE :contains)''';

  // Exact title, then title starts with it, then title contains it, then a
  // match on a person's name. Popularity only breaks ties.
  static const _searchTitles = '''
SELECT t.title_id, t.type, t.name, t.release_year, t.poster_url
$_searchFrom
ORDER BY CASE WHEN t.name = :exact THEN 0
              WHEN t.name LIKE :prefix THEN 1
              WHEN t.name LIKE :contains THEN 2
              ELSE 3 END,
          t.popularity DESC, t.title_id
LIMIT :limit OFFSET :offset''';

  static const _searchCount = 'SELECT COUNT(*) AS total $_searchFrom';

  /// GU-02.02: titles whose name, director/creator or cast match [keyword]
  Future<TitlePage> search(String keyword, Paging paging) async {
    final like = escapeLike(keyword);
    final count = await _db.execute(_searchCount, {'contains': '%$like%'});
    final res = await _db.execute(_searchTitles, {
      'exact': keyword,
      'prefix': '$like%',
      'contains': '%$like%',
      'limit': paging.limit,
      'offset': paging.offset,
    });
    return (
      titles: res.rows.map(TitleCard.fromRow).toList(),
      total: int.parse(count.rows.first.colByName('total')!),
    );
  }

  /// Makes `%` and `_` in user input match literally in a LIKE pattern
  static String escapeLike(String value) => value
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');
}
