import 'package:dart_frog/dart_frog.dart';
import 'package:server/auth/auth_service.dart';
import 'package:server/auth/http_helpers.dart';

/// POST /auth/logout   header: Authorization: Bearer <token>
/// 204 - 401 missing token
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) return methodNotAllowed();
  final token = bearerToken(context.request);
  if (token == null) {
    return Response.json(statusCode: 401, body: {'error': 'no_token'});
  }
  await context.read<AuthService>().logout(token);
  return Response(statusCode: 204);
}
