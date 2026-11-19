import 'package:dart_frog/dart_frog.dart';
import 'package:server/auth/current_user.dart';
import 'package:server/auth/http_helpers.dart';
import 'package:server/browse/paging.dart';
import 'package:server/dao/mood_dao.dart';
import 'package:server/dao/title_dao.dart';
import 'package:server/dao/vote_dao.dart';
import 'package:server/votes/vote_response.dart';

/// PUT    /titles/:id/votes/:moodId   vote for this mood (RU-11.01)
/// DELETE /titles/:id/votes/:moodId   take the vote back (RU-11.02)
/// header: Authorization: Bearer <token>
///
/// 200 {titleId, myMoodIds, maxVotes, moods} - 401 not logged in
/// - 403 admin account - 404 no such title or mood
/// - 409 already voting for 3 moods on this title
/// Both are safe to repeat: voting twice or removing a missing vote
/// changes nothing and still returns 200
Future<Response> onRequest(
  RequestContext context,
  String id,
  String moodId,
) async {
  final method = context.request.method;
  if (method != HttpMethod.put && method != HttpMethod.delete) {
    return methodNotAllowed();
  }

  final user = await currentUser(context);
  if (user == null) return notLoggedIn();
  // Votes belong to registered users (user_mood_tags -> registered_users)
  if (user.role != 'user') {
    return Response.json(
      statusCode: 403,
      body: {
        'error': 'forbidden',
        'message': "Admin accounts can't vote on moods.",
      },
    );
  }

  final titleId = parseId(id);
  if (titleId == null || !await context.read<TitleDao>().exists(titleId)) {
    return notFound('Title');
  }
  final moodNumber = parseId(moodId);
  final mood = moodNumber == null
      ? null
      : await context.read<MoodDao>().findActive(moodNumber);
  if (mood == null) return notFound('Mood');

  final votes = context.read<VoteDao>();
  if (method == HttpMethod.delete) {
    await votes.remove(user.userId, titleId, mood.id);
  } else {
    final result = await votes.add(user.userId, titleId, mood.id);
    if (result == VoteResult.limitReached) {
      return Response.json(
        statusCode: 409,
        body: {
          'error': 'vote_limit',
          'message':
              'You can vote for up to ${VoteDao.maxPerTitle} moods '
              'per title. Remove one to pick another.',
          'maxVotes': VoteDao.maxPerTitle,
        },
      );
    }
  }

  return voteResponse(context, userId: user.userId, titleId: titleId);
}
