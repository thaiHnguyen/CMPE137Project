import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/api/api_client.dart';
import 'package:flutter_application_1/auth/auth_controller.dart';
import 'package:flutter_application_1/screens/app_shell.dart';
import 'package:flutter_application_1/screens/lists_screen.dart';
import 'package:flutter_application_1/screens/search_screen.dart';
import 'package:flutter_application_1/theme/noireel_theme.dart';
import 'package:flutter_application_1/theme/theme_controller.dart';

/// A pretend server: search finds "Film 1" to "Film 5"; lists are kept in
/// memory; the user's token is `tok`
class FakeServer {
  final lists = <Map<String, dynamic>>[];
  final posted = <Map<String, dynamic>>[];

  Map<String, Object?> card(int id) => {
        'titleId': id,
        'type': 'movie',
        'name': 'Film $id',
        'year': 2000 + id,
        'posterUrl': null,
      };

  late final client = MockClient((req) async {
    http.Response json(int status, Object body) =>
        http.Response(jsonEncode(body), status);
    final path = req.url.path;

    if (path.startsWith('/me/')) {
      if (req.headers['Authorization'] != 'Bearer tok') {
        return json(401, {'error': 'unauthorized', 'message': 'Log in.'});
      }
    }
    if (path == '/me/lists' && req.method == 'GET') {
      return json(200, {
        'lists': [
          for (final l in lists.reversed)
            {
              'listId': l['listId'],
              'name': l['name'],
              'description': l['description'],
              'entryCount': (l['entries'] as List).length,
              'posterUrls': <String>[],
              'updatedAt': '2026-11-25 13:00:00',
            },
        ],
      });
    }
    if (path == '/me/lists' && req.method == 'POST') {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      posted.add(body);
      final list = {
        'listId': lists.length + 1,
        'name': body['name'],
        'description': body['description'],
        'entries': [
          for (final id in (body['titleIds'] as List).cast<int>()) card(id),
        ],
      };
      lists.add(list);
      return json(201, {'list': list});
    }
    if (path == '/search') {
      return json(200, {
        'total': 5,
        'titles': [for (var i = 1; i <= 5; i++) card(i)],
      });
    }
    if (path == '/discover') return json(200, {'titles': <Object>[]});
    if (path == '/moods') return json(200, {'moods': <Object>[]});
    return http.Response('Route not found', 404);
  });

  ApiClient get api => ApiClient(baseUrl: 'http://test', client: client);
}

const _user = Session(token: 'tok', userId: 1, username: 'thai', role: 'user');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<FakeServer> pumpLists(WidgetTester tester, {Session? session}) async {
    final server = FakeServer();
    await tester.pumpWidget(
      MaterialApp(
        theme: NoiReelPalette.defaultTheme.toThemeData(),
        home: ListsScreen(
          api: server.api,
          auth: AuthController(server.api, session),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return server;
  }

  Future<void> addEntry(WidgetTester tester, String name) async {
    await tester.tap(find.text('Add entries'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'film');
    await tester.pump(SearchScreen.typingPause);
    await tester.pumpAndSettle();
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
  }

  testWidgets('List tab is open first, with Favorite and Watchlist tabs',
      (tester) async {
    await pumpLists(tester, session: _user);

    expect(find.text('Favorite'), findsOneWidget);
    expect(find.text('List'), findsOneWidget);
    expect(find.text('Watchlist'), findsOneWidget);
    expect(find.textContaining("haven't made any lists"), findsOneWidget);
    expect(find.byTooltip('New list'), findsOneWidget);
  });

  testWidgets('guest tapping + gets the sign-in popup', (tester) async {
    await pumpLists(tester);

    await tester.tap(find.byTooltip('New list'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Register or Sign In to your NoiReel account to create a list.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();
    expect(find.text('Username or email'), findsOneWidget); // login page
  });

  testWidgets('create a list: entries keep the order they were added',
      (tester) async {
    final server = await pumpLists(tester, session: _user);

    await tester.tap(find.byTooltip('New list'));
    await tester.pumpAndSettle();
    expect(find.text('New List'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Rainy day');
    await addEntry(tester, 'Film 3');
    await addEntry(tester, 'Film 1');
    expect(find.text('2 entries'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(server.posted.single['name'], 'Rainy day');
    expect(server.posted.single['titleIds'], [3, 1]);
    expect(find.text('Rainy day'), findsOneWidget); // back on the List tab
    expect(find.text('2 entries'), findsOneWidget);
  });

  testWidgets('Done without a name asks for one', (tester) async {
    final server = await pumpLists(tester, session: _user);
    await tester.tap(find.byTooltip('New list'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Give your list a name.'), findsOneWidget);
    expect(server.posted, isEmpty);
  });

  testWidgets('Back with no changes just goes back', (tester) async {
    await pumpLists(tester, session: _user);
    await tester.tap(find.byTooltip('New list'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('New List'), findsNothing);
  });

  testWidgets('Back with changes asks first; No keeps editing',
      (tester) async {
    await pumpLists(tester, session: _user);
    await tester.tap(find.byTooltip('New list'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Half done');

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);

    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();
    expect(find.text('New List'), findsOneWidget);
    expect(find.text('Half done'), findsOneWidget);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    expect(find.text('New List'), findsNothing);
  });

  testWidgets('switching tabs mid-edit asks first', (tester) async {
    final server = FakeServer();
    await tester.pumpWidget(
      MaterialApp(
        theme: NoiReelPalette.defaultTheme.toThemeData(),
        home: AppShell(
          api: server.api,
          themes: ThemeController(),
          auth: AuthController(server.api, _user),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.bookmarks_outlined)); // Lists tab
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('New list'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Half done');

    // No: stay on the Lists tab, still editing
    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();
    expect(find.text('New List'), findsOneWidget);

    // Yes: the edit is thrown away and Home opens
    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    expect(find.text('Discovery'), findsOneWidget);

    // Back on Lists: the editor is gone
    await tester.tap(find.byIcon(Icons.bookmarks_outlined));
    await tester.pumpAndSettle();
    expect(find.text('New List'), findsNothing);
    expect(server.posted, isEmpty);
  });
}
