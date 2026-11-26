import 'package:dart_frog/dart_frog.dart';
import 'package:server/auth/http_helpers.dart';
import 'package:server/dao/collection_dao.dart';
import 'package:server/entries/title_status.dart';

/// PUT    /me/titles/:id/watchlist   add this title to your Watchlist (at the end)
/// DELETE /me/titles/:id/watchlist   take it out
/// Both are safe to repeat. 200 your status (same as GET /me/titles/:id)
/// 401 not logged in - 403 admin - 404 no such title
Future<Response> onRequest(RequestContext context, String id) async {
  final method = context.request.method;
  if (method != HttpMethod.put && method != HttpMethod.delete) {
    return methodNotAllowed();
  }
  final (user, titleId, error) = await userAndTitle(context, id);
  if (error != null) return error;

  final collections = context.read<CollectionDao>();
  if (method == HttpMethod.put) {
    await collections.add(user!.userId, Collection.watchlist, titleId!);
  } else {
    await collections.remove(user!.userId, Collection.watchlist, titleId!);
  }
  return titleStatusResponse(context, user.userId, titleId);
}
