import 'package:dart_frog/dart_frog.dart';
import 'package:server/auth/http_helpers.dart';
import 'package:server/browse/paging.dart';
import 'package:server/dao/title_dao.dart';

/// GET /search?q=nolan&page=1&limit=20
/// 200 {query, page, limit, total, titles} - 400 bad keyword or paging
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) return methodNotAllowed();

  final params = context.request.uri.queryParameters;
  final keyword = (params['q'] ?? '').trim();
  if (keyword.isEmpty || keyword.length > 100) {
    return Response.json(
      statusCode: 400,
      body: {
        'error': 'invalid',
        'field': 'q',
        'message': 'Search must be 1-100 characters.',
      },
    );
  }

  final paging = parsePaging(params);
  if (paging == null) return invalidPaging();

  final result = await context.read<TitleDao>().search(keyword, paging);
  return Response.json(
    body: {
      'query': keyword,
      'page': paging.page,
      'limit': paging.limit,
      'total': result.total,
      'titles': [for (final t in result.titles) t.toJson()],
    },
  );
}
