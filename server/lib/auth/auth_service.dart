import 'package:bcrypt/bcrypt.dart';
import 'package:mysql_client/mysql_client.dart' show MySQLConnectionPool;
import 'package:server/auth/validators.dart';
import 'package:server/dao/session_dao.dart';
import 'package:server/dao/user_dao.dart';

/// A failed auth request. Routes return [body] with [statusCode] as-is
class AuthException implements Exception {
  /// Creates an [AuthException].
  AuthException(this.statusCode, this.body);

  /// HTTP status to return.
  final int statusCode;

  /// JSON body to return. Always has an `error` key
  final Map<String, dynamic> body;

  @override
  String toString() => 'AuthException($statusCode, $body)';
}

/// What the app receives after signing up or logging in.
typedef AuthResult = ({String token, int userId, String role});

/// Sign-up, login, logout and session checks (GU-07, GU-08, RU-01).
/// Routes call this; this calls the DAOs.
class AuthService {
  /// Creates the service from its DAOs 
  AuthService(this._users, this._sessions);

  /// Creates the service on a real connection pool
  AuthService.withPool(MySQLConnectionPool db)
      : this(UserDao(db), SessionDao(db));

  final UserDao _users;
  final SessionDao _sessions;

  static const _wrongLogin = 'Incorrect username or password';

  // Used when the login doesn't exist, so the response takes as long as a
  // real password check and doesn't reveal which usernames exist
  late final String _dummyHash =
      BCrypt.hashpw('not-a-real-password-1', BCrypt.gensalt());

  /// GU-07: validates, creates the account, and logs the user in
  Future<AuthResult> register({
    required String email,
    required String username,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanUsername = username.trim();

    final invalid = validateRegistration(
      email: cleanEmail,
      username: cleanUsername,
      password: password,
    );
    if (invalid != null) {
      throw AuthException(400, {
        'error': 'invalid',
        'field': invalid.field,
        'message': invalid.message,
      });
    }

    final taken =
        await _users.takenField(email: cleanEmail, username: cleanUsername);
    if (taken != null) throw _takenError(taken);

    final hash = BCrypt.hashpw(password, BCrypt.gensalt());
    final int userId;
    try {
      userId = await _users.createRegisteredUser(
        email: cleanEmail,
        username: cleanUsername,
        passwordHash: hash,
      );
    } on Exception catch (e) {
      // Someone took the email/username between the check and the insert.
      // MySQL reports it as error naming the unique key
      final msg = e.toString();
      if (msg.contains('1062') && msg.contains('uq_user_email')) {
        throw _takenError('email');
      }
      if (msg.contains('1062') && msg.contains('uq_user_username')) {
        throw _takenError('username');
      }
      rethrow;
    }

    final token = await _sessions.create(userId);
    return (token: token, userId: userId, role: 'user');
  }

  /// GU-08.01-04: logs in with an email or username
  Future<AuthResult> login({
    required String login,
    required String password,
  }) async {
    final user = await _users.findByLogin(login.trim());
    if (user == null) {
      BCrypt.checkpw(password, _dummyHash);
      throw AuthException(401, {'error': 'incorrect', 'message': _wrongLogin});
    }

    if (user.isLocked) {
      throw AuthException(423, {
        'error': 'locked',
        'message': 'Too many failed attempts. Try again in 15 minutes.',
        'until': user.lockedUntil,
      });
    }

    if (!BCrypt.checkpw(password, user.passwordHash)) {
      await _users.recordFailedLogin(user.id);
      throw AuthException(401, {'error': 'incorrect', 'message': _wrongLogin});
    }

    // Status is checked only after a correct password, so the ban or
    // suspension reason is shown to the account owner, not to anyone who
    // types a username
    if (user.isBlocked) {
      throw AuthException(403, {
        'error': user.status, // 'suspended' or 'banned'
        'reason': user.statusReason,
        'until': user.statusUntil,
      });
    }
    if (user.statusExpired) await _users.endExpiredSuspension(user.id);

    await _users.resetFailedLogins(user.id);
    final token = await _sessions.create(user.id);
    return (token: token, userId: user.id, role: user.role);
  }

  /// RU-01.02: the user behind a token, or null if it's expired/invalid
  Future<SessionUser?> checkSession(String token) => _sessions.validate(token);

  /// RU-01.03: logs this session out
  Future<void> logout(String token) => _sessions.revoke(token);

  AuthException _takenError(String field) => AuthException(409, {
        'error': 'taken',
        'field': field,
        'message': 'That $field is already in use.',
      });
}