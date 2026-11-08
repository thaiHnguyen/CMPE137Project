// Imports movies and TV shows from TMDB into the NoiReel catalog.
//
// NoiReel ranks titles by mood fit, not by what's trending, so the catalog
// needs depth in every genre (and so every mood), across decades. For both
// movies and TV it pulls:
//   * the best-rated titles in EACH genre (enough TMDB votes to be known)
//   * TMDB's all-time top rated list
//   * one page of currently popular titles, so new releases still exist
// This only decides WHICH titles are in the catalog. Mood rows are still
// ordered by mood_score; TMDB's rating only breaks ties.
//
// Run from inside server/:
//   dart run bin/import_tmdb.dart              (3 pages per source)
//   dart run bin/import_tmdb.dart --pages 1    (quick test run)
//
// Safe to re-run: titles, genres and people are matched on their TMDB ids
// and updated in place, so nothing is duplicated. Ratings, reviews and
// community mood votes stored in NoiReel are never touched.
//
// At the end it refreshes every title's starting mood fit from its genres
// (title_moods.genre_score), so seed_moods.sql only has to be run once.
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

// Fewest TMDB votes for a title to count as "best-rated" in a genre.
// Without a floor, a title rated 10/10 by 3 people would top every genre.
// Mood rows hide titles under 200 votes, so importing them would be wasted.
const _minVotes = {'movie': 300, 'tv': 200};

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
      : 3;

  try {
    final genres = await _importGenres();
    stdout.writeln('Genres: ${genres.ids.length} TMDB genre ids mapped');

    for (final type in ['movie', 'tv']) {
      final ids = await _titleIds(type, genres.byType[type]!, pages);
      stdout.writeln('$type: ${ids.length} titles to import');
      final genreIds = genres.ids;
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

    final moodFit = await _refreshMoodFit();
    stdout.writeln('Mood fit: $moodFit titles have a starting mood');
    if (moodFit == 0) {
      stdout.writeln('  Run db/seed_moods.sql once, then this is automatic.');
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

/// Upserts the movie and TV genre lists.
/// Returns TMDB genre id -> genre_id, and each type's TMDB genre ids
Future<({Map<int, int> ids, Map<String, List<int>> byType})>
    _importGenres() async {
  final map = <int, int>{};

  final byType = <String, List<int>>{};

  for (final type in ['movie', 'tv']) {
    final data = await _get('/genre/$type/list');
    byType[type] = [];

    for (final g in _objects(data['genres'])) {
      final tmdbId = g['id'] as int;
      byType[type]!.add(tmdbId);

      if (map.containsKey(tmdbId)) continue; // e.g. Drama is in both lists

      final res = await db.execute(
        'INSERT INTO genres (tmdb_genre_id, name) VALUES (:tid, :name) '
        'ON DUPLICATE KEY UPDATE genre_id = LAST_INSERT_ID(genre_id)',
        {'tid': tmdbId, 'name': g['name']},
      );

      map[tmdbId] = res.lastInsertID.toInt();
    }
  }
  return (ids: map, byType: byType);
}

/// TMDB ids to import for [type]: the best-rated titles in each genre,
/// the all-time top rated list, then one page of currently popular titles.
Future<List<int>> _titleIds(
  String type,
  List<int> genreIds,
  int pages,
) async {
  final ids = <int>{}; // a title can be in several lists; import it once

  for (final genre in genreIds) {
    await _collect(ids, '/discover/$type', pages, {
      'with_genres': '$genre',
      'sort_by': 'vote_average.desc',
      'vote_count.gte': '${_minVotes[type]}',
    });
  }
  
  await _collect(ids, '/$type/top_rated', pages);
  await _collect(ids, '/$type/popular', 1);
  return ids.toList();
}

/// Adds the TMDB ids from the first [pages] pages of a list endpoint.
Future<void> _collect(
  Set<int> ids,
  String path,
  int pages, [
  Map<String, String> query = const {},
]) async {
  for (var p = 1; p <= pages; p++) {
    final data = await _get(path, {...query, 'page': '$p'});
    for (final r in _objects(data['results'])) {
      ids.add(r['id'] as int);
    }
    final totalPages = (data['total_pages'] as int?) ?? 0;
    if (p >= totalPages) break; // a small genre may have fewer pages
  }
}

/// Recomputes every title's starting mood fit from its genres
/// (same as the last step of seed_moods.sql). Community votes and admin
/// tags are kept. Returns how many titles have at least one starting mood
Future<int> _refreshMoodFit() async {
  await db.transactional((MySQLConnection conn) async {
    await conn.execute(
      'UPDATE title_moods SET genre_score = 0 WHERE genre_score <> 0',
    );
    await conn.execute(
      'INSERT INTO title_moods (title_id, mood_id, genre_score) '
      'SELECT tg.title_id, gm.mood_id, MAX(gm.weight) '
      'FROM title_genres tg '
      'JOIN genre_moods gm ON gm.genre_id = tg.genre_id '
      'GROUP BY tg.title_id, gm.mood_id '
      'ON DUPLICATE KEY UPDATE genre_score = VALUES(genre_score)',
    );
  });
  final res = await db.execute(
    'SELECT COUNT(DISTINCT title_id) AS n FROM title_moods '
    'WHERE genre_score > 0',
  );
  return int.parse(res.rows.first.colByName('n')!);
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
    (s == null || s.isEmpty) ? null : 
        (s.length <= max ? s : s.substring(0, max));

/// Fetches one title's details + credits and writes it in one transaction.
Future<void> _importTitle(String type, int tmdbId, 
                          Map<int, int> genreIds) async {
  final d = await _get('/$type/$tmdbId', {'append_to_response': 'credits'});
  final isTv = type == 'tv';

  final episodeTimes = (d['episode_run_time'] as List?)?.cast<int>() ?? 
                          const <int>[];
  final runtime = isTv
      ? _positive(episodeTimes.isEmpty ? null : episodeTimes.first)
      : _positive(d['runtime']);
  final poster = d['poster_path'] as String?;
  final voteAvg = (d['vote_average'] as num?)?.toDouble();
  final voteCount = (d['vote_count'] as int?) ?? 0;

  // Directors (movies) / creators (TV), then the top-billed cast
  final creditsJson = (d['credits'] as Map<String, dynamic>?) ?? const {};
  final credits = <({int tmdbId, String name, String role, 
                      String? character, int? order})>[];
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
      'runtime_min, num_seasons, num_episodes, poster_url, popularity, '
      'tmdb_vote_avg, tmdb_vote_count) '
      'VALUES (:tmdb, :type, :name, :synopsis, :year, :runtime, :seasons, '
      ':episodes, :poster, :pop, :vote_avg, :vote_count) '
      'ON DUPLICATE KEY UPDATE title_id = LAST_INSERT_ID(title_id), '
      'name = VALUES(name), synopsis = VALUES(synopsis), '
      'release_year = VALUES(release_year), '
      'runtime_min = VALUES(runtime_min), '
      'num_seasons = VALUES(num_seasons), '
      'num_episodes = VALUES(num_episodes), '
      'poster_url = VALUES(poster_url), popularity = VALUES(popularity), '
      'tmdb_vote_avg = VALUES(tmdb_vote_avg), '
      'tmdb_vote_count = VALUES(tmdb_vote_count)',
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
        // No votes means no real score, so store NULL rather than 0.0
        'vote_avg': voteCount == 0 || voteAvg == null
            ? null
            : double.parse(voteAvg.toStringAsFixed(1)),
        'vote_count': voteCount,
      },
    );
    final titleId = res.lastInsertID.toInt();

    // Replace genres and credits so a re-run reflects TMDB's current data
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
