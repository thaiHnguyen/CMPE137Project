import 'package:mysql_client/mysql_client.dart';
import 'package:server/models/user.dart';

/// Reads and writes accounts: `user_accounts`, `registered_users`, and the
/// default watchlist every new user gets
class UserDao {
  /// Creates a DAO on a connection pool (normally the shared `db`)
  UserDao(this._db);

  final MySQLConnectionPool _db;

  static const _select = '''
SELECT user_id, email, username, password_hash, role, status,
        status_reason, status_until, locked_until, display_name, avatar_url,
        (locked_until IS NOT NULL AND locked_until > NOW()) AS is_locked,
        (status_until IS NOT NULL AND status_until <= NOW()) AS status_expired
FROM user_accounts''';

  /// Finds an account by email OR username (GU-08.01). Case-insensitiv
  Future<User?> findByLogin(String login) async {
    final res = await _db.execute(
      '$_select WHERE email = :login OR username = :login LIMIT 1',
      {'login': login},
    );
    return res.rows.isEmpty ? null : User.fromRow(res.rows.first);
  }

  /// Finds an account by id.
  Future<User?> findById(int id) async {
    final res =
        await _db.execute('$_select WHERE user_id = :id', {'id': id});
    return res.rows.isEmpty ? null : User.fromRow(res.rows.first);
  }

  /// GU-07.03: returns `'email'` or `'username'` if already taken,
  /// or null if both are free
  Future<String?> takenField({
    required String email,
    required String username,
  }) async {
    final res = await _db.execute(
      'SELECT '
      '(SELECT COUNT(*) FROM user_accounts WHERE email = :email) AS e, '
      '(SELECT COUNT(*) FROM user_accounts WHERE username = :username) AS u',
      {'email': email, 'username': username},
    );
    final row = res.rows.first;
    if (row.colByName('e') != '0') return 'email';
    if (row.colByName('u') != '0') return 'username';
    return null;
  }

  /// GU-07.04: creates a Registered User and their private default
  /// "Watchlist" in one transaction. Returns the new user id
  Future<int> createRegisteredUser({
    required String email,
    required String username,
    required String passwordHash,
  }) async {
    var userId = 0;
    await _db.transactional((MySQLConnection conn) async {
      final res = await conn.execute(
        'INSERT INTO user_accounts (email, username, password_hash, role) '
        "VALUES (:email, :username, :hash, 'user')",
        {'email': email, 'username': username, 'hash': passwordHash},
      );
      userId = res.lastInsertID.toInt();
      await conn.execute(
        'INSERT INTO registered_users (user_id) VALUES (:id)',
        {'id': userId},
      );
      await conn.execute(
        'INSERT INTO watchlists (user_id, name, visibility, is_default) '
        "VALUES (:id, 'Watchlist', 'private', TRUE)",
        {'id': userId},
      );
    });
    return userId;
  }

  /// GU-08.03: counts a failed login. The 5th failure locks the account
  /// for 15 minutes and resets the counter
  Future<void> recordFailedLogin(int userId) async {
    // Both expressions read the OLD failed_logins value, so the result
    // doesn't depend on MySQL's assignment order
    await _db.execute(
      'UPDATE user_accounts SET '
      'locked_until = IF(failed_logins + 1 >= 5, '
      'NOW() + INTERVAL 15 MINUTE, locked_until), '
      'failed_logins = IF(failed_logins + 1 >= 5, 0, failed_logins + 1) '
      'WHERE user_id = :id',
      {'id': userId},
    );
  }

  /// GU-08.04: clears failed attempts after a successful login
  Future<void> resetFailedLogins(int userId) async {
    await _db.execute(
      'UPDATE user_accounts SET failed_logins = 0, locked_until = NULL '
      'WHERE user_id = :id',
      {'id': userId},
    );
  }

  /// Turns a suspension whose end date has passed back into `active`
  Future<void> endExpiredSuspension(int userId) async {
    await _db.execute(
      "UPDATE user_accounts SET status = 'active', status_reason = NULL, "
      'status_until = NULL '
      "WHERE user_id = :id AND status = 'suspended' "
      'AND status_until IS NOT NULL AND status_until <= NOW()',
      {'id': userId},
    );
  }
}
