import 'package:dart_frog/dart_frog.dart';
import 'package:server/auth/current_user.dart';
import 'package:server/auth/http_helpers.dart';
import 'package:server/browse/paging.dart';
import 'package:server/dao/list_dao.dart';

/// GET /me/lists/:id   one of your lists with all its entries, in the
/// order they were added
/// 200 {list: {listId, name, description, entryCount, entries}}
/// 401 not logged in - 404 no such list, or it isn't yours
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.get) return methodNotAllowed();

  final user = await currentUser(context);
  if (user == null) return notLoggedIn();

  final listId = parseId(id);
  final list = listId == null
      ? null
      : await context.read<ListDao>().find(user.userId, listId);
  if (list == null) return notFound('List');

  return Response.json(body: {'list': list.toJson()});
}
