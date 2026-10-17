// Imports popular movies and TV shows from TMDB into the NoiReel catalog.
//
// Run from inside server/:
//   dart run bin/import_tmdb.dart              (10 pages each = ~200 movies + ~200 shows)
//   dart run bin/import_tmdb.dart --pages 3    (quick test run)
//
// Safe to re-run: titles, genres and people are matched on their TMDB ids
// and updated in place, so nothing is duplicated. Ratings, reviews and
// mood data stored in NoiReel are never touched.
//
// Uses DB_* and TMDB_API_KEY from server/.env (see .env.example).
// TMDB_API_KEY can be either the v3 "API Key" or the v4 "Read Access Token".

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mysql_client/mysql_client.dart';
import 'package:server/db.dart';

const _apiBase = 'https://api.themoviedb.org/3';
const _posterBase = 'https://image.tmdb.org/t/p/w500';
const _topCast = 10; // GU-03.02

final _key = env['TMDB_API_KEY'] ?? '';
final _client = http.Client();

Future<void> main(List<String> args) async {
  if (_key.isEmpty) {
    stderr.writeln('TMDB_API_KEY is missing from server/.env');
    exit(1);
  }
  final pagesArg = args.indexOf('--pages');
  final pages = pagesArg >= 0 && pagesArg + 1 < args.length
      ? int.parse(args[pagesArg + 1])
      : 10;

  try {
    final genreIds = await _importGenres();
    stdout.writeln('Genres: ${genreIds.length} TMDB genre ids mapped');

    for (final type in ['movie', 'tv']) {
      final ids = await _popularIds(type, pages);
      stdout.writeln('$type: ${ids.length} popular titles to import');
      var done = 0;
      var failed = 0;
      for (final id in ids) {
        try {
          await _importTitle(type, id, genreIds);
          done++;
        } catch (e) {
          failed++;
          stderr.writeln('  skipped $type $id: $e');
        }
        if ((done + failed) % 25 == 0) {
          stdout.writeln('  ${done + failed}/${ids.length}');
        }
      }
      stdout.writeln('$type: $done imported, $failed skipped');
    }
  } finally {
    _client.close();
    await db.close();
  }
}

/// GET a TMDB endpoint as JSON, retrying briefly if rate limited.
Future<Map<String, dynamic>> _get(
  String path, [
  Map<String, String> query = const {},
]) async {
  final useBearer = _key.startsWith('eyJ'); // v4 tokens are JWTs
  final uri = Uri.parse('$_apiBase$path').replace(
    queryParameters: {
      'language': 'en-US',
      ...query,
      if (!useBearer) 'api_key': _key,
    },
  );
  final headers = {
    'accept': 'application/json',
    if (useBearer) 'Authorization': 'Bearer $_key',
  };

  for (var attempt = 0; attempt < 4; attempt++) {
    final res = await _client.get(uri, headers: headers);
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    if (res.statusCode == 429) {
      await Future<void>.delayed(Duration(seconds: 2 * (attempt + 1)));
      continue;
    }
    throw HttpException('TMDB $path -> ${res.statusCode}: ${res.body}');
  }
  throw HttpException('TMDB $path -> still rate limited');
}

/// Upserts the movie and TV genre lists. Returns TMDB genre id -> genre_id.
Future<Map<int, int>> _importGenres() async {
  final map = <int, int>{};
  for (final type in ['movie', 'tv']) {
    final data = await _get('/genre/$type/list');
    for (final g in _objects(data['genres'])) {
      final tmdbId = g['id'] as int;
      if (map.containsKey(tmdbId)) continue; // e.g. Drama is in both lists
      final res = await db.execute(
        'INSERT INTO genres (tmdb_genre_id, name) VALUES (:tid, :name) '
        'ON DUPLICATE KEY UPDATE genre_id = LAST_INSERT_ID(genre_id)',
        {'tid': tmdbId, 'name': g['name']},
      );
      map[tmdbId] = res.lastInsertID.toInt();
    }
  }
  return map;
}

/// TMDB ids from the first [pages] pages of /movie/popular or /tv/popular.
Future<List<int>> _popularIds(String type, int pages) async {
  final ids = <int>{}; // popular lists can repeat a title across pages
  for (var p = 1; p <= pages; p++) {
    final data = await _get('/$type/popular', {'page': '$p'});
    for (final r in _objects(data['results'])) {
      ids.add(r['id'] as int);
    }
  }
  return ids.toList();
}

int? _year(Object? date) {
  final s = date as String?;
  return (s == null || s.length < 4) ? null : int.tryParse(s.substring(0, 4));
}

int? _positive(Object? n) => (n is int && n > 0) ? n : null;

/// A JSON array of objects, typed so fields can be read without dynamic calls.
List<Map<String, dynamic>> _objects(Object? v) =>
    (v as List?)?.cast<Map<String, dynamic>>() ?? const [];

String? _clip(String? s, int max) =>
    (s == null || s.isEmpty) ? null : (s.length <= max ? s : s.substring(0, max));

/// Fetches one title's details + credits and writes it in one transaction.
Future<void> _importTitle(String type, int tmdbId, Map<int, int> genreIds) async {
  final d = await _get('/$type/$tmdbId', {'append_to_response': 'credits'});
  final isTv = type == 'tv';

  final episodeTimes = (d['episode_run_time'] as List?)?.cast<int>() ?? const <int>[];
  final runtime = isTv
      ? _positive(episodeTimes.isEmpty ? null : episodeTimes.first)
      : _positive(d['runtime']);
  final poster = d['poster_path'] as String?;

  // Directors (movies) / creators (TV), then the top-billed cast.
  final creditsJson = (d['credits'] as Map<String, dynamic>?) ?? const {};
  final credits = <({int tmdbId, String name, String role, String? character, int? order})>[];
  if (isTv) {
    for (final c in _objects(d['created_by'])) {
      credits.add((tmdbId: c['id'] as int, name: c['name'] as String,
          role: 'creator', character: null, order: null));
    }
  } else {
    for (final c in _objects(creditsJson['crew'])) {
      if (c['job'] == 'Director') {
        credits.add((tmdbId: c['id'] as int, name: c['name'] as String,
            role: 'director', character: null, order: null));
      }
    }
  }
  final cast = _objects(creditsJson['cast']).take(_topCast);
  for (final c in cast) {
    credits.add((tmdbId: c['id'] as int, name: c['name'] as String,
        role: 'cast', character: _clip(c['character'] as String?, 255),
        order: c['order'] as int?));
  }

  await db.transactional((MySQLConnection conn) async {
    final res = await conn.execute(
      'INSERT INTO titles (tmdb_id, type, name, synopsis, release_year, '
      'runtime_min, num_seasons, num_episodes, poster_url, popularity) '
      'VALUES (:tmdb, :type, :name, :synopsis, :year, :runtime, :seasons, '
      ':episodes, :poster, :pop) '
      'ON DUPLICATE KEY UPDATE title_id = LAST_INSERT_ID(title_id), '
      'name = VALUES(name), synopsis = VALUES(synopsis), '
      'release_year = VALUES(release_year), runtime_min = VALUES(runtime_min), '
      'num_seasons = VALUES(num_seasons), num_episodes = VALUES(num_episodes), '
      'poster_url = VALUES(poster_url), popularity = VALUES(popularity)',
      {
        'tmdb': tmdbId,
        'type': type,
        'name': (isTv ? d['name'] : d['title']) as String,
        'synopsis': (d['overview'] as String?)?.trim().isEmpty ?? true
            ? null
            : d['overview'],
        'year': _year(isTv ? d['first_air_date'] : d['release_date']),
        'runtime': runtime,
        'seasons': isTv ? _positive(d['number_of_seasons']) : null,
        'episodes': isTv ? _positive(d['number_of_episodes']) : null,
        'poster': poster == null ? null : '$_posterBase$poster',
        'pop': (d['popularity'] as num?)?.toDouble() ?? 0,
      },
    );
    final titleId = res.lastInsertID.toInt();

    // Replace genres and credits so a re-run reflects TMDB's current data.
    await conn.execute(
      'DELETE FROM title_genres WHERE title_id = :t', {'t': titleId});
    for (final g in _objects(d['genres'])) {
      final genreId = genreIds[g['id'] as int];
      if (genreId == null) continue;
      await conn.execute(
        'INSERT IGNORE INTO title_genres (title_id, genre_id) VALUES (:t, :g)',
        {'t': titleId, 'g': genreId},
      );
    }

    await conn.execute(
      'DELETE FROM title_credits WHERE title_id = :t', {'t': titleId});
    for (final c in credits) {
      final p = await conn.execute(
        'INSERT INTO people (tmdb_id, name) VALUES (:pid, :name) '
        'ON DUPLICATE KEY UPDATE person_id = LAST_INSERT_ID(person_id), '
        'name = VALUES(name)',
        {'pid': c.tmdbId, 'name': c.name},
      );
      // IGNORE: the same person can appear twice in one role on TMDB.
      await conn.execute(
        'INSERT IGNORE INTO title_credits '
        '(title_id, person_id, role, character_name, billing_order) '
        'VALUES (:t, :p, :role, :ch, :ord)',
        {
          't': titleId,
          'p': p.lastInsertID.toInt(),
          'role': c.role,
          'ch': c.character,
          'ord': c.order,
        },
      );
    }
  });
}