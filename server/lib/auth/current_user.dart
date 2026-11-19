import 'package:dart_frog/dart_frog.dart';
import 'package:server/auth/http_helpers.dart';
import 'package:server/dao/session_dao.dart';

/// The logged-in user behind the request's Bearer token, or null if there's
/// no token or it's expired. Needs a [SessionDao] provided by middleware
Future<SessionUser?> currentUser(RequestContext context) async {
  final token = bearerToken(context.request);
  if (token == null) return null;
  return context.read<SessionDao>().validate(token);
}

/// 401 response for a request that needs a logged-in user
Response notLoggedIn() => Response.json(
  statusCode: 401,
  body: {'error': 'unauthorized', 'message': 'Log in to do this.'},
);
