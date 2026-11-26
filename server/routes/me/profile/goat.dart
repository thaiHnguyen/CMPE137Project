import 'package:dart_frog/dart_frog.dart';
import 'package:server/auth/current_user.dart';
import 'package:server/auth/http_helpers.dart';
import 'package:server/browse/paging.dart';
import 'package:server/dao/list_dao.dart';
import 'package:server/dao/profile_dao.dart';
import 'package:server/profile/profile_request.dart';

/// PUT /me/profile/goat   {titleIds: [5 entries, a title id or null]}
/// Replaces your Greatest Of All Time, slots left to right
///     200 {profile}   400 {error: "invalid", message}
///     401 not logged in
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.put) return methodNotAllowed();

  final user = await currentUser(context);
  if (user == null) return notLoggedIn();

  final body = await readJsonObject(context.request);
  if (body == null) return badJson();
  final (slots, problem) = parseGoat(body);
  if (problem != null) return _invalid(problem);

  final missing = await context.read<ListDao>().missingTitles([
    for (final id in slots!)
      if (id != null) id,
  ]);
  if (missing.isNotEmpty) {
    return _invalid('Unknown title ids: ${missing.join(', ')}.');
  }

  final profiles = context.read<ProfileDao>();
  await profiles.setGoat(user.userId, slots);
  final profile = await profiles.find(user.userId);
  if (profile == null) return notFound('Profile');
  return Response.json(body: {'profile': profile.toJson()});
}

Response _invalid(String message) => Response.json(
  statusCode: 400,
  body: {'error': 'invalid', 'field': 'titleIds', 'message': message},
);
