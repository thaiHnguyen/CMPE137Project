import 'package:dart_frog/dart_frog.dart';
import 'package:server/auth/current_user.dart';
import 'package:server/auth/http_helpers.dart';
import 'package:server/browse/paging.dart';
import 'package:server/dao/profile_dao.dart';
import 'package:server/profile/profile_request.dart';

/// GET /me/profile   your profile: name, bio, pronoun, avatar, email and
///                   Greatest Of All Time
///     200 {profile: {userId, username, email, role, displayName, bio,
///                    pronoun, avatarUrl, goat: [5 x title or null]}}
/// PUT /me/profile   {displayName?, bio?, pronoun?, email}
///     Saves Profile Settings. A blank name or bio clears it
///     200 {profile}   400 {error: "invalid", field, message}
///     409 {error: "taken", field: "email", message}
/// Both need `Authorization: Bearer <token>` (401 if not logged in)
Future<Response> onRequest(RequestContext context) async {
  final method = context.request.method;
  if (method != HttpMethod.get && method != HttpMethod.put) {
    return methodNotAllowed();
  }

  final user = await currentUser(context);
  if (user == null) return notLoggedIn();
  final profiles = context.read<ProfileDao>();

  if (method == HttpMethod.put) {
    final body = await readJsonObject(context.request);
    if (body == null) return badJson();
    final (edit, problem) = parseProfileEdit(body);
    if (problem != null) {
      return Response.json(
        statusCode: 400,
        body: {
          'error': 'invalid',
          'field': problem.field,
          'message': problem.message,
        },
      );
    }

    final taken =
        await profiles.emailTaken(edit!.email, exceptUserId: user.userId) ||
        !await profiles.update(
          userId: user.userId,
          displayName: edit.displayName,
          bio: edit.bio,
          pronoun: edit.pronoun,
          email: edit.email,
        );
    if (taken) {
      return Response.json(
        statusCode: 409,
        body: {
          'error': 'taken',
          'field': 'email',
          'message': 'That email is already used by another account.',
        },
      );
    }
  }

  final profile = await profiles.find(user.userId);
  if (profile == null) return notFound('Profile');
  return Response.json(body: {'profile': profile.toJson()});
}
