import 'package:dart_frog/dart_frog.dart';
import 'package:server/auth/current_user.dart';
import 'package:server/dao/session_dao.dart';

/// The logged-in user, or the response to send instead: 401 if not
/// logged in, 403 for an admin (likes and comments belong to registered
/// users)
Future<(SessionUser?, Response?)> registeredUser(
  RequestContext context,
) async {
  final user = await currentUser(context);
  if (user == null) return (null, notLoggedIn());
  if (user.role != 'user') {
    return (
      null,
      Response.json(
        statusCode: 403,
        body: {
          'error': 'forbidden',
          'message': "Admin accounts can't like or comment.",
        },
      ),
    );
  }
  return (user, null);
}

/// 400 with a message
Response invalid(String field, String message) => Response.json(
  statusCode: 400,
  body: {'error': 'invalid', 'field': field, 'message': message},
);
