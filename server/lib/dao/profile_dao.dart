import 'package:mysql_client/exception.dart';
import 'package:mysql_client/mysql_client.dart';
import 'package:server/models/profile.dart';
import 'package:server/models/title.dart';

/// Reads and writes the logged-in user's profile: name, bio, pronoun,
/// email and avatar in `user_accounts`, and their Greatest Of All Time in
/// `goat_picks`
class ProfileDao {
  /// Creates a DAO on a connection pool (normally the shared `db`)
  ProfileDao(this._db);

  final MySQLConnectionPool _db;

  /// How many Greatest Of All Time slots a profile has
  static const goatSlots = 5;

  /// Pronouns a profile can show (stored as-is; the app formats them)
  static const pronouns = {
    'he/him',
    'she/her',
    'they/them',
    'he/they',
    'she/they',
    'xe/xem',
    'ze/hir',
    'it/its',
  };

  static const _account = '''
SELECT user_id, username, email, role, display_name, bio, pronoun, avatar_url
FROM user_accounts WHERE user_id = :user''';

  static const _goat = '''
SELECT g.slot, t.title_id, t.type, t.name, t.release_year, t.poster_url
FROM goat_picks g JOIN titles t ON t.title_id = g.title_id
WHERE g.user_id = :user
ORDER BY g.slot''';

  static const _update = '''
UPDATE user_accounts
SET display_name = :name, bio = :bio, pronoun = :pronoun, email = :email
WHERE user_id = :user''';

  /// MySQL's "Duplicate entry" error, e.g. an email someone else has
  static const _duplicateKey = 1062;

  /// The user's profile, or null if the account is gone
  Future<Profile?> find(int userId) async {
    final res = await _db.execute(_account, {'user': userId});
    if (res.rows.isEmpty) return null;

    final goat = List<TitleCard?>.filled(goatSlots, null);
    final picks = await _db.execute(_goat, {'user': userId});
    for (final row in picks.rows) {
      final slot = int.parse(row.colByName('slot')!);
      goat[slot - 1] = TitleCard.fromRow(row);
    }
    return Profile.fromRow(res.rows.first, goat: goat);
  }

  /// True if another account already uses [email]
  Future<bool> emailTaken(String email, {required int exceptUserId}) async {
    final res = await _db.execute(
      'SELECT 1 FROM user_accounts '
      'WHERE email = :email AND user_id <> :user LIMIT 1',
      {'email': email, 'user': exceptUserId},
    );
    return res.rows.isNotEmpty;
  }

  /// Saves Profile Settings. Returns false if [email] was taken by someone
  /// else in the meantime
  Future<bool> update({
    required int userId,
    required String? displayName,
    required String? bio,
    required String? pronoun,
    required String email,
  }) async {
    try {
      await _db.execute(_update, {
        'user': userId,
        'name': displayName,
        'bio': bio,
        'pronoun': pronoun,
        'email': email,
      });
      return true;
    } on MySQLServerException catch (e) {
      if (e.errorCode == _duplicateKey) return false;
      rethrow;
    }
  }

  /// Replaces the Greatest Of All Time. [titleIds] has one entry per slot,
  /// left to right; null leaves that slot empty
  Future<void> setGoat(int userId, List<int?> titleIds) {
    return _db.transactional((MySQLConnection conn) async {
      await conn.execute(
        'DELETE FROM goat_picks WHERE user_id = :user',
        {'user': userId},
      );
      for (final (i, titleId) in titleIds.indexed) {
        if (titleId == null) continue;
        await conn.execute(
          'INSERT INTO goat_picks (user_id, slot, title_id) '
          'VALUES (:user, :slot, :title)',
          {'user': userId, 'slot': i + 1, 'title': titleId},
        );
      }
    });
  }

  /// Sets (or with null, clears) the avatar. Returns the previous one so
  /// its file can be deleted
  Future<String?> setAvatar(int userId, String? avatarUrl) {
    return _db.transactional((MySQLConnection conn) async {
      final old = await conn.execute(
        'SELECT avatar_url FROM user_accounts WHERE user_id = :user '
        'FOR UPDATE',
        {'user': userId},
      );
      await conn.execute(
        'UPDATE user_accounts SET avatar_url = :url WHERE user_id = :user',
        {'user': userId, 'url': avatarUrl},
      );
      return old.rows.isEmpty ? null : old.rows.first.colByName('avatar_url');
    });
  }
}
