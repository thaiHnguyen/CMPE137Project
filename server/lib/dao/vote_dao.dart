import 'package:mysql_client/mysql_client.dart';

/// What happened when a user tried to vote a mood
enum VoteResult {
  /// The vote was saved
  added,

  /// The user had already voted this mood on this title; nothing changed
  alreadyVoted,

  /// The user already has [VoteDao.maxPerTitle] moods on this title
  limitReached,
}

/// Mood votes (RU-11): `user_mood_tags`. Every change recounts the title's
/// votes with `refresh_title_moods`, so tags and vote bars stay current
class VoteDao {
  /// Creates a DAO on a connection pool (normally the shared `db`)
  VoteDao(this._db);

  final MySQLConnectionPool _db;

  /// Most moods one user can vote on one title
  static const maxPerTitle = 3;

  static const _myVotes = '''
SELECT mood_id FROM user_mood_tags
WHERE user_id = :user AND title_id = :title
ORDER BY created_at, mood_id''';

  // Locks the title's row until the transaction ends, so vote changes on
  // one title happen one at a time. Without it, two quick taps could both
  // get past the 3-mood limit, and two votes at once could deadlock in
  // refresh_title_moods (which reads every vote on the title)
  static const _lockTitle = '''
SELECT title_id FROM titles WHERE title_id = :title FOR UPDATE''';

  static const _insert = '''
INSERT INTO user_mood_tags (user_id, title_id, mood_id)
VALUES (:user, :title, :mood)''';

  static const _delete = '''
DELETE FROM user_mood_tags
WHERE user_id = :user AND title_id = :title AND mood_id = :mood''';

  static const _refresh = 'CALL refresh_title_moods(:title)';

  /// The moods [userId] voted on [titleId], oldest vote first
  /// (same-second votes in mood order)
  Future<List<int>> myVotes(int userId, int titleId) async {
    final res = await _db.execute(_myVotes, {'user': userId, 'title': titleId});
    return [for (final r in res.rows) int.parse(r.colByName('mood_id')!)];
  }

  /// RU-11.01: votes [moodId] on [titleId] for [userId]
  Future<VoteResult> add(int userId, int titleId, int moodId) {
    final params = {'user': userId, 'title': titleId, 'mood': moodId};
    return _db.transactional((MySQLConnection conn) async {
      await conn.execute(_lockTitle, params);
      final mine = await conn.execute(_myVotes, params);
      final moodIds = [
        for (final r in mine.rows) int.parse(r.colByName('mood_id')!),
      ];
      if (moodIds.contains(moodId)) return VoteResult.alreadyVoted;
      if (moodIds.length >= maxPerTitle) return VoteResult.limitReached;

      await conn.execute(_insert, params);
      await conn.execute(_refresh, params);
      return VoteResult.added;
    });
  }

  /// RU-11.02: removes [userId]'s vote for [moodId] on [titleId].
  /// Returns false if there was no such vote
  Future<bool> remove(int userId, int titleId, int moodId) {
    final params = {'user': userId, 'title': titleId, 'mood': moodId};
    return _db.transactional((MySQLConnection conn) async {
      await conn.execute(_lockTitle, params);
      final res = await conn.execute(_delete, params);
      if (res.affectedRows == BigInt.zero) return false;
      await conn.execute(_refresh, params);
      return true;
    });
  }
}
