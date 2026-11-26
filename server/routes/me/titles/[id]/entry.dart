import 'package:dart_frog/dart_frog.dart';
import 'package:server/auth/http_helpers.dart';
import 'package:server/dao/entry_dao.dart';
import 'package:server/dao/mood_dao.dart';
import 'package:server/entries/entry_request.dart';
import 'package:server/entries/title_status.dart';

/// PUT    /me/titles/:id/entry   save your review and log of this title
///        {watchedOn?: "YYYY-MM-DD", stars?: 0.5-5, review?, spoiler?,
///         moodIds?: [up to 3]}
///        Replaces what was saved before; anything left out is removed
///        200 your status (same as GET /me/titles/:id)
///        400 {error: "invalid", field, message}
/// DELETE /me/titles/:id/entry   delete your date, rating, review and mood
///        votes on this title. 200 your status
/// Both: 401 not logged in - 403 admin - 404 no such title
Future<Response> onRequest(RequestContext context, String id) async {
  final method = context.request.method;
  if (method != HttpMethod.put && method != HttpMethod.delete) {
    return methodNotAllowed();
  }
  final (user, titleId, error) = await userAndTitle(context, id);
  if (error != null) return error;
  final entries = context.read<EntryDao>();

  if (method == HttpMethod.delete) {
    await entries.delete(user!.userId, titleId!);
  } else {
    final body = await readJsonObject(context.request);
    if (body == null) return badJson();
    final moods = await context.read<MoodDao>().listActive();
    final (entry, problem) = parseEntry(
      body,
      today: DateTime.now(),
      activeMoodIds: {for (final m in moods) m.id},
    );
    if (problem != null) {
      return Response.json(
        statusCode: 400,
        body: {
          'error': 'invalid',
          'field': problem.field,
          'message': problem.message,
        },
      );
    }
    await entries.save(user!.userId, titleId!, entry!);
  }
  return titleStatusResponse(context, user.userId, titleId);
}
