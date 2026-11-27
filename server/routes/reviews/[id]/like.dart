import 'package:dart_frog/dart_frog.dart';
import 'package:server/auth/http_helpers.dart';
import 'package:server/browse/paging.dart';
import 'package:server/dao/review_dao.dart';
import 'package:server/reviews/review_routes.dart';

/// PUT    /reviews/:id/like   like a review
/// DELETE /reviews/:id/like   take the like back
/// Both are safe to repeat. 200 {likeCount, likedByMe}
/// 400 your own review - 401 not logged in - 403 admin - 404 no such review
Future<Response> onRequest(RequestContext context, String id) async {
  final method = context.request.method;
  if (method != HttpMethod.put && method != HttpMethod.delete) {
    return methodNotAllowed();
  }
  final (user, error) = await registeredUser(context);
  if (error != null) return error;

  final reviewId = parseId(id);
  final reviews = context.read<ReviewDao>();
  final author = reviewId == null ? null : await reviews.reviewAuthor(reviewId);
  if (author == null) return notFound('Review');
  if (author == user!.userId) {
    return invalid('review', "You can't like your own review.");
  }

  await reviews.setReviewLike(
    reviewId!,
    user.userId,
    like: method == HttpMethod.put,
  );
  final review = await reviews.find(reviewId, viewerId: user.userId);
  return Response.json(
    body: {'likeCount': review!.likeCount, 'likedByMe': review.likedByMe},
  );
}
