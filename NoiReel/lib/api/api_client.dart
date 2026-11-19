import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'models.dart';

/// A request to the NoiReel server that failed
class ApiException implements Exception {
  /// Creates an [ApiException].
  ApiException(
    this.message, {
    this.statusCode,
    this.body = const {},
  });

  final String message;         // Message that can be shown to the user
  final int? statusCode;        // HTTP status, if the server answered at all
  final Map<String, dynamic> body; // The server's JSON error, if any

  /// The server's error code, e.g. `incorrect`, `locked` or `taken`
  String? get error => body['error'] as String?;

  /// The form field the server rejected, e.g. `email` or `username`
  String? get field => body['field'] as String?;

  @override
  String toString() => message;
}

/// Talks to the Dart Frog server. Every screen uses this instead of
/// calling `http` directly, so the server address lives in one place
class ApiClient {
  /// Creates a client. [baseUrl] defaults to `API_URL` from `.env`.
  ApiClient({String? baseUrl, http.Client? client})
    : baseUrl = baseUrl ?? dotenv.env['API_URL'] ?? 'http://localhost:8080',
      _http = client ?? http.Client();

  /// Server address, such as the public `http://localhost:8080`
  final String baseUrl;

  final http.Client _http;

  /// `GET /moods`: every active mood
  Future<List<Mood>> getMoods() async {
    final json = await _get('/moods');
    return [
      for (final m in json['moods'] as List<dynamic>)
        Mood.fromJson(m as Map<String, dynamic>),
    ];
  }

  /// `GET /moods/:id/titles`: a mood row, best mood fit first
  Future<TitlePage> getMoodTitles(
    int moodId, {
    int page = 1,
    int limit = 20,
  }) async {
    final json = await _get('/moods/$moodId/titles', {
      'page': '$page',
      'limit': '$limit',
    });
    return TitlePage.fromJson(json);
  }

  /// `GET /titles/:id`: everything for the title details page
  Future<TitleDetails> getTitle(int titleId) async {
    final json = await _get('/titles/$titleId');
    return TitleDetails.fromJson(json);
  }

  /// `GET /search?q=`: titles whose name, director/creator or cast match
  /// [query], best match first, [limit] per page (GU-02.02)
  Future<TitlePage> search(
    String query, {
    int page = 1,
    int limit = 20,
  }) async {
    final json = await _get('/search', {
      'q': query,
      'page': '$page',
      'limit': '$limit',
    });
    return TitlePage.fromJson(json);
  }

  /// `POST /auth/register`: creates an account and logs it in (GU-07).
  /// A rejected field comes back as an [ApiException] with [ApiException.field]
  Future<AuthResult> register({
    required String email,
    required String username,
    required String password,
  }) async {
    final json = await _send('POST', '/auth/register', body: {
      'email': email,
      'username': username,
      'password': password,
    });
    return AuthResult.fromJson(json);
  }

  /// `POST /auth/login`: [login] is a username or an email (GU-08)
  Future<AuthResult> login({
    required String login,
    required String password,
  }) async {
    final json = await _send('POST', '/auth/login', body: {
      'login': login,
      'password': password,
    });
    return AuthResult.fromJson(json);
  }

  /// `GET /auth/session`: who [token] belongs to, or null if it has
  /// expired (RU-01.02)
  Future<SessionInfo?> checkSession(String token) async {
    try {
      final json = await _send('GET', '/auth/session', token: token);
      return SessionInfo.fromJson(json);
    } on ApiException catch (e) {
      if (e.statusCode == 401) return null;
      rethrow;
    }
  }

  /// `POST /auth/logout`: ends the session behind [token] (RU-01.03)
  Future<void> logout(String token) =>
      _send('POST', '/auth/logout', token: token);

  Future<Map<String, dynamic>> _get(
    String path, [
    Map<String, String>? query,
  ]) =>
      _send('GET', path, query: query);

  /// Sends a request and returns its JSON body. Anything other than a
  /// 2xx answer becomes an [ApiException] carrying the server's message
  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, Object?>? body,
    String? token, // sent as `Authorization: Bearer <token>`
  }) async {
    final request = http.Request(
      method,
      Uri.parse('$baseUrl$path').replace(queryParameters: query),
    );
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    if (token != null) request.headers['Authorization'] = 'Bearer $token';

    final http.Response res;
    try {
      res = await http.Response.fromStream(
        await _http.send(request).timeout(const Duration(seconds: 15)),
      );
    } on Exception {
      throw ApiException("Can't reach the server. Is dart_frog dev running?");
    }

    final json = _decode(res.body);
    final map = json is Map<String, dynamic> ? json : <String, dynamic>{};
    if (res.statusCode >= 200 && res.statusCode < 300) return map;

    final message = map['message'] is String
        ? map['message'] as String
        : 'Something went wrong (${res.statusCode}).';
    throw ApiException(message, statusCode: res.statusCode, body: map);
  }

  /// JSON body, or null if it's empty or not JSON
  /// (e.g. Dart Frog's plain-text "Route not found")
  static Object? _decode(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }
}
