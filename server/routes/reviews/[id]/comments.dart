import 'package:dart_frog/dart_frog.dart';
import 'package:server/auth/http_helpers.dart';
import 'package:server/browse/paging.dart';
import 'package:server/dao/review_dao.dart';
import 'package:server/reviews/review_routes.dart';

/// POST /reviews/:id/comments   {body}   add a comment (up to 2000
/// characters) under a review
/// 201 {comment} - 400 {error: "invalid", field: "body", message}
/// 401 not logged in - 403 admin - 404 no such review
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.post) return methodNotAllowed();
  final (user, error) = await registeredUser(context);
  if (error != null) return error;

  final reviewId = parseId(id);
  final reviews = context.read<ReviewDao>();
  if (reviewId == null || await reviews.reviewAuthor(reviewId) == null) {
    return notFound('Review');
  }

  final json = await readJsonObject(context.request);
  if (json == null) return badJson();
  final raw = json['body'];
  final body = raw is String ? raw.trim() : '';
  if (body.isEmpty) return invalid('body', 'Write a comment first.');
  if (body.runes.length > ReviewDao.maxComment) {
    return invalid('body', 'Use at most ${ReviewDao.maxComment} characters.');
  }

  final commentId = await reviews.addComment(reviewId, user!.userId, body);
  final comment = await reviews.findComment(
    commentId,
    viewerId: user.userId,
  );
  return Response.json(statusCode: 201, body: {'comment': comment!.toJson()});
}
