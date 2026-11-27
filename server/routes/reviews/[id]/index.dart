import 'package:dart_frog/dart_frog.dart';
import 'package:server/auth/current_user.dart';
import 'package:server/auth/http_helpers.dart';
import 'package:server/browse/paging.dart';
import 'package:server/dao/review_dao.dart';

/// GET /reviews/:id   one review with its comments (oldest first).
/// Logging in is optional; with it, the review and each comment say
/// whether you liked it and whether it's yours
/// 200 {review, comments} - 404 no such review
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.get) return methodNotAllowed();

  final reviewId = parseId(id);
  if (reviewId == null) return notFound('Review');
  final viewer = (await currentUser(context))?.userId ?? 0;
  final reviews = context.read<ReviewDao>();

  final review = await reviews.find(reviewId, viewerId: viewer);
  if (review == null) return notFound('Review');
  final comments = await reviews.comments(reviewId, viewerId: viewer);
  return Response.json(
    body: {
      'review': review.toJson(),
      'comments': [for (final c in comments) c.toJson()],
    },
  );
}
