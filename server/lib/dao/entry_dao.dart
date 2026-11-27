import 'package:mysql_client/mysql_client.dart';
import 'package:server/models/title_entry.dart';

/// Reviews and logs (RU-06, RU-07, RU-10): one user's date, rating,
/// review and mood votes on one title, saved together in one transaction
/// A user has at most one of each per title; saving again replaces them
class EntryDao {
  /// Creates a DAO on a connection pool (normally the shared `db`)
  EntryDao(this._db);

  final MySQLConnectionPool _db;

  // Same lock as mood voting, so votes and this save never interleave
  static const _lockTitle =
      'SELECT title_id FROM titles WHERE title_id = :title FOR UPDATE';

  static const _rating = '''
SELECT stars, DATE_FORMAT(updated_at, '%Y-%m-%d %H:%i:%s') AS changed
FROM ratings WHERE user_id = :user AND title_id = :title''';

  static const _review = '''
SELECT review_id, body, is_spoiler,
        DATE_FORMAT(updated_at, '%Y-%m-%d %H:%i:%s') AS changed
FROM reviews WHERE user_id = :user AND title_id = :title''';

  static const _log = '''
SELECT log_id, DATE_FORMAT(watched_on, '%Y-%m-%d') AS watched_on,
        DATE_FORMAT(created_at, '%Y-%m-%d %H:%i:%s') AS changed
FROM watch_logs WHERE user_id = :user AND title_id = :title
ORDER BY watched_on DESC, log_id DESC LIMIT 1''';

  static const _moods = '''
SELECT mood_id FROM user_mood_tags
WHERE user_id = :user AND title_id = :title
ORDER BY created_at, mood_id''';

  static const _saveRating = '''
INSERT INTO ratings (user_id, title_id, stars) VALUES (:user, :title, :stars)
ON DUPLICATE KEY UPDATE stars = VALUES(stars)''';

  // is_edited is set before body changes, so it compares the old text
  static const _saveReview = '''
INSERT INTO reviews (user_id, title_id, body, is_spoiler)
VALUES (:user, :title, :body, :spoiler)
ON DUPLICATE KEY UPDATE
  is_edited = is_edited OR body <> VALUES(body),
  body = VALUES(body),
  is_spoiler = VALUES(is_spoiler)''';

  // The title's average and count, kept on `titles` for fast reads
  static const _refreshRatings = '''
UPDATE titles SET
  avg_rating = (SELECT ROUND(AVG(stars), 1) FROM ratings
                WHERE title_id = :title),
  rating_count = (SELECT COUNT(*) FROM ratings WHERE title_id = :title)
WHERE title_id = :title''';

  /// [userId]'s entry for [titleId]. Never null: with nothing saved, every
  /// field is empty and [TitleEntry.logged] is false
  Future<TitleEntry> find(int userId, int titleId) async {
    final p = {'user': userId, 'title': titleId};
    final rating = await _db.execute(_rating, p);
    final review = await _db.execute(_review, p);
    final log = await _db.execute(_log, p);
    final moods = await _db.execute(_moods, p);

    final r = rating.rows.isEmpty ? null : rating.rows.first;
    final v = review.rows.isEmpty ? null : review.rows.first;
    final l = log.rows.isEmpty ? null : log.rows.first;
    final changed = [
      r?.colByName('changed'),
      v?.colByName('changed'),
      l?.colByName('changed'),
    ].whereType<String>().toList()..sort();

    return TitleEntry(
      watchedOn: l?.colByName('watched_on'),
      stars: r == null ? null : double.parse(r.colByName('stars')!),
      review: v?.colByName('body'),
      spoiler: v != null && v.colByName('is_spoiler') == '1',
      moodIds: [
        for (final row in moods.rows) int.parse(row.colByName('mood_id')!),
      ],
      updatedAt: changed.isEmpty ? null : changed.last,
      reviewId: switch (v?.colByName('review_id')) {
        final String id => int.parse(id),
        _ => null,
      },
    );
  }

  /// Saves [entry] for [userId] on [titleId]: anything null or empty in it
  /// is removed (e.g. a null rating deletes the old rating). Mood ids must
  /// already be checked (active, at most 3)
  Future<void> save(int userId, int titleId, TitleEntry entry) {
    final p = {'user': userId, 'title': titleId};
    return _db.transactional((MySQLConnection conn) async {
      await conn.execute(_lockTitle, p);

      // Mood votes: remove the ones dropped, add the new ones
      final had = {
        for (final row in (await conn.execute(_moods, p)).rows)
          int.parse(row.colByName('mood_id')!),
      };
      final want = entry.moodIds.toSet();
      for (final mood in had.difference(want)) {
        await conn.execute(
          'DELETE FROM user_mood_tags '
          'WHERE user_id = :user AND title_id = :title AND mood_id = :mood',
          {...p, 'mood': mood},
        );
      }
      for (final mood in entry.moodIds.where((m) => !had.contains(m))) {
        await conn.execute(
          'INSERT INTO user_mood_tags (user_id, title_id, mood_id) '
          'VALUES (:user, :title, :mood)',
          {...p, 'mood': mood},
        );
      }
      if (had.length != want.length || !had.containsAll(want)) {
        await conn.execute('CALL refresh_title_moods(:title)', p);
      }

      // Rating
      final stars = entry.stars;
      if (stars == null) {
        await conn.execute(
          'DELETE FROM ratings WHERE user_id = :user AND title_id = :title',
          p,
        );
      } else {
        await conn.execute(_saveRating, {...p, 'stars': stars});
      }
      await conn.execute(_refreshRatings, p);

      // Review
      final review = entry.review;
      if (review == null) {
        await conn.execute(
          'DELETE FROM reviews WHERE user_id = :user AND title_id = :title',
          p,
        );
      } else {
        await conn.execute(_saveReview, {
          ...p,
          'body': review,
          'spoiler': entry.spoiler,
        });
      }

      // Watch date: one log per title, changed in place
      final watchedOn = entry.watchedOn;
      final log = await conn.execute(_log, p);
      if (watchedOn == null) {
        await conn.execute(
          'DELETE FROM watch_logs WHERE user_id = :user AND title_id = :title',
          p,
        );
      } else if (log.rows.isEmpty) {
        await conn.execute(
          'INSERT INTO watch_logs (user_id, title_id, watched_on) '
          'VALUES (:user, :title, :date)',
          {...p, 'date': watchedOn},
        );
      } else {
        await conn.execute(
          'UPDATE watch_logs SET watched_on = :date WHERE log_id = :log',
          {'date': watchedOn, 'log': log.rows.first.colByName('log_id')},
        );
      }
    });
  }

  /// Deletes [userId]'s date, rating, review and mood votes on [titleId]
  Future<void> delete(int userId, int titleId) =>
      save(userId, titleId, const TitleEntry());
}
