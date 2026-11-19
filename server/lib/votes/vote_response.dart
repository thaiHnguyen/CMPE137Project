import 'package:dart_frog/dart_frog.dart';
import 'package:server/dao/title_dao.dart';
import 'package:server/dao/vote_dao.dart';

/// The user's votes on a title plus its updated mood tags, so the app can
/// redraw the details page without loading it again
Future<Response> voteResponse(
  RequestContext context, {
  required int userId,
  required int titleId,
}) async {
  final mine = await context.read<VoteDao>().myVotes(userId, titleId);
  final moods = await context.read<TitleDao>().findMoods(titleId);
  return Response.json(
    body: {
      'titleId': titleId,
      'myMoodIds': mine,
      'maxVotes': VoteDao.maxPerTitle,
      'moods': moods?.toJson(),
    },
  );
}
