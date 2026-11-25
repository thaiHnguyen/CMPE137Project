import 'package:dart_frog/dart_frog.dart';
import 'package:server/auth/current_user.dart';
import 'package:server/auth/http_helpers.dart';
import 'package:server/dao/list_dao.dart';
import 'package:server/lists/list_request.dart';

/// GET  /me/lists   your lists, most recently changed first
///      200 {lists: [{listId, name, description, entryCount, posterUrls,
///      updatedAt}]}
/// POST /me/lists   {name, description?, titleIds: [int]}   (RU-08.01)
///      201 {list: {listId, name, description, entryCount, entries}}
///      400 {error: "invalid", field, message}
/// Both need `Authorization: Bearer <token>`: 401 if not logged in,
/// 403 for admin accounts
Future<Response> onRequest(RequestContext context) async {
  final method = context.request.method;
  if (method != HttpMethod.get && method != HttpMethod.post) {
    return methodNotAllowed();
  }

  final user = await currentUser(context);
  if (user == null) return notLoggedIn();
  // Lists belong to registered users (watchlists -> registered_users)
  if (user.role != 'user') {
    return Response.json(
      statusCode: 403,
      body: {
        'error': 'forbidden',
        'message': "Admin accounts can't have lists.",
      },
    );
  }

  final lists = context.read<ListDao>();
  if (method == HttpMethod.get) {
    final mine = await lists.myLists(user.userId);
    return Response.json(
      body: {
        'lists': [for (final l in mine) l.toJson()],
      },
    );
  }

  final body = await readJsonObject(context.request);
  if (body == null) return badJson();
  final (list, problem) = parseNewList(body);
  if (problem != null) return _invalid(problem.field, problem.message);

  final missing = await lists.missingTitles(list!.titleIds);
  if (missing.isNotEmpty) {
    return _invalid('titleIds', 'Unknown title ids: ${missing.join(', ')}.');
  }

  final id = await lists.create(
    userId: user.userId,
    name: list.name,
    description: list.description,
    titleIds: list.titleIds,
  );
  final created = await lists.find(user.userId, id);
  return Response.json(statusCode: 201, body: {'list': created!.toJson()});
}

Response _invalid(String field, String message) => Response.json(
  statusCode: 400,
  body: {'error': 'invalid', 'field': field, 'message': message},
);
