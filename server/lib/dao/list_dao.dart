import 'package:mysql_client/mysql_client.dart';
import 'package:server/models/title.dart';
import 'package:server/models/user_list.dart';

/// A user's own lists (RU-08): `watchlists` rows that aren't the default
/// Watchlist, and their entries in `watchlist_items`, kept in the order
/// they were added. Deleting the account deletes its lists (ON DELETE
/// CASCADE from user_accounts down to watchlist_items)
class ListDao {
  /// Creates a DAO on a connection pool (normally the shared `db`)
  ListDao(this._db);

  final MySQLConnectionPool _db;

  /// Most entries a list can be created with in one request
  static const maxEntries = 500;

  /// Posters shown on a list's card
  static const previewPosters = 4;

  // The first few posters of each list, in list order, joined by newlines
  // (a URL never contains one)
  static const _myLists =
      '''
SELECT w.watchlist_id, w.name, w.description,
        DATE_FORMAT(w.updated_at, '%Y-%m-%d %H:%i:%s') AS updated_at,
        COUNT(i.title_id) AS entry_count,
        SUBSTRING_INDEX(
          GROUP_CONCAT(t.poster_url ORDER BY i.position SEPARATOR '\\n'),
          '\\n', $previewPosters) AS posters
FROM watchlists w
LEFT JOIN watchlist_items i ON i.watchlist_id = w.watchlist_id
LEFT JOIN titles t ON t.title_id = i.title_id
WHERE w.user_id = :user AND NOT w.is_default
GROUP BY w.watchlist_id
ORDER BY w.updated_at DESC, w.watchlist_id DESC''';

  static const _oneList = '''
SELECT watchlist_id, name, description FROM watchlists
WHERE watchlist_id = :list AND user_id = :user AND NOT is_default''';

  static const _entries = '''
SELECT t.title_id, t.type, t.name, t.release_year, t.poster_url
FROM watchlist_items i JOIN titles t ON t.title_id = i.title_id
WHERE i.watchlist_id = :list
ORDER BY i.position''';

  static const _insertList = '''
INSERT INTO watchlists (user_id, name, description, visibility, is_default)
VALUES (:user, :name, :description, 'private', FALSE)''';

  static const _insertEntry = '''
INSERT INTO watchlist_items (watchlist_id, title_id, position)
VALUES (:list, :title, :position)''';

  // Locks the list row so two saves of the same list run one at a time
  static const _lockList = '''
SELECT watchlist_id FROM watchlists
WHERE watchlist_id = :list AND user_id = :user AND NOT is_default
FOR UPDATE''';

  // updated_at is set by hand so reordering alone still counts as a change
  static const _updateList = '''
UPDATE watchlists
SET name = :name, description = :description, updated_at = NOW()
WHERE watchlist_id = :list''';

  static const _clearEntries =
      'DELETE FROM watchlist_items WHERE watchlist_id = :list';

  static const _deleteList = '''
DELETE FROM watchlists
WHERE watchlist_id = :list AND user_id = :user AND NOT is_default''';

  /// The user's lists, most recently changed first
  Future<List<UserListSummary>> myLists(int userId) async {
    final res = await _db.execute(_myLists, {'user': userId});
    return res.rows.map(UserListSummary.fromRow).toList();
  }

  /// One of the user's lists with its entries, or null if it doesn't
  /// exist or belongs to someone else
  Future<UserListDetails?> find(int userId, int listId) async {
    final list = await _db.execute(_oneList, {'list': listId, 'user': userId});
    if (list.rows.isEmpty) return null;
    final row = list.rows.first;
    final entries = await _db.execute(_entries, {'list': listId});
    return UserListDetails(
      id: listId,
      name: row.colByName('name')!,
      description: row.colByName('description'),
      entries: entries.rows.map(TitleCard.fromRow).toList(),
    );
  }

  /// Ids from [titleIds] that aren't in the catalog
  Future<List<int>> missingTitles(List<int> titleIds) async {
    if (titleIds.isEmpty) return [];
    // Ids are already validated integers, so listing them inline is safe
    final res = await _db.execute(
      'SELECT title_id FROM titles WHERE title_id IN (${titleIds.join(',')})',
    );
    final found = {
      for (final r in res.rows) int.parse(r.colByName('title_id')!),
    };
    return [
      for (final id in titleIds)
        if (!found.contains(id)) id,
    ];
  }

  /// RU-08.01: creates a list with its entries in the given order, all or
  /// nothing. Returns the new list's id
  Future<int> create({
    required int userId,
    required String name,
    required String? description,
    required List<int> titleIds,
  }) {
    return _db.transactional((MySQLConnection conn) async {
      final res = await conn.execute(_insertList, {
        'user': userId,
        'name': name,
        'description': description,
      });
      final listId = res.lastInsertID.toInt();
      for (final (i, titleId) in titleIds.indexed) {
        await conn.execute(_insertEntry, {
          'list': listId,
          'title': titleId,
          'position': i + 1,
        });
      }
      return listId;
    });
  }

  /// Replaces a list's name, description and entries (in the
  /// given order), all or nothing. 
  /// Returns false if the list doesn't exist or isn't the user's
  Future<bool> update({
    required int userId,
    required int listId,
    required String name,
    required String? description,
    required List<int> titleIds,
  }) {
    return _db.transactional((MySQLConnection conn) async {
      final mine = await conn.execute(_lockList, {
        'list': listId,
        'user': userId,
      });
      if (mine.rows.isEmpty) return false;

      await conn.execute(_updateList, {
        'list': listId,
        'name': name,
        'description': description,
      });
      await conn.execute(_clearEntries, {'list': listId});
      for (final (i, titleId) in titleIds.indexed) {
        await conn.execute(_insertEntry, {
          'list': listId,
          'title': titleId,
          'position': i + 1,
        });
      }
      return true;
    });
  }

  /// Deletes one of the user's lists and its entries (ON DELETE
  /// CASCADE). Returns false if it doesn't exist or isn't the user's
  Future<bool> delete(int userId, int listId) async {
    final res = await _db.execute(_deleteList, {
      'list': listId,
      'user': userId,
    });
    return res.affectedRows.toInt() > 0;
  }
}
