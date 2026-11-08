import 'package:dart_frog/dart_frog.dart';
import 'package:server/auth/http_helpers.dart';
import 'package:server/browse/paging.dart';
import 'package:server/dao/mood_dao.dart';
import 'package:server/dao/title_dao.dart';

/// GET /moods/:id/titles?page=1&limit=20
/// 200 {mood, page, limit, total, titles} - 400 bad paging - 404 no such mood
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.get) return methodNotAllowed();

  final paging = parsePaging(context.request.uri.queryParameters);
  if (paging == null) return invalidPaging();

  final moodId = parseId(id);
  final mood =
      moodId == null ? null : await context.read<MoodDao>().findActive(moodId);
  if (mood == null) return notFound('Mood');

  final result = await context.read<TitleDao>().titlesForMood(mood.id, paging);
  return Response.json(
    body: {
      'mood': mood.toJson(),
      'page': paging.page,
      'limit': paging.limit,
      'total': result.total,
      'titles': [for (final t in result.titles) t.toJson()],
    },
  );
}
