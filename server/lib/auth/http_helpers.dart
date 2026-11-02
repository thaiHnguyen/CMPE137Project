import 'package:dart_frog/dart_frog.dart';

/// Parses the request body as a JSON object, or returns null if it isn't one.
Future<Map<String, dynamic>?> readJsonObject(Request request) async {
  try {
    final data = await request.json();
    return data is Map<String, dynamic> ? data : null;
  } on Exception {
    return null;
  }
}

/// A string field from a JSON body, or '' if missing or not a string.
String stringField(Map<String, dynamic> body, String key) {
  final value = body[key];
  return value is String ? value : '';
}

/// The token from an `Authorization: Bearer <token>` header, or null.
String? bearerToken(Request request) {
  final header = request.headers['authorization'] ?? '';
  if (!header.startsWith('Bearer ')) return null;
  final token = header.substring(7).trim();
  return token.isEmpty ? null : token;
}

/// 400 response for a body that isn't a JSON object.
Response badJson() => Response.json(
      statusCode: 400,
      body: {'error': 'bad_request', 'message': 'Body must be a JSON object.'},
    );

/// 405 response for the wrong HTTP method.
Response methodNotAllowed() => Response(statusCode: 405);
