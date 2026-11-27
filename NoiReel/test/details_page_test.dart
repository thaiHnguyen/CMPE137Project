import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/api/api_client.dart';
import 'package:flutter_application_1/api/models.dart';
import 'package:flutter_application_1/auth/auth_controller.dart';
import 'package:flutter_application_1/auth/auth_scope.dart';
import 'package:flutter_application_1/screens/title_details_screen.dart';
import 'package:flutter_application_1/theme/noireel_theme.dart';

/// A pretend server with Kikujiro (title 7), the TV show "Series" (8),
/// and one list, "Rainy day", holding title 1. The user's token is `tok`
class FakeServer {
  FakeServer({this.ratings = const [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]});

  final List<int> ratings; // Kikujiro's rating histogram
  final listSaves = <List<Object?>>[]; // titleIds sent by PUT /me/lists/1
  var listTitleIds = <int>[1];

  // The user's status on Kikujiro
  var favorite = false;
  var watchlist = false;
  Map<String, Object?>? entry; // Null: never reviewed or logged
  final entrySaves = <Map<String, dynamic>>[]; // PUT /me/titles/7/entry
  var entryDeleted = false;

  Map<String, Object?> get _status {
    final e = entry;
    return {
      'titleId': 7,
      'favorite': favorite,
      'watchlist': watchlist,
      'logged':
          e != null &&
          (e['watchedOn'] != null || e['stars'] != null || e['review'] != null),
      'entry':
          e ??
          {
            'watchedOn': null,
            'stars': null,
            'review': null,
            'spoiler': false,
            'moodIds': <int>[],
            'updatedAt': null,
          },
    };
  }

  Map<String, Object?> card(int id) => {
    'titleId': id,
    'type': 'movie',
    'name': 'Film $id',
    'year': 2000 + id,
    'posterUrl': null,
  };

  Map<String, Object?> get _kikujiro {
    final count = ratings.fold(0, (a, b) => a + b);
    return {
      'titleId': 7,
      'type': 'movie',
      'name': 'Kikujiro',
      'year': 1999,
      'posterUrl': 'http://test/poster.jpg',
      'originalName': '菊次郎の夏',
      'backdropUrl': 'http://test/backdrop.jpg',
      'synopsis': 'Brash, loudmouthed and opportunistic.',
      'runtimeMin': 121,
      'seasons': null,
      'episodes': null,
      'avgRating': count == 0 ? null : 4.1,
      'ratingCount': count,
      'ratingHistogram': ratings,
      'genres': ['Comedy', 'Drama'],
      'directors': [
        {'personId': 1, 'name': 'Takeshi Kitano'},
      ],
      'creators': <Object>[],
      'cast': [
        {'personId': 2, 'name': 'Yusuke Sekiguchi', 'character': 'Masao'},
      ],
      'moods': {
        'primary': {'moodId': 5, 'name': 'Calm', 'votes': 2},
        'secondary': [
          {'moodId': 3, 'name': 'Happy', 'votes': 1},
        ],
        'voters': 3,
        'votes': [
          {'moodId': 5, 'name': 'Calm', 'votes': 2},
          {'moodId': 3, 'name': 'Happy', 'votes': 1},
        ],
      },
    };
  }

  static const _series = {
    'titleId': 8,
    'type': 'tv',
    'name': 'Series',
    'year': 2019,
    'posterUrl': null,
    'synopsis': null,
    'runtimeMin': 45,
    'seasons': 2,
    'episodes': 16,
    'avgRating': null,
    'ratingCount': 0,
    'genres': <String>[],
    'directors': <Object>[],
    'creators': [
      {'personId': 3, 'name': 'A Creator'},
    ],
    'cast': <Object>[],
    'moods': {
      'primary': null,
      'secondary': <Object>[],
      'voters': 0,
      'votes': <Object>[],
    },
  };

  Map<String, Object?> get _list => {
    'listId': 1,
    'name': 'Rainy day',
    'description': null,
    'entryCount': listTitleIds.length,
    'entries': [for (final id in listTitleIds) card(id)],
  };

  late final client = MockClient((req) async {
    // UTF-8 with a charset, like the real server (the default is
    // Latin-1, which can't hold titles like 菊次郎の夏)
    http.Response json(int status, Object body) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
    switch ('${req.method} ${req.url.path}') {
      case 'GET /me/titles/7':
        return json(200, _status);
      case 'PUT /me/titles/7/favorite' || 'DELETE /me/titles/7/favorite':
        favorite = req.method == 'PUT';
        return json(200, _status);
      case 'PUT /me/titles/7/watchlist' || 'DELETE /me/titles/7/watchlist':
        watchlist = req.method == 'PUT';
        return json(200, _status);
      case 'PUT /me/titles/7/entry':
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        entrySaves.add(body);
        entry = {...body, 'updatedAt': '2026-11-26 10:00:00'};
        return json(200, _status);
      case 'DELETE /me/titles/7/entry':
        entryDeleted = true;
        entry = null;
        return json(200, _status);
      case 'GET /moods':
        return json(200, {
          'moods': [
            for (final (id, name) in [(1, 'Hopeful'), (3, 'Happy'),
                (5, 'Calm'), (6, 'Excited')])
              {
                'moodId': id,
                'name': name,
                'description': '',
                'colorHex': '#000000',
                'counterMoodIds': <int>[],
              },
          ],
        });
      case 'GET /me/profile':
        return json(200, {
          'profile': {
            'userId': 1,
            'username': 'thai',
            'email': 'thai@example.com',
            'displayName': 'Thai Nguyen',
            'goat': [null, null, null, null, null],
          },
        });
      case 'GET /titles/7':
        return json(200, _kikujiro);
      case 'GET /titles/8':
        return json(200, _series);
      case 'GET /me/lists':
        return json(200, {
          'lists': [
            {
              'listId': 1,
              'name': 'Rainy day',
              'description': null,
              'entryCount': listTitleIds.length,
              'posterUrls': <String>[],
              'updatedAt': '2026-11-26 10:00:00',
            },
          ],
        });
      case 'GET /me/lists/1':
        return json(200, {'list': _list});
      case 'PUT /me/lists/1':
        final ids = (jsonDecode(req.body) as Map)['titleIds'] as List;
        listSaves.add(ids);
        listTitleIds = ids.cast<int>();
        return json(200, {'list': _list});
    }
    return http.Response('Route not found', 404);
  });

  ApiClient get api => ApiClient(baseUrl: 'http://test', client: client);
}

const _kikujiroCard = TitleCard(
  id: 7,
  type: 'movie',
  name: 'Kikujiro',
  year: 1999,
  posterUrl: 'http://test/poster.jpg',
);

const _user = Session(token: 'tok', userId: 1, username: 'thai', role: 'user');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<FakeServer> pumpDetails(
    WidgetTester tester, {
    FakeServer? server,
    TitleCard title = _kikujiroCard,
    Session? session,
  }) async {
    server ??= FakeServer();
    // A phone-sized screen
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: NoiReelPalette.defaultTheme.toThemeData(),
        home: AuthScope(
          auth: AuthController(server.api, session),
          child: TitleDetailsScreen(api: server.api, title: title),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return server;
  }

  testWidgets('header: name, original name, year, director, length',
      (tester) async {
    await pumpDetails(tester);

    expect(find.text('Kikujiro'), findsOneWidget);
    expect(find.text('菊次郎の夏'), findsOneWidget);
    expect(find.text('1999  ·  DIRECTED BY'), findsOneWidget);
    expect(find.text('Takeshi Kitano'), findsOneWidget);
    expect(find.text('2h 1m'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.byTooltip('More options'), findsOneWidget);
  });

  testWidgets('then the overview, mood tags and Ratings', (tester) async {
    await pumpDetails(tester);

    expect(find.text('Brash, loudmouthed and opportunistic.'), findsOneWidget);
    expect(find.text('Calm'), findsOneWidget); // the primary mood tag
    expect(find.text('RATINGS'), findsOneWidget);
    expect(find.text('No ratings yet.'), findsOneWidget);
    expect(find.text('–'), findsOneWidget);
  });

  testWidgets('Show votes puts vote counts on the mood tags',
      (tester) async {
    await pumpDetails(tester);

    expect(find.text('Show votes'), findsOneWidget);
    expect(find.bySemanticsLabel('Calm, 2 votes'), findsNothing);

    await tester.tap(find.text('Show votes'));
    await tester.pumpAndSettle();
    expect(find.text('Hide votes'), findsOneWidget);
    expect(find.text('MOODS ACCORDING TO 3 VOTERS'), findsOneWidget);
    expect(find.bySemanticsLabel('Calm, 2 votes'), findsOneWidget);
    expect(find.bySemanticsLabel('Happy, 1 vote'), findsOneWidget);

    await tester.tap(find.text('Hide votes'));
    await tester.pumpAndSettle();
    expect(find.text('MOODS ACCORDING TO 3 VOTERS'), findsNothing);
    expect(find.bySemanticsLabel('Calm'), findsOneWidget);
  });

  testWidgets('Ratings shows the average and count', (tester) async {
    await pumpDetails(
      tester,
      server: FakeServer(ratings: [0, 0, 0, 0, 0, 1, 0, 3, 2, 4]),
    );

    expect(find.text('4.1'), findsOneWidget);
    expect(find.text('10 ratings'), findsOneWidget);
    expect(find.byTooltip('4 ratings of 5 stars'), findsOneWidget);
    expect(find.byTooltip('3 ratings of 4 stars'), findsOneWidget);
    expect(find.byTooltip('0 ratings of ½ star'), findsOneWidget);
  });

  testWidgets('a show says CREATED BY and its seasons', (tester) async {
    await pumpDetails(
      tester,
      title: const TitleCard(id: 8, type: 'tv', name: 'Series', year: 2019),
    );

    expect(find.text('2019  ·  CREATED BY'), findsOneWidget);
    expect(find.text('A Creator'), findsOneWidget);
    expect(find.text('2 seasons  ·  16 episodes  ·  45m each'), findsOneWidget);
    expect(find.text('RATINGS'), findsOneWidget);
  });

  testWidgets('tapping the poster opens it full screen', (tester) async {
    await pumpDetails(tester);

    await tester.tap(find.bySemanticsLabel('View poster'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Close'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Close'), findsNothing);
    expect(find.text('Kikujiro'), findsOneWidget);
  });

  group('3 dots -> Add to lists', () {
    Future<void> chooseAddToList(WidgetTester tester) async {
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to lists'));
      await tester.pumpAndSettle();
    }

    testWidgets('a guest is asked to sign in', (tester) async {
      await pumpDetails(tester);
      await chooseAddToList(tester);

      expect(
        find.text(
          'Register or Sign In to your NoiReel account to review, log and '
          'save titles.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('adds the title to the end of the picked list',
        (tester) async {
      final server = await pumpDetails(tester, session: _user);
      await chooseAddToList(tester);

      expect(find.text('Rainy day'), findsOneWidget);
      await tester.tap(find.text('Rainy day'));
      await tester.pumpAndSettle();

      expect(server.listSaves.single, [1, 7]);
      expect(find.text('Added to "Rainy day".'), findsOneWidget);
    });

    testWidgets("doesn't add it twice", (tester) async {
      final server = FakeServer()..listTitleIds = [1, 7];
      await pumpDetails(tester, server: server, session: _user);
      await chooseAddToList(tester);
      await tester.tap(find.text('Rainy day'));
      await tester.pumpAndSettle();

      expect(server.listSaves, isEmpty);
      expect(find.text('Already in "Rainy day".'), findsOneWidget);
    });
  });

  group('3 dots sheet', () {
    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the title, year, Favorite, Watchlist and actions',
        (tester) async {
      await pumpDetails(tester, session: _user);
      await openSheet(tester);

      expect(find.text('1999'), findsOneWidget);
      expect(find.text('Favorite'), findsOneWidget);
      expect(find.text('Watchlist'), findsOneWidget);
      expect(find.text('Review or log'), findsOneWidget);
      expect(find.text('Add to lists'), findsOneWidget);
      expect(find.text('View poster'), findsOneWidget);
    });

    testWidgets('Favorite and Watchlist switch right away', (tester) async {
      final server = await pumpDetails(tester, session: _user);
      await openSheet(tester);

      await tester.tap(find.text('Favorite'));
      await tester.pumpAndSettle();
      expect(server.favorite, isTrue);
      expect(find.text('Favorited'), findsOneWidget);

      await tester.tap(find.text('Watchlist'));
      await tester.pumpAndSettle();
      expect(server.watchlist, isTrue);
      expect(find.text('In watchlist'), findsOneWidget);

      await tester.tap(find.text('Favorited'));
      await tester.pumpAndSettle();
      expect(server.favorite, isFalse);
    });

    testWidgets('View poster opens it full screen', (tester) async {
      await pumpDetails(tester, session: _user);
      await openSheet(tester);
      await tester.tap(find.text('View poster'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Close'), findsOneWidget);
    });

    testWidgets('Review or log saves date, stars, moods, review, spoiler',
        (tester) async {
      final server = await pumpDetails(tester, session: _user);
      await openSheet(tester);
      await tester.tap(find.text('Review or log'));
      await tester.pumpAndSettle();

      expect(find.text('I Watched'), findsOneWidget);
      // Today's date is filled in; remove it
      await tester.tap(find.byTooltip('Remove date'));
      await tester.pump();
      expect(find.text('Add date'), findsOneWidget);

      // 4 stars: the right half of the 4th star
      final stars = tester.getTopLeft(find.bySemanticsLabel('Rating'));
      await tester.tapAt(stars + const Offset(44 * 3 + 33, 20));
      await tester.pump();
      expect(find.textContaining('Rated 4 stars'), findsOneWidget);

      await tester.tap(find.text('Calm'));
      await tester.tap(find.text('Happy'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Lovely summer film.');
      await tester.pump();
      await tester.ensureVisible(find.text('No spoilers'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('No spoilers'));
      await tester.pump();
      expect(find.text('Contains spoilers'), findsOneWidget);

      await tester.tap(find.byTooltip('Save'));
      await tester.pumpAndSettle();

      expect(server.entrySaves.single, {
        'watchedOn': null,
        'stars': 4.0,
        'review': 'Lovely summer film.',
        'spoiler': true,
        'moodIds': [5, 3],
      });
      expect(find.text('I Watched'), findsNothing);
      expect(find.text('Saved.'), findsOneWidget);
    });

    testWidgets('a 4th mood is refused', (tester) async {
      await pumpDetails(tester, session: _user);
      await openSheet(tester);
      await tester.tap(find.text('Review or log'));
      await tester.pumpAndSettle();

      for (final m in ['Hopeful', 'Happy', 'Calm', 'Excited']) {
        await tester.tap(find.text(m));
        await tester.pump();
      }
      expect(find.textContaining('Pick up to 3 moods'), findsOneWidget);
    });

    testWidgets('x with changes asks before leaving', (tester) async {
      final server = await pumpDetails(tester, session: _user);
      await openSheet(tester);
      await tester.tap(find.text('Review or log'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Calm'));
      await tester.pump();

      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();

      expect(find.text('I Watched'), findsNothing);
      expect(server.entrySaves, isEmpty);
    });

    testWidgets('once logged it says My review and log, and opens it',
        (tester) async {
      final server = FakeServer()
        ..favorite = true
        ..entry = {
          'watchedOn': '2026-11-08',
          'stars': 5,
          'review': 'Wonderful.',
          'spoiler': false,
          'moodIds': [5],
          'updatedAt': '2026-11-08 20:00:00',
        };
      await pumpDetails(tester, server: server, session: _user);
      await openSheet(tester);

      expect(find.text('Review or log'), findsNothing);
      await tester.tap(find.text('My review and log'));
      await tester.pumpAndSettle();

      expect(find.text('Your Review'), findsOneWidget);
      expect(find.text('Thai Nguyen'), findsOneWidget);
      expect(find.text('Watched Nov 8, 2026'), findsOneWidget);
      expect(find.text('Wonderful.'), findsOneWidget);
      expect(find.bySemanticsLabel('5 stars'), findsOneWidget);
      expect(find.bySemanticsLabel('In your Favorites'), findsOneWidget);
    });

    testWidgets('My review: Delete removes it', (tester) async {
      final server = FakeServer()
        ..entry = {
          'watchedOn': null,
          'stars': 3.5,
          'review': null,
          'spoiler': false,
          'moodIds': <int>[],
          'updatedAt': '2026-11-08 20:00:00',
        };
      await pumpDetails(tester, server: server, session: _user);
      await openSheet(tester);
      await tester.tap(find.text('My review and log'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Review options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete your review?'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(server.entryDeleted, isTrue);
      expect(find.text('Your Review'), findsNothing);
    });

    testWidgets('My review: Edit opens the filled-in editor', (tester) async {
      final server = FakeServer()
        ..entry = {
          'watchedOn': null,
          'stars': 2,
          'review': 'Not for me.',
          'spoiler': false,
          'moodIds': [6],
          'updatedAt': '2026-11-08 20:00:00',
        };
      await pumpDetails(tester, server: server, session: _user);
      await openSheet(tester);
      await tester.tap(find.text('My review and log'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Review options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.text('Edit review'), findsOneWidget);
      expect(find.text('Not for me.'), findsOneWidget);
      expect(find.textContaining('Rated 2 stars'), findsOneWidget);
      expect(find.text('Add date'), findsOneWidget);
    });
  });
}
