import 'dart:convert';
import 'dart:typed_data';

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
  /// With [shuffle], the titles come in a random order picked by that
  /// number: keep it while loading more pages, change it to reshuffle
  Future<TitlePage> getMoodTitles(
    int moodId, {
    int page = 1,
    int limit = 20,
    int? shuffle,
  }) async {
    final json = await _get('/moods/$moodId/titles', {
      'page': '$page',
      'limit': '$limit',
      if (shuffle != null) 'shuffle': '$shuffle',
    });
    return TitlePage.fromJson(json);
  }

  /// `GET /titles/:id`: everything for the title details page
  Future<TitleDetails> getTitle(int titleId) async {
    final json = await _get('/titles/$titleId');
    return TitleDetails.fromJson(json);
  }

  /// `GET /discover`: [limit] random titles with posters for the home
  /// page's Discovery grid. Different titles on every call
  Future<List<TitleCard>> discover({int limit = 30}) async {
    final json = await _get('/discover', {'limit': '$limit'});
    return [
      for (final t in json['titles'] as List<dynamic>)
        TitleCard.fromJson(t as Map<String, dynamic>),
    ];
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

  /// `GET /me/lists`: the logged-in user's lists, newest change first
  Future<List<UserListSummary>> getMyLists(String token) async {
    final json = await _send('GET', '/me/lists', token: token);
    return [
      for (final l in json['lists'] as List<dynamic>)
        UserListSummary.fromJson(l as Map<String, dynamic>),
    ];
  }

  /// `GET /me/lists/:id`: one of the user's lists with all its entries
  Future<UserListDetails> getMyList(String token, int listId) async {
    final json = await _send('GET', '/me/lists/$listId', token: token);
    return UserListDetails.fromJson(json['list'] as Map<String, dynamic>);
  }

  /// `POST /me/lists`: creates a list with [titleIds] in that order
  /// (RU-08.01). A rejected field comes back as an [ApiException] with
  /// [ApiException.field]
  Future<UserListDetails> createList(
    String token, {
    required String name,
    String? description,
    required List<int> titleIds,
  }) async {
    final json = await _send(
      'POST',
      '/me/lists',
      token: token,
      body: {
        'name': name,
        'description': description,
        'titleIds': titleIds,
      },
    );
    return UserListDetails.fromJson(json['list'] as Map<String, dynamic>);
  }

  /// `PUT /me/lists/:id`: saves an edit. Replaces the name, description
  /// and entries, with [titleIds] in their new order. A rejected field
  /// comes back as an [ApiException] with [ApiException.field]
  Future<UserListDetails> updateList(
    String token,
    int listId, {
    required String name,
    String? description,
    required List<int> titleIds,
  }) async {
    final json = await _send(
      'PUT',
      '/me/lists/$listId',
      token: token,
      body: {
        'name': name,
        'description': description,
        'titleIds': titleIds,
      },
    );
    return UserListDetails.fromJson(json['list'] as Map<String, dynamic>);
  }

  /// `DELETE /me/lists/:id`: deletes the list and its entries
  Future<void> deleteList(String token, int listId) =>
      _send('DELETE', '/me/lists/$listId', token: token);

  /// `GET /me/titles/:id`: whether the title is in Favorites and
  /// Watchlist, and the user's review and log of it
  Future<TitleStatus> getTitleStatus(String token, int titleId) async {
    final json = await _send('GET', '/me/titles/$titleId', token: token);
    return TitleStatus.fromJson(json);
  }

  /// `PUT` or `DELETE /me/titles/:id/favorite|watchlist`: adds the title
  /// to [collection] or takes it out
  Future<TitleStatus> setInCollection(
    String token,
    int titleId,
    Collection collection, {
    required bool add,
  }) async {
    final word = collection == Collection.favorites ? 'favorite' : 'watchlist';
    final json = await _send(
      add ? 'PUT' : 'DELETE',
      '/me/titles/$titleId/$word',
      token: token,
    );
    return TitleStatus.fromJson(json);
  }

  /// `PUT /me/titles/:id/entry`: saves the user's review and log. It
  /// replaces what was saved before, so pass every field
  Future<TitleStatus> saveEntry(
    String token,
    int titleId,
    TitleEntry entry,
  ) async {
    final review = entry.review?.trim() ?? '';
    final json = await _send(
      'PUT',
      '/me/titles/$titleId/entry',
      token: token,
      body: {
        'watchedOn': entry.watchedOnText,
        'stars': entry.stars,
        'review': review.isEmpty ? null : review,
        'spoiler': entry.spoiler,
        'moodIds': entry.moodIds,
      },
    );
    return TitleStatus.fromJson(json);
  }

  /// `DELETE /me/titles/:id/entry`: deletes the user's date, rating,
  /// review and mood votes on the title
  Future<TitleStatus> deleteEntry(String token, int titleId) async {
    final json = await _send(
      'DELETE',
      '/me/titles/$titleId/entry',
      token: token,
    );
    return TitleStatus.fromJson(json);
  }

  /// `GET /me/favorites` or `/me/watchlist`, entries in order
  Future<UserListDetails> getCollection(
    String token,
    Collection collection,
  ) async {
    final json = await _send('GET', '/me/${collection.path}', token: token);
    return UserListDetails.fromJson(json['list'] as Map<String, dynamic>);
  }

  /// `PUT /me/favorites` or `/me/watchlist`: saves the entries in this
  /// order (reordered, removed or added)
  Future<UserListDetails> saveCollection(
    String token,
    Collection collection,
    List<int> titleIds,
  ) async {
    final json = await _send(
      'PUT',
      '/me/${collection.path}',
      token: token,
      body: {'titleIds': titleIds},
    );
    return UserListDetails.fromJson(json['list'] as Map<String, dynamic>);
  }

  /// `GET /titles/:id/similar`: titles with a similar mood, most alike
  /// first
  Future<TitlePage> getSimilar(
    int titleId, {
    int page = 1,
    int limit = 30,
  }) async {
    final json = await _send(
      'GET',
      '/titles/$titleId/similar',
      query: {'page': '$page', 'limit': '$limit'},
    );
    return TitlePage.fromJson(json);
  }

  /// `GET /titles/:id/reviews`: a title's reviews, most liked first.
  /// With [mine], just the logged-in user's own. [token] is optional;
  /// with it, each review says whether you liked it
  Future<ReviewPage> getReviews(
    int titleId, {
    String? token,
    bool mine = false,
    int page = 1,
    int limit = 20,
  }) async {
    final json = await _send(
      'GET',
      '/titles/$titleId/reviews',
      token: token,
      query: {
        'page': '$page',
        'limit': '$limit',
        if (mine) 'mine': '1',
      },
    );
    return ReviewPage.fromJson(json);
  }

  /// `GET /reviews/:id`: one review and its comments, oldest first
  Future<({Review review, List<ReviewComment> comments})> getReview(
    int reviewId, {
    String? token,
  }) async {
    final json = await _send('GET', '/reviews/$reviewId', token: token);
    return (
      review: Review.fromJson(json['review'] as Map<String, dynamic>),
      comments: [
        for (final c in json['comments'] as List<dynamic>)
          ReviewComment.fromJson(c as Map<String, dynamic>),
      ],
    );
  }

  /// `PUT` or `DELETE /reviews/:id/like`
  Future<({int count, bool mine})> setReviewLike(
    String token,
    int reviewId, {
    required bool like,
  }) async {
    final json = await _send(
      like ? 'PUT' : 'DELETE',
      '/reviews/$reviewId/like',
      token: token,
    );
    return (count: json['likeCount'] as int, mine: json['likedByMe'] as bool);
  }

  /// `POST /reviews/:id/comments`: adds a comment
  Future<ReviewComment> addComment(
    String token,
    int reviewId,
    String body,
  ) async {
    final json = await _send(
      'POST',
      '/reviews/$reviewId/comments',
      token: token,
      body: {'body': body},
    );
    return ReviewComment.fromJson(json['comment'] as Map<String, dynamic>);
  }

  /// `DELETE /comments/:id`: deletes one of your comments
  Future<void> deleteComment(String token, int commentId) =>
      _send('DELETE', '/comments/$commentId', token: token);

  /// `PUT` or `DELETE /comments/:id/like`
  Future<({int count, bool mine})> setCommentLike(
    String token,
    int commentId, {
    required bool like,
  }) async {
    final json = await _send(
      like ? 'PUT' : 'DELETE',
      '/comments/$commentId/like',
      token: token,
    );
    return (count: json['likeCount'] as int, mine: json['likedByMe'] as bool);
  }

  /// Full address of a file the server hosts, such as an avatar path
  /// (`/avatars/7-123.jpg`). Full URLs are returned as they are
  String mediaUrl(String path) =>
      path.startsWith('http') ? path : '$baseUrl$path';

  /// `GET /me/profile`: the logged-in user's profile
  Future<Profile> getProfile(String token) async {
    final json = await _send('GET', '/me/profile', token: token);
    return Profile.fromJson(json['profile'] as Map<String, dynamic>);
  }

  /// `PUT /me/profile`: saves Profile Settings. A blank name or bio clears
  /// it. A rejected field comes back as an [ApiException] with
  /// [ApiException.field]; a taken email is a 409
  Future<Profile> updateProfile(
    String token, {
    String? displayName,
    String? bio,
    String? pronoun,
    required String email,
  }) async {
    final json = await _send(
      'PUT',
      '/me/profile',
      token: token,
      body: {
        'displayName': displayName,
        'bio': bio,
        'pronoun': pronoun,
        'email': email,
      },
    );
    return Profile.fromJson(json['profile'] as Map<String, dynamic>);
  }

  /// `PUT /me/profile/goat`: saves all 5 Greatest Of All Time slots, left
  /// to right (null for an empty slot)
  Future<Profile> setGoat(String token, List<int?> titleIds) async {
    final json = await _send(
      'PUT',
      '/me/profile/goat',
      token: token,
      body: {'titleIds': titleIds},
    );
    return Profile.fromJson(json['profile'] as Map<String, dynamic>);
  }

  /// `POST /me/profile/avatar`: uploads a new profile photo (JPEG, PNG or
  /// WebP, up to 5 MB)
  Future<Profile> uploadAvatar(
    String token,
    Uint8List bytes, {
    String filename = 'avatar.jpg',
  }) async {
    final request =
        http.MultipartRequest('POST', Uri.parse('$baseUrl/me/profile/avatar'))
          ..headers['Authorization'] = 'Bearer $token'
          ..files.add(
            http.MultipartFile.fromBytes('avatar', bytes, filename: filename),
          );
    final json = await _dispatch(request);
    return Profile.fromJson(json['profile'] as Map<String, dynamic>);
  }

  /// `DELETE /me/profile/avatar`: back to the default picture
  Future<Profile> removeAvatar(String token) async {
    final json = await _send('DELETE', '/me/profile/avatar', token: token);
    return Profile.fromJson(json['profile'] as Map<String, dynamic>);
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
    return _dispatch(request);
  }

  /// Sends [request] and returns its JSON, or throws an [ApiException]
  Future<Map<String, dynamic>> _dispatch(http.BaseRequest request) async {
    final http.Response res;
    try {
      res = await http.Response.fromStream(
        await _http.send(request).timeout(const Duration(seconds: 15)),
      );
    } on Exception {
      throw ApiException("Can't reach the server. Is dart_frog dev running?");
    }

    // The server always sends UTF-8
    final json = _decode(utf8.decode(res.bodyBytes, allowMalformed: true));
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
