import 'package:dart_frog/dart_frog.dart';
import 'package:server/auth/http_helpers.dart';
import 'package:server/dao/collection_dao.dart';
import 'package:server/lists/collection_route.dart';

/// GET /me/watchlist   your Watchlist, entries in order
///     200 {list: {listId, name, description, entryCount, entries}}
/// PUT /me/watchlist   {titleIds: [int]}  saves an edit: the entries in this
///     order (reordered, removed or added). 200 {list}
///     400 {error: "invalid", field: "titleIds", message}
/// Both: 401 not logged in - 403 admin
Future<Response> onRequest(RequestContext context) async {
  final method = context.request.method;
  if (method != HttpMethod.get && method != HttpMethod.put) {
    return methodNotAllowed();
  }
  return collectionRoute(context, Collection.watchlist);
}
