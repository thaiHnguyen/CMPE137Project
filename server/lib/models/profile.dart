import 'package:mysql_client/mysql_client.dart';
import 'package:server/models/title.dart';

/// The logged-in user's own profile: what the Profile tab shows and what
/// Profile Settings can change. Includes the email, so only send it to its
/// owner
class Profile {
  /// Builds a [Profile] from a `ProfileDao` account row and the user's
  /// Greatest Of All Time list
  Profile.fromRow(ResultSetRow row, {required this.goat})
      : id = int.parse(row.colByName('user_id')!),
        username = row.colByName('username')!,
        email = row.colByName('email')!,
        role = row.colByName('role')!,
        displayName = row.colByName('display_name'),
        bio = row.colByName('bio'),
        pronoun = row.colByName('pronoun'),
        avatarUrl = row.colByName('avatar_url');

  /// `user_accounts.user_id`
  final int id;
  /// Public username (can't be changed)
  final String username;
  /// Login email
  final String email;
  /// `user` or `admin`
  final String role;
  /// Name shown on the profile, or null to show the username
  final String? displayName;
  /// Short bio, up to 160 characters
  final String? bio;
  /// One of `ProfileDao.pronouns`, or null
  final String? pronoun;
  /// Server path of the avatar image (e.g. `/avatars/7-1764123.jpg`), or
  /// null for the default picture
  final String? avatarUrl;
  /// Greatest Of All Time: always 5 slots, left to right; null is empty
  final List<TitleCard?> goat;

  /// JSON sent to the app
  Map<String, dynamic> toJson() => {
    'userId': id,
    'username': username,
    'email': email,
    'role': role,
    'displayName': displayName,
    'bio': bio,
    'pronoun': pronoun,
    'avatarUrl': avatarUrl,
    'goat': [for (final t in goat) t?.toJson()],
  };
}
