import 'package:dart_frog/dart_frog.dart';
import 'package:server/auth/http_helpers.dart';
import 'package:server/browse/paging.dart';
import 'package:server/dao/review_dao.dart';
import 'package:server/dao/title_dao.dart';

/// GET /titles/:id/similar?page=1&limit=20
/// Titles with a similar mood: they share this title's main mood, or at
/// least 3 of its 5 mood tags. Most alike first
/// 200 {page, limit, total, titles} - 400 bad paging - 404 no such title
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.get) return methodNotAllowed();

  final paging = parsePaging(context.request.uri.queryParameters);
  if (paging == null) return invalidPaging();

  final titleId = parseId(id);
  if (titleId == null || !await context.read<TitleDao>().exists(titleId)) {
    return notFound('Title');
  }

  final result = await context.read<ReviewDao>().similar(titleId, paging);
  return Response.json(
    body: {
      'page': paging.page,
      'limit': paging.limit,
      'total': result.total,
      'titles': [for (final t in result.titles) t.toJson()],
    },
  );
}
