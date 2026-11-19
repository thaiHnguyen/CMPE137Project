import 'package:dart_frog/dart_frog.dart';
import 'package:server/auth/current_user.dart';
import 'package:server/auth/http_helpers.dart';
import 'package:server/browse/paging.dart';
import 'package:server/dao/title_dao.dart';
import 'package:server/votes/vote_response.dart';

/// GET /titles/:id/votes   header: Authorization: Bearer <token>
/// 200 {titleId, myMoodIds, maxVotes, moods} - 401 not logged in
/// - 404 no such title
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.get) return methodNotAllowed();

  final user = await currentUser(context);
  if (user == null) return notLoggedIn();

  final titleId = parseId(id);
  if (titleId == null || !await context.read<TitleDao>().exists(titleId)) {
    return notFound('Title');
  }

  return voteResponse(context, userId: user.userId, titleId: titleId);
}
