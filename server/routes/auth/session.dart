import 'package:dart_frog/dart_frog.dart';
import 'package:server/auth/auth_service.dart';
import 'package:server/auth/http_helpers.dart';

/// GET /auth/session   header: Authorization: Bearer <token>
/// Call on app start (RU-01.02)
/// 200 {status: valid, userId, username, role} - 401 {status: expired}
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) return methodNotAllowed();
  final token = bearerToken(context.request);
  final user = token == null
      ? null
      : await context.read<AuthService>().checkSession(token);
  if (user == null) {
    return Response.json(statusCode: 401, body: {'status': 'expired'});
  }
  return Response.json(
    body: {
      'status': 'valid',
      'userId': user.userId,
      'username': user.username,
      'role': user.role,
    },
  );
}
