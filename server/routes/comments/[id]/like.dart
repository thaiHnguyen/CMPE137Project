import 'package:dart_frog/dart_frog.dart';
import 'package:server/auth/http_helpers.dart';
import 'package:server/browse/paging.dart';
import 'package:server/dao/review_dao.dart';
import 'package:server/reviews/review_routes.dart';

/// PUT    /comments/:id/like   like a comment
/// DELETE /comments/:id/like   take the like back
/// Both are safe to repeat. 200 {likeCount, likedByMe}
/// 400 your own comment - 401 not logged in - 403 admin
/// 404 no such comment
Future<Response> onRequest(RequestContext context, String id) async {
  final method = context.request.method;
  if (method != HttpMethod.put && method != HttpMethod.delete) {
    return methodNotAllowed();
  }
  final (user, error) = await registeredUser(context);
  if (error != null) return error;

  final commentId = parseId(id);
  final reviews = context.read<ReviewDao>();
  final author =
      commentId == null ? null : await reviews.commentAuthor(commentId);
  if (author == null) return notFound('Comment');
  if (author == user!.userId) {
    return invalid('comment', "You can't like your own comment.");
  }

  await reviews.setCommentLike(
    commentId!,
    user.userId,
    like: method == HttpMethod.put,
  );
  final comment = await reviews.findComment(commentId, viewerId: user.userId);
  return Response.json(
    body: {'likeCount': comment!.likeCount, 'likedByMe': comment.likedByMe},
  );
}
