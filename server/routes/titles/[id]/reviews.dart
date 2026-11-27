import 'package:dart_frog/dart_frog.dart';
import 'package:server/auth/current_user.dart';
import 'package:server/auth/http_helpers.dart';
import 'package:server/browse/paging.dart';
import 'package:server/dao/review_dao.dart';
import 'package:server/dao/title_dao.dart';

/// GET /titles/:id/reviews?page=1&limit=20&sort=popular|recent[&mine=1]
/// A title's reviews (GU-04). Popular: most liked first. `mine=1`: only
/// the logged-in user's own review (the "You" tab; empty for a guest)
/// 
/// Logging in is optional; with it, each review says whether you liked
/// it and whether it's yours
/// 
/// 200 {page, limit, total, reviews} - 400 bad paging - 404 no such title
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.get) return methodNotAllowed();

  final query = context.request.uri.queryParameters;
  final paging = parsePaging(query);
  if (paging == null) return invalidPaging();

  final titleId = parseId(id);
  if (titleId == null || !await context.read<TitleDao>().exists(titleId)) {
    return notFound('Title');
  }

  final viewer = await currentUser(context);
  final mine = query['mine'] == '1';
  if (mine && viewer == null) {
    return Response.json(
      body: {
        'page': paging.page,
        'limit': paging.limit,
        'total': 0,
        'reviews': <Object>[],
      },
    );
  }

  final result = await context.read<ReviewDao>().forTitle(
    titleId,
    paging,
    viewerId: viewer?.userId ?? 0,
    sort: query['sort'] == 'recent' ? ReviewSort.recent : ReviewSort.popular,
    onlyUser: mine ? viewer!.userId : null,
  );
  return Response.json(
    body: {
      'page': paging.page,
      'limit': paging.limit,
      'total': result.total,
      'reviews': [for (final r in result.reviews) r.toJson()],
    },
  );
}
