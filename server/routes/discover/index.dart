import 'package:dart_frog/dart_frog.dart';
import 'package:server/auth/http_helpers.dart';
import 'package:server/browse/paging.dart';
import 'package:server/dao/title_dao.dart';

/// Titles per call when `?limit=` is missing
const defaultDiscoverLimit = 30;

/// Largest allowed `?limit=`
const maxDiscoverLimit = 60;

/// GET /discover?limit=30
/// 200 {titles} - random titles with posters, different on every call
/// - 400 bad limit
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) return methodNotAllowed();

  final raw = context.request.uri.queryParameters['limit'];
  final limit = raw == null ? defaultDiscoverLimit : parseId(raw);
  if (limit == null || limit > maxDiscoverLimit) {
    return Response.json(
      statusCode: 400,
      body: {
        'error': 'invalid',
        'message': 'limit must be from 1 to $maxDiscoverLimit.',
      },
    );
  }

  final titles = await context.read<TitleDao>().discover(limit);
  return Response.json(
    body: {
      'titles': [for (final t in titles) t.toJson()],
    },
  );
}
