import 'package:dart_frog/dart_frog.dart';
import 'package:server/auth/http_helpers.dart';
import 'package:server/browse/paging.dart';
import 'package:server/dao/mood_dao.dart';
import 'package:server/dao/title_dao.dart';

/// GET /moods/:id/titles?page=1&limit=20[&shuffle=12345]
/// 200 {mood, page, limit, total, titles} - 400 bad paging or shuffle
/// - 404 no such mood
///
/// Without `shuffle`: best mood fit first. 
/// With it: the same titles in a random order. 
/// Keep the same number while paging; send a new one to reshuffle

Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.get) return methodNotAllowed();

  final query = context.request.uri.queryParameters;
  final paging = parsePaging(query);
  if (paging == null) return invalidPaging();

  final rawShuffle = query['shuffle'];
  final shuffle = rawShuffle == null ? null : parseId(rawShuffle);
  if (rawShuffle != null && (shuffle == null || shuffle > 0x7FFFFFFF)) {
    return Response.json(
      statusCode: 400,
      body: {
        'error': 'invalid',
        'message': 'shuffle must be a whole number from 1 to 2147483647.',
      },
    );
  }

  final moodId = parseId(id);
  final mood =
      moodId == null ? null : await context.read<MoodDao>().findActive(moodId);
  if (mood == null) return notFound('Mood');

  final result = await context
      .read<TitleDao>()
      .titlesForMood(mood.id, paging, shuffle: shuffle);
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
