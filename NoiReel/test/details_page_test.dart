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
    http.Response json(int status, Object body) =>
        http.Response(jsonEncode(body), status);
    switch ('${req.method} ${req.url.path}') {
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
    expect(find.text('Calm'), findsWidgets); // tag and vote bar
    expect(find.text('RATINGS'), findsOneWidget);
    expect(find.text('No ratings yet.'), findsOneWidget);
    expect(find.text('–'), findsOneWidget);
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

  group('⋮ Add to a list', () {
    Future<void> chooseAddToList(WidgetTester tester) async {
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to a list'));
      await tester.pumpAndSettle();
    }

    testWidgets('a guest is asked to sign in', (tester) async {
      await pumpDetails(tester);
      await chooseAddToList(tester);

      expect(
        find.text(
          'Register or Sign In to your NoiReel account to add titles to a '
          'list.',
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
}
