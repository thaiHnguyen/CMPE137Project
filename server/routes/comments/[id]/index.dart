import 'package:dart_frog/dart_frog.dart';
import 'package:server/auth/http_helpers.dart';
import 'package:server/browse/paging.dart';
import 'package:server/dao/review_dao.dart';
import 'package:server/reviews/review_routes.dart';

/// DELETE /comments/:id   delete your own comment (and its likes)
/// 204 - 401 not logged in - 403 admin, or someone else's comment
/// 404 no such comment
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.delete) return methodNotAllowed();
  final (user, error) = await registeredUser(context);
  if (error != null) return error;

  final commentId = parseId(id);
  final reviews = context.read<ReviewDao>();
  final author =
      commentId == null ? null : await reviews.commentAuthor(commentId);
  if (author == null) return notFound('Comment');
  if (author != user!.userId) {
    return Response.json(
      statusCode: 403,
      body: {
        'error': 'forbidden',
        'message': 'You can only delete your own comments.',
      },
    );
  }
  await reviews.deleteComment(commentId!);
  return Response(statusCode: 204);
}
