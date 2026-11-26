import 'package:dart_frog/dart_frog.dart';
import 'package:server/auth/current_user.dart';
import 'package:server/auth/http_helpers.dart';
import 'package:server/browse/paging.dart';
import 'package:server/dao/list_dao.dart';
import 'package:server/lists/list_request.dart';

/// GET    /me/lists/:id   one of your lists with all its entries, in order
///        200 {list: {listId, name, description, entryCount, entries}}
/// PUT    /me/lists/:id   {name, description?, titleIds: [int]}
///        Saves an edit: replaces the name, description and entries (in
///        the order given, so this is also how entries are reordered)
///        200 {list: {...}}   400 {error: "invalid", field, message}
/// DELETE /me/lists/:id   deletes the list and its entries
///        204
/// All need `Authorization: Bearer <token>`: 401 if not logged in,
/// 404 if there's no such list or it isn't yours
Future<Response> onRequest(RequestContext context, String id) async {
  final method = context.request.method;
  if (method != HttpMethod.get &&
      method != HttpMethod.put &&
      method != HttpMethod.delete) {
    return methodNotAllowed();
  }

  final user = await currentUser(context);
  if (user == null) return notLoggedIn();

  final listId = parseId(id);
  if (listId == null) return notFound('List');
  final lists = context.read<ListDao>();

  if (method == HttpMethod.delete) {
    final deleted = await lists.delete(user.userId, listId);
    return deleted ? Response(statusCode: 204) : notFound('List');
  }

  if (method == HttpMethod.put) {
    final body = await readJsonObject(context.request);
    if (body == null) return badJson();
    final (list, problem) = parseNewList(body);
    if (problem != null) return _invalid(problem.field, problem.message);

    final missing = await lists.missingTitles(list!.titleIds);
    if (missing.isNotEmpty) {
      return _invalid('titleIds', 'Unknown title ids: ${missing.join(', ')}.');
    }
    final saved = await lists.update(
      userId: user.userId,
      listId: listId,
      name: list.name,
      description: list.description,
      titleIds: list.titleIds,
    );
    if (!saved) return notFound('List');
  }

  // GET, or the list as just saved by PUT
  final list = await lists.find(user.userId, listId);
  if (list == null) return notFound('List');
  return Response.json(body: {'list': list.toJson()});
}

Response _invalid(String field, String message) => Response.json(
  statusCode: 400,
  body: {'error': 'invalid', 'field': field, 'message': message},
);
