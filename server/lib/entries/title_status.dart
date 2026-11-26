import 'package:dart_frog/dart_frog.dart';
import 'package:server/auth/current_user.dart';
import 'package:server/browse/paging.dart';
import 'package:server/dao/collection_dao.dart';
import 'package:server/dao/entry_dao.dart';
import 'package:server/dao/session_dao.dart';
import 'package:server/dao/title_dao.dart';

/// The logged-in, non-admin user and the title in the URL, or the error
/// response to send instead (401 not logged in, 403 admin, 404 no title)
/// 
/// Favorites, watchlists, ratings, reviews, logs and mood votes all belong
/// to registered users, so admins can't have them
Future<(SessionUser?, int?, Response?)> userAndTitle(
  RequestContext context,
  String id,
) async {
  final user = await currentUser(context);
  if (user == null) return (null, null, notLoggedIn());
  if (user.role != 'user') {
    return (
      null,
      null,
      Response.json(
        statusCode: 403,
        body: {
          'error': 'forbidden',
          'message': "Admin accounts can't review, log or save titles.",
        },
      ),
    );
  }
  final titleId = parseId(id);
  if (titleId == null || !await context.read<TitleDao>().exists(titleId)) {
    return (null, null, notFound('Title'));
  }
  return (user, titleId, null);
}

/// What the ⋮ menu on a details page needs: whether the title is in the
/// user's Favorites and Watchlist, and their review and log of it
Future<Response> titleStatusResponse(
  RequestContext context,
  int userId,
  int titleId,
) async {
  final collections = context.read<CollectionDao>();
  final entry = await context.read<EntryDao>().find(userId, titleId);
  return Response.json(
    body: {
      'titleId': titleId,
      'favorite': await collections.contains(
        userId,
        Collection.favorites,
        titleId,
      ),
      'watchlist': await collections.contains(
        userId,
        Collection.watchlist,
        titleId,
      ),
      'logged': entry.logged,
      'entry': entry.toJson(),
    },
  );
}
