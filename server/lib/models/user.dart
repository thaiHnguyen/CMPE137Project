import 'package:mysql_client/mysql_client.dart';

/// One account from `user_accounts`, plus two flags computed by the
/// database clock (so the server and MySQL never disagree on time zones)
///
/// Holds the password hash, so never return it to the app directly:
/// use [toJson], which leaves the hash out
class User {
  /// Builds a [User] from a row selected with `UserDao`'s column list
  User.fromRow(ResultSetRow row)
      : id = int.parse(row.colByName('user_id')!),
        email = row.colByName('email')!,
        username = row.colByName('username')!,
        passwordHash = row.colByName('password_hash')!,
        role = row.colByName('role')!,
        status = row.colByName('status')!,
        statusReason = row.colByName('status_reason'),
        statusUntil = row.colByName('status_until'),
        lockedUntil = row.colByName('locked_until'),
        isLocked = row.colByName('is_locked') == '1',
        statusExpired = row.colByName('status_expired') == '1',
        displayName = row.colByName('display_name'),
        avatarUrl = row.colByName('avatar_url');

  /// `user_accounts.user_id`.
  final int id;

  /// Login email
  final String email;

  /// Public username
  final String username;

  /// bcrypt hash (salt included)
  final String passwordHash;

  /// `user` or `admin`
  final String role;

  /// `active`, `suspended` or `banned`
  final String status;

  /// Why the account was suspended or banned
  final String? statusReason;

  /// When a suspension ends (`YYYY-MM-DD HH:MM:SS`), or null
  final String? statusUntil;

  /// End of a failed-login lockout, or null
  final String? lockedUntil;

  /// True while a lockout is still running (GU-08.02)
  final bool isLocked;

  /// True when a suspension's end date has passed
  final bool statusExpired;

  /// Optional display name
  final String? displayName;

  /// Optional avatar URL
  final String? avatarUrl;

  /// True if a suspension or ban currently blocks this account
  bool get isBlocked => status != 'active' && !statusExpired;

  /// Safe public fields only (no email, no hash)
  Map<String, dynamic> toJson() => {
        'userId': id,
        'username': username,
        'role': role,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
      };
}
