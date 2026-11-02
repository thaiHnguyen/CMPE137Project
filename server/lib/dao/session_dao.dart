import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:mysql_client/mysql_client.dart';

/// The logged-in user behind a valid session token
class SessionUser {
  /// Creates a [SessionUser]
  const SessionUser({
    required this.sessionId,
    required this.userId,
    required this.username,
    required this.role,
  });

  /// `sessions.session_id`
  final int sessionId;

  /// `user_accounts.user_id`
  final int userId;

  /// Username
  final String username;

  /// `user` or `admin`
  final String role;
}

/// Login sessions (GU-07.05, GU-08.04, RU-01)
/// The app keeps the raw token; the database only stores its SHA-256 hash,
/// so a leaked database can't be used to log in
class SessionDao {
  /// Creates a DAO on a connection pool (normally the shared `db`)
  SessionDao(this._db);

  final MySQLConnectionPool _db;
  static final _random = Random.secure();

  /// Sessions expire after this many days without use (RU-01.02)
  static const idleDays = 30;

  /// SHA-256 hex of a token, as stored in `sessions.token_hash`
  static String hashToken(String token) =>
      sha256.convert(utf8.encode(token)).toString();

  /// Starts a session and returns the raw token to give to the app
  Future<String> create(int userId) async {
    final token = base64UrlEncode(
      List<int>.generate(32, (_) => _random.nextInt(256)),
    );
    await _db.execute(
      'INSERT INTO sessions (user_id, token_hash) VALUES (:u, :h)',
      {'u': userId, 'h': hashToken(token)},
    );
    return token;
  }

  /// RU-01.02: returns the user if the token is valid, else null
  /// (unknown, logged out, idle 30+ days, or account suspended/banned)
  /// A valid check counts as activity and pushes the expiry forward
  Future<SessionUser?> validate(String token) async {
    final res = await _db.execute(
      'SELECT s.session_id, u.user_id, u.username, u.role '
      'FROM sessions s JOIN user_accounts u ON u.user_id = s.user_id '
      'WHERE s.token_hash = :h AND s.revoked_at IS NULL '
      'AND s.last_active_at > NOW() - INTERVAL $idleDays DAY '
      "AND (u.status = 'active' OR "
      '(u.status_until IS NOT NULL AND u.status_until <= NOW()))',
      {'h': hashToken(token)},
    );
    if (res.rows.isEmpty) return null;
    final row = res.rows.first;
    final session = SessionUser(
      sessionId: int.parse(row.colByName('session_id')!),
      userId: int.parse(row.colByName('user_id')!),
      username: row.colByName('username')!,
      role: row.colByName('role')!,
    );
    await _db.execute(
      'UPDATE sessions SET last_active_at = NOW() WHERE session_id = :id',
      {'id': session.sessionId},
    );
    return session;
  }

  /// RU-01.03: logs one session out
  Future<void> revoke(String token) async {
    await _db.execute(
      'UPDATE sessions SET revoked_at = NOW() '
      'WHERE token_hash = :h AND revoked_at IS NULL',
      {'h': hashToken(token)},
    );
  }

  /// RU-13.02 (password change): logs out every session of a user except
  /// [keepSessionId].
  Future<void> revokeAllForUser(int userId, {int? keepSessionId}) async {
    await _db.execute(
      'UPDATE sessions SET revoked_at = NOW() '
      'WHERE user_id = :u AND revoked_at IS NULL AND session_id <> :keep',
      {'u': userId, 'keep': keepSessionId ?? 0},
    );
  }
}
