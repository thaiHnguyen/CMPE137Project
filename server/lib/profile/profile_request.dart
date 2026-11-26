import 'package:server/auth/validators.dart';
import 'package:server/dao/profile_dao.dart';

/// A checked Profile Settings save: trimmed, with blanks turned into null
typedef ProfileEdit = ({
  String? displayName,
  String? bio,
  String? pronoun,
  String email,
});

/// Longest display name, matching `user_accounts.display_name`
const maxDisplayName = 50;
/// Longest bio, matching `user_accounts.bio`
const maxBio = 160;

/// Checks a `PUT /me/profile` body: `{displayName?, bio?, pronoun?,
/// email}`. Returns the edit, or the first problem
(ProfileEdit?, FieldError?) parseProfileEdit(Map<String, dynamic> body) {
  final name = body['displayName'];
  final bio = body['bio'];
  final pronoun = body['pronoun'];
  final email = body['email'];

  if (name != null && name is! String) {
    return (null, (field: 'displayName', message: 'Name must be text.'));
  }
  final cleanName = _blankToNull(name as String?);
  if (cleanName != null && cleanName.length > maxDisplayName) {
    const message = 'Use at most $maxDisplayName characters.';
    return (null, (field: 'displayName', message: message));
  }

  if (bio != null && bio is! String) {
    return (null, (field: 'bio', message: 'Bio must be text.'));
  }
  final cleanBio = _blankToNull(bio as String?);
  if (cleanBio != null && cleanBio.length > maxBio) {
    return (null, (field: 'bio', message: 'Use at most $maxBio characters.'));
  }

  if (pronoun != null &&
      (pronoun is! String || !ProfileDao.pronouns.contains(pronoun))) {
    return (null, (field: 'pronoun', message: 'Pick a pronoun from the list.'));
  }

  if (email is! String) {
    return (null, (field: 'email', message: 'Enter a valid email address.'));
  }
  final cleanEmail = email.trim().toLowerCase();
  final badEmail = validateEmail(cleanEmail);
  if (badEmail != null) return (null, badEmail);

  return (
    (
      displayName: cleanName,
      bio: cleanBio,
      pronoun: pronoun as String?,
      email: cleanEmail,
    ),
    null,
  );
}

/// Checks a `PUT /me/profile/goat` body: `{titleIds: [5 entries]}`, each a
/// title id or null for an empty slot, with no title twice. Returns the
/// slots, or a message
(List<int?>?, String?) parseGoat(Map<String, dynamic> body) {
  final ids = body['titleIds'];
  const slots = ProfileDao.goatSlots;
  if (ids is! List || ids.length != slots) {
    return (null, 'Send exactly $slots slots (use null for an empty one).');
  }
  final seen = <int>{};
  final out = <int?>[];
  for (final id in ids) {
    if (id == null) {
      out.add(null);
    } else if (id is int && id > 0) {
      if (!seen.add(id)) return (null, 'A title can only fill one slot.');
      out.add(id);
    } else {
      return (null, 'Each slot must be a title id or null.');
    }
  }
  return (out, null);
}

String? _blankToNull(String? text) {
  final trimmed = text?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
