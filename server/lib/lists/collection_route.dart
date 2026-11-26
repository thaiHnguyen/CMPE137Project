import 'package:dart_frog/dart_frog.dart';
import 'package:server/auth/current_user.dart';
import 'package:server/auth/http_helpers.dart';
import 'package:server/dao/collection_dao.dart';
import 'package:server/dao/list_dao.dart';
import 'package:server/lists/list_request.dart';

/// Shared by GET/PUT `/me/favorites` and `/me/watchlist`
Future<Response> collectionRoute(
  RequestContext context,
  Collection collection,
) async {
  final user = await currentUser(context);
  if (user == null) return notLoggedIn();
  if (user.role != 'user') {
    return Response.json(
      statusCode: 403,
      body: {
        'error': 'forbidden',
        'message': "Admin accounts don't have a ${collection.label}.",
      },
    );
  }
  final collections = context.read<CollectionDao>();

  if (context.request.method == HttpMethod.put) {
    final body = await readJsonObject(context.request);
    if (body == null) return badJson();
    // Same title id checks as a list, without a name
    final (list, problem) = parseNewList({
      'name': collection.label,
      'titleIds': body['titleIds'],
    });
    if (problem != null) return _invalid(problem.message);
    final missing = await context.read<ListDao>().missingTitles(
      list!.titleIds,
    );
    if (missing.isNotEmpty) {
      return _invalid('Unknown title ids: ${missing.join(', ')}.');
    }
    await collections.replace(user.userId, collection, list.titleIds);
  }

  final list = await collections.get(user.userId, collection);
  return Response.json(body: {'list': list.toJson()});
}

Response _invalid(String message) => Response.json(
  statusCode: 400,
  body: {'error': 'invalid', 'field': 'titleIds', 'message': message},
);
