import 'package:dart_frog/dart_frog.dart';
import 'package:server/auth/auth_service.dart';
import 'package:server/auth/http_helpers.dart';

/// POST /auth/login  {login, password}   (login = email or username)
/// 200 {token, userId, role} - 401 incorrect - 403 suspended/banned - 423 locked
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) return methodNotAllowed();
  final body = await readJsonObject(context.request);
  if (body == null) return badJson();

  try {
    final result = await context.read<AuthService>().login(
          login: stringField(body, 'login'),
          password: stringField(body, 'password'),
        );
    return Response.json(
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
