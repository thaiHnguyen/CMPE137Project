import 'package:dart_frog/dart_frog.dart';
import 'package:server/auth/http_helpers.dart';
import 'package:server/entries/title_status.dart';

/// GET /me/titles/:id   your status on one title, for its ⋮ menu
///     200 {titleId, favorite, watchlist, logged,
///          entry: {watchedOn, stars, review, spoiler, moodIds, updatedAt}}
///     401 not logged in - 403 admin - 404 no such title
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.get) return methodNotAllowed();
  final (user, titleId, error) = await userAndTitle(context, id);
  if (error != null) return error;
  return titleStatusResponse(context, user!.userId, titleId!);
}
