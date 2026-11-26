import 'package:mysql_client/mysql_client.dart';
import 'package:server/dao/list_dao.dart';
import 'package:server/models/title.dart';
import 'package:server/models/user_list.dart';

/// The two built-in lists every user has
enum Collection {
  /// Titles the user marked with the heart
  favorites('favorites', 'Favorites'),
  /// Titles the user wants to watch
  watchlist('watchlist', 'Watchlist');

  const Collection(this.kind, this.label);
  
  /// `watchlists.kind`, and the URL word (`/me/favorites`)
  final String kind;
  /// Name shown in the app
  final String label;
}

/// Favorites and Watchlist: `watchlists` rows of kind `favorites` and
/// `watchlist`, one each per user, made the first time they're needed
/// Entries work like a user's own lists: kept in order, reorderable
class CollectionDao {
  /// Creates a DAO on a connection pool (normally the shared `db`)
  CollectionDao(this._db);

  final MySQLConnectionPool _db;

  // INSERT IGNORE: the unique key (user_id, special_kind) makes a second
  // one impossible, even if two requests race to make it
  static const _create = '''
INSERT IGNORE INTO watchlists (user_id, name, visibility, is_default, kind)
VALUES (:user, :name, 'private', :isDefault, :kind)''';

  static const _find = '''
SELECT watchlist_id FROM watchlists WHERE user_id = :user AND kind = :kind''';

  static const _lock = '''
SELECT watchlist_id FROM watchlists
WHERE user_id = :user AND kind = :kind FOR UPDATE''';

  static const _has = '''
SELECT 1 FROM watchlist_items i
JOIN watchlists w ON w.watchlist_id = i.watchlist_id
WHERE w.user_id = :user AND w.kind = :kind AND i.title_id = :title''';

  static const _nextPosition = '''
SELECT COALESCE(MAX(position), 0) + 1 AS next
FROM watchlist_items WHERE watchlist_id = :list''';

  static const _add = '''
INSERT IGNORE INTO watchlist_items (watchlist_id, title_id, position)
VALUES (:list, :title, :position)''';

  static const _remove = '''
DELETE FROM watchlist_items WHERE watchlist_id = :list AND title_id = :title''';

  static const _touch =
      'UPDATE watchlists SET updated_at = NOW() WHERE watchlist_id = :list';

  /// The id of [userId]'s collection [c], making it first if needed
  Future<int> _ensure(MySQLConnection conn, int userId, Collection c) async {
    final params = {'user': userId, 'kind': c.kind};
    var res = await conn.execute(_lock, params);
    if (res.rows.isEmpty) {
      await conn.execute(_create, {
        ...params,
        'name': c.label,
        'isDefault': c == Collection.watchlist,
      });
      res = await conn.execute(_lock, params);
    }
    return int.parse(res.rows.first.colByName('watchlist_id')!);
  }

  /// The collection with its entries in order (empty if never used)
  Future<UserListDetails> get(int userId, Collection c) async {
    final found = await _db.execute(_find, {'user': userId, 'kind': c.kind});
    if (found.rows.isEmpty) {
      return UserListDetails(id: 0, name: c.label, description: null,
          entries: const []);
    }
    final id = int.parse(found.rows.first.colByName('watchlist_id')!);
    final entries = await _db.execute(ListDao.entriesQuery, {'list': id});
    return UserListDetails(
      id: id,
      name: c.label,
      description: null,
      entries: entries.rows.map(TitleCard.fromRow).toList(),
    );
  }

  /// True if [titleId] is in [userId]'s [c]
  Future<bool> contains(int userId, Collection c, int titleId) async {
    final res = await _db.execute(_has, {
      'user': userId,
      'kind': c.kind,
      'title': titleId,
    });
    return res.rows.isNotEmpty;
  }

  /// Adds [titleId] at the end, or does nothing if it's already there
  Future<void> add(int userId, Collection c, int titleId) {
    return _db.transactional((MySQLConnection conn) async {
      final list = await _ensure(conn, userId, c);
      final next = await conn.execute(_nextPosition, {'list': list});
      await conn.execute(_add, {
        'list': list,
        'title': titleId,
        'position': int.parse(next.rows.first.colByName('next')!),
      });
      await conn.execute(_touch, {'list': list});
    });
  }

  /// Takes [titleId] out, or does nothing if it isn't there
  Future<void> remove(int userId, Collection c, int titleId) {
    return _db.transactional((MySQLConnection conn) async {
      final list = await _ensure(conn, userId, c);
      await conn.execute(_remove, {'list': list, 'title': titleId});
      await conn.execute(_touch, {'list': list});
    });
  }

  /// Replaces the entries with [titleIds], in that order (the Edit screen)
  Future<void> replace(int userId, Collection c, List<int> titleIds) {
    return _db.transactional((MySQLConnection conn) async {
      final list = await _ensure(conn, userId, c);
      await conn.execute(
        'DELETE FROM watchlist_items WHERE watchlist_id = :list',
        {'list': list},
      );
      for (final (i, titleId) in titleIds.indexed) {
        await conn.execute(_add, {
          'list': list,
          'title': titleId,
          'position': i + 1,
        });
      }
      await conn.execute(_touch, {'list': list});
    });
  }
}
