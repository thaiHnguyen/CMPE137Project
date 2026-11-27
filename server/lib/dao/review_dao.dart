import 'package:mysql_client/mysql_client.dart';
import 'package:server/browse/paging.dart';
import 'package:server/models/review.dart';
import 'package:server/models/title.dart';

/// How to order a title's reviews
enum ReviewSort {
  /// Most liked first, then most commented, then newest
  popular,

  /// Newest first
  recent,
}

/// Reading reviews (GU-04), and their likes and comments (RU-06). Writing
/// a review is `EntryDao`'s job; deleting one there also deletes its
/// likes and comments (ON DELETE CASCADE)
class ReviewDao {
  /// Creates a DAO on a connection pool (normally the shared `db`)
  ReviewDao(this._db);

  final MySQLConnectionPool _db;

  /// Longest comment (`review_comments.body` is VARCHAR(2000))
  static const maxComment = 2000;

  /// Most comments returned with a review
  static const maxComments = 500;

  // Everything a review card or page shows. :viewer is 0 for a guest
  static const _select = '''
SELECT r.review_id, r.body, r.is_spoiler, r.is_edited,
        UNIX_TIMESTAMP(r.created_at) AS created_unix,
        u.user_id, u.username, u.display_name, u.avatar_url,
        t.title_id, t.type, t.name, t.release_year, t.poster_url,
        rt.stars,
        (SELECT DATE_FORMAT(MAX(l.watched_on), '%Y-%m-%d') FROM watch_logs l
          WHERE l.user_id = r.user_id AND l.title_id = r.title_id) AS watched_on,
        EXISTS (SELECT 1 FROM watchlist_items i
                JOIN watchlists w ON w.watchlist_id = i.watchlist_id
                WHERE w.user_id = r.user_id AND w.kind = 'favorites'
                  AND i.title_id = r.title_id) AS favorite,
        (SELECT COUNT(*) FROM review_likes rl
          WHERE rl.review_id = r.review_id) AS like_count,
        (SELECT COUNT(*) FROM review_comments c
          WHERE c.review_id = r.review_id AND c.status = 'visible')
          AS comment_count,
        EXISTS (SELECT 1 FROM review_likes rl
                WHERE rl.review_id = r.review_id AND rl.user_id = :viewer)
          AS liked_by_me
FROM reviews r
JOIN user_accounts u ON u.user_id = r.user_id
JOIN titles t ON t.title_id = r.title_id
LEFT JOIN ratings rt ON rt.user_id = r.user_id AND rt.title_id = r.title_id''';

  static const _comments = '''
SELECT c.comment_id, c.body, UNIX_TIMESTAMP(c.created_at) AS created_unix,
        u.user_id, u.username, u.display_name, u.avatar_url,
        (SELECT COUNT(*) FROM comment_likes cl
          WHERE cl.comment_id = c.comment_id) AS like_count,
        EXISTS (SELECT 1 FROM comment_likes cl
                WHERE cl.comment_id = c.comment_id AND cl.user_id = :viewer)
          AS liked_by_me
FROM review_comments c
JOIN user_accounts u ON u.user_id = c.user_id''';

  /// A title's visible reviews, one page. With [onlyUser], just that
  /// user's review (the "You" tab)
  Future<({List<Review> reviews, int total})> forTitle(
    int titleId,
    Paging paging, {
    int viewerId = 0,
    ReviewSort sort = ReviewSort.popular,
    int? onlyUser,
  }) async {
    final where = StringBuffer(
      "WHERE r.title_id = :title AND r.status = 'visible'",
    );
    if (onlyUser != null) where.write(' AND r.user_id = :only');
    final order = sort == ReviewSort.popular
        ? 'ORDER BY like_count DESC, comment_count DESC, r.created_at DESC, '
              'r.review_id DESC'
        : 'ORDER BY r.created_at DESC, r.review_id DESC';
    final params = {
      'title': titleId,
      'viewer': viewerId,
      'only': ?onlyUser,
      'limit': paging.limit,
      'offset': paging.offset,
    };

    final count = await _db.execute(
      'SELECT COUNT(*) AS total FROM reviews r $where',
      params,
    );
    final rows = await _db.execute(
      '$_select $where $order LIMIT :limit OFFSET :offset',
      params,
    );
    return (
      reviews: [
        for (final row in rows.rows) Review.fromRow(row, viewerId: viewerId),
      ],
      total: int.parse(count.rows.first.colByName('total')!),
    );
  }

  /// One review, or null if it doesn't exist or is hidden (its author can
  /// still see a hidden one)
  Future<Review?> find(int reviewId, {int viewerId = 0}) async {
    final res = await _db.execute(
      '$_select WHERE r.review_id = :id '
      "AND (r.status = 'visible' OR r.user_id = :viewer)",
      {'id': reviewId, 'viewer': viewerId},
    );
    if (res.rows.isEmpty) return null;
    return Review.fromRow(res.rows.first, viewerId: viewerId);
  }

  /// A review's visible comments, oldest first (up to [maxComments])
  Future<List<ReviewComment>> comments(
    int reviewId, {
    int viewerId = 0,
  }) async {
    final res = await _db.execute(
      "$_comments WHERE c.review_id = :id AND c.status = 'visible' "
      'ORDER BY c.created_at, c.comment_id LIMIT $maxComments',
      {'id': reviewId, 'viewer': viewerId},
    );
    return [
      for (final row in res.rows)
        ReviewComment.fromRow(row, viewerId: viewerId),
    ];
  }

  /// One comment as [viewerId] sees it, or null
  Future<ReviewComment?> findComment(int commentId, {int viewerId = 0}) async {
    final res = await _db.execute(
      "$_comments WHERE c.comment_id = :id AND c.status = 'visible'",
      {'id': commentId, 'viewer': viewerId},
    );
    if (res.rows.isEmpty) return null;
    return ReviewComment.fromRow(res.rows.first, viewerId: viewerId);
  }

  /// Who wrote a review, or null if there's no such (visible) review
  Future<int?> reviewAuthor(int reviewId) async {
    final res = await _db.execute(
      'SELECT user_id FROM reviews '
      "WHERE review_id = :id AND status = 'visible'",
      {'id': reviewId},
    );
    return res.rows.isEmpty
        ? null
        : int.parse(res.rows.first.colByName('user_id')!);
  }

  /// Who wrote a comment, or null if there's no such (visible) comment
  Future<int?> commentAuthor(int commentId) async {
    final res = await _db.execute(
      'SELECT user_id FROM review_comments '
      "WHERE comment_id = :id AND status = 'visible'",
      {'id': commentId},
    );
    return res.rows.isEmpty
        ? null
        : int.parse(res.rows.first.colByName('user_id')!);
  }

  /// Likes or unlikes a review. Safe to repeat
  Future<void> setReviewLike(int reviewId, int userId, {required bool like}) =>
      _db.execute(
        like
            ? 'INSERT IGNORE INTO review_likes (review_id, user_id) '
                  'VALUES (:id, :user)'
            : 'DELETE FROM review_likes '
                  'WHERE review_id = :id AND user_id = :user',
        {'id': reviewId, 'user': userId},
      );

  /// Likes or unlikes a comment. Safe to repeat
  Future<void> setCommentLike(
    int commentId,
    int userId, {
    required bool like,
  }) => _db.execute(
    like
        ? 'INSERT IGNORE INTO comment_likes (comment_id, user_id) '
              'VALUES (:id, :user)'
        : 'DELETE FROM comment_likes '
              'WHERE comment_id = :id AND user_id = :user',
    {'id': commentId, 'user': userId},
  );

  /// Adds a comment and returns its id
  Future<int> addComment(int reviewId, int userId, String body) async {
    final res = await _db.execute(
      'INSERT INTO review_comments (review_id, user_id, body) '
      'VALUES (:review, :user, :body)',
      {'review': reviewId, 'user': userId, 'body': body},
    );
    return res.lastInsertID.toInt();
  }

  /// Deletes a comment and its likes
  Future<void> deleteComment(int commentId) => _db.execute(
    'DELETE FROM review_comments WHERE comment_id = :id',
    {'id': commentId},
  );

  /// Titles that feel like [titleId]: they share its main mood, or at
  /// least 3 of its mood tags. Most alike first: same main mood, then
  /// more shared tags, then a stronger fit on those moods
  Future<({List<TitleCard> titles, int total})> similar(
    int titleId,
    Paging paging,
  ) async {
    final p = {
      'id': titleId,
      'limit': paging.limit,
      'offset': paging.offset,
    };
    final count = await _db.execute(
      'SELECT COUNT(*) AS total FROM ($_similarScores) s',
      p,
    );
    final rows = await _db.execute('''
SELECT t.title_id, t.type, t.name, t.release_year, t.poster_url
FROM ($_similarScores) s JOIN titles t ON t.title_id = s.title_id
ORDER BY s.same_primary DESC, s.shared DESC, s.fit DESC,
          t.tmdb_vote_avg DESC, t.title_id
LIMIT :limit OFFSET :offset''', p);
    return (
      titles: rows.rows.map(TitleCard.fromRow).toList(),
      total: int.parse(count.rows.first.colByName('total')!),
    );
  }

  // Each other title's overlap with this one's top 5 mood tags
  static const _similarScores = '''
SELECT them.title_id,
        COUNT(*) AS shared,
        MAX(me.tag_rank = 1 AND them.tag_rank = 1) AS same_primary,
        SUM(them.mood_score) AS fit
FROM title_mood_tags me
JOIN title_mood_tags them
  ON them.mood_id = me.mood_id AND them.title_id <> me.title_id
WHERE me.title_id = :id AND me.tag_rank <= 5 AND them.tag_rank <= 5
GROUP BY them.title_id
HAVING same_primary = 1 OR shared >= 3''';
}
