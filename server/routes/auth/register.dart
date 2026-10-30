import 'package:dart_frog/dart_frog.dart';
import 'package:server/auth/auth_service.dart';
import 'package:server/auth/http_helpers.dart';

/// POST /auth/register  {email, username, password}
/// 201 {token, userId, role} - 400 invalid field - 409 taken field
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) return methodNotAllowed();
  final body = await readJsonObject(context.request);
  if (body == null) return badJson();

  try {
    final result = await context.read<AuthService>().register(
          email: stringField(body, 'email'),
          username: stringField(body, 'username'),
          password: stringField(body, 'password'),
        );
    return Response.json(
      statusCode: 201,
      body: {
        'token': result.token,
        'userId': result.userId,
        'role': result.role,
      },
    );
  } on AuthException catch (e) {
    return Response.json(statusCode: e.statusCode, body: e.body);
  }
}
