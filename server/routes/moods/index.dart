import 'package:dart_frog/dart_frog.dart';
import 'package:server/auth/http_helpers.dart';
import 'package:server/dao/mood_dao.dart';

/// GET /moods
/// 200 {moods: [{moodId, name, description, colorHex, counterMoodIds}]}
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) return methodNotAllowed();
  final moods = await context.read<MoodDao>().listActive();
  return Response.json(
    body: {
      'moods': [for (final m in moods) m.toJson()],
    },
  );
}
