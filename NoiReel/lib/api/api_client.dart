import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'models.dart';

/// A request to the NoiReel server that failed
class ApiException implements Exception {
  /// Creates an [ApiException].
  ApiException(this.message, {this.statusCode});

  final String message;         // Message that can be shown to the user
  final int? statusCode;        // HTTP status, if the server answered at all

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

  Future<Map<String, dynamic>> _get(
    String path, [
    Map<String, String>? query,
  ]) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final http.Response res;
    try {
      res = await _http.get(uri).timeout(const Duration(seconds: 15));
    } on Exception {
      throw ApiException("Can't reach the server. Is dart_frog dev running?");
    }

    final body = _decode(res.body);
    if (res.statusCode == 200 && body is Map<String, dynamic>) return body;

    final message = body is Map<String, dynamic> && body['message'] is String
        ? body['message'] as String
        : 'Something went wrong (${res.statusCode}).';
    throw ApiException(message, statusCode: res.statusCode);
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
