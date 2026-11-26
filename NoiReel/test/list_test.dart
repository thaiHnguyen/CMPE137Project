import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/api/api_client.dart';
import 'package:flutter_application_1/auth/auth_controller.dart';
import 'package:flutter_application_1/screens/app_shell.dart';
import 'package:flutter_application_1/screens/new_list_screen.dart';
import 'package:flutter_application_1/screens/profile_screen.dart';
import 'package:flutter_application_1/screens/search_screen.dart';
import 'package:flutter_application_1/theme/noireel_theme.dart';
import 'package:flutter_application_1/theme/theme_controller.dart';

/// A pretend server: search finds "Film 1" to "Film 5"; lists are kept in
/// memory; the user's token is `tok`
class FakeServer {
  final lists = <Map<String, dynamic>>[];
  final posted = <Map<String, dynamic>>[];
  final saved = <Map<String, dynamic>>[]; // PUT bodies
  final deleted = <int>[];

  /// Adds a list as if it had been made earlier
  void seed(String name, List<int> titleIds, {String? description}) {
    lists.add({
      'listId': lists.length + 1,
      'name': name,
      'description': description,
      'entries': [for (final id in titleIds) card(id)],
    });
  }

  Map<String, dynamic>? byId(int id) =>
      lists.where((l) => l['listId'] == id).firstOrNull;

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
    final one = RegExp(r'^/me/lists/(\d+)$').firstMatch(path);
    if (one != null) {
      final id = int.parse(one.group(1)!);
      final list = byId(id);
      if (list == null) {
        return json(404, {'error': 'not_found', 'message': 'No such list.'});
      }
      if (req.method == 'DELETE') {
        deleted.add(id);
        lists.remove(list);
        return http.Response('', 204);
      }
      if (req.method == 'PUT') {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        saved.add(body);
        list
          ..['name'] = body['name']
          ..['description'] = body['description']
          ..['entries'] = [
            for (final id in (body['titleIds'] as List).cast<int>()) card(id),
          ];
      }
      return json(200, {'list': list});
    }
    if (path == '/search') {
      return json(200, {
        'total': 5,
        'titles': [for (var i = 1; i <= 5; i++) card(i)],
      });
    }
    if (path == '/me/profile') {
      return json(200, {
        'profile': {
          'userId': 1,
          'username': 'thai',
          'email': 'thai@example.com',
          'goat': [null, null, null, null, null],
        },
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
        home: ProfileScreen(
          api: server.api,
          auth: AuthController(server.api, session),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('List')); // the List tab on Profile
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

  testWidgets('Profile has Profile, Favorite, List and Watchlist tabs',
      (tester) async {
    await pumpLists(tester, session: _user);

    expect(find.text('Profile'), findsOneWidget);
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
    await tester.pump(); // let the page see the change

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

    await tester.tap(find.byIcon(Icons.person_outlined)); // Profile tab
    await tester.pumpAndSettle();
    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('New list'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Half done');

    // No: stay on Profile, still editing
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

    // Back on Profile: the editor is gone
    await tester.tap(find.byIcon(Icons.person_outlined));
    await tester.pumpAndSettle();
    expect(find.text('New List'), findsNothing);
    expect(server.posted, isEmpty);
  });

  group("a list's ... menu", () {
    /// Opens "Rainy day" (Film 1, 2, 3) from the List tab
    Future<FakeServer> openList(WidgetTester tester) async {
      final server = FakeServer()
        ..seed('Rainy day', [1, 2, 3], description: 'Cozy');
      await tester.pumpWidget(
        MaterialApp(
          theme: NoiReelPalette.defaultTheme.toThemeData(),
          home: ProfileScreen(
            api: server.api,
            auth: AuthController(server.api, _user),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('List'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rainy day'));
      await tester.pumpAndSettle();
      return server;
    }

    /// An entry in the editor, by its "position. name" label
    Finder poster(String label) => find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == label,
        );

    Future<void> chooseFromMenu(WidgetTester tester, String option) async {
      await tester.tap(find.byTooltip('List options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(option));
      await tester.pumpAndSettle();
    }

    testWidgets('has Edit and Delete', (tester) async {
      await openList(tester);
      await tester.tap(find.byTooltip('List options'));
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('Edit opens the list with Cancel and Done', (tester) async {
      await openList(tester);
      await chooseFromMenu(tester, 'Edit');

      expect(find.text('Edit List'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Rainy day'), findsOneWidget);
      expect(find.text('Cozy'), findsOneWidget);
      expect(find.text('3 entries'), findsOneWidget);
    });

    testWidgets('Cancel without changes just closes', (tester) async {
      await openList(tester);
      await chooseFromMenu(tester, 'Edit');

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('Edit List'), findsNothing);
    });

    testWidgets('Cancel after changes asks first; Yes throws them away',
        (tester) async {
      final server = await openList(tester);
      await chooseFromMenu(tester, 'Edit');
      await tester.enterText(find.byType(TextField), 'Sunny day');
      await tester.pump(); // let the page see the change

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('No'));
      await tester.pumpAndSettle();
      expect(find.text('Sunny day'), findsOneWidget); // still editing

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();
      expect(find.text('Edit List'), findsNothing);
      expect(find.text('Rainy day'), findsOneWidget); // unchanged
      expect(server.saved, isEmpty);
    });

    testWidgets('Done saves the new name and shows it', (tester) async {
      final server = await openList(tester);
      await chooseFromMenu(tester, 'Edit');
      await tester.enterText(find.byType(TextField), 'Sunny day');
      await tester.pump(); // let the page see the change

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(server.saved.single['name'], 'Sunny day');
      expect(server.saved.single['titleIds'], [1, 2, 3]);
      expect(find.text('Sunny day'), findsOneWidget); // on the list's page
    });

    testWidgets('holding a poster 1.5s then dragging moves it',
        (tester) async {
      final server = await openList(tester);
      await chooseFromMenu(tester, 'Edit');

      final first = tester.getCenter(poster('1. Film 1'));
      final third = tester.getCenter(poster('3. Film 3'));

      final gesture = await tester.startGesture(first);
      await tester.pump(NewListScreen.holdToDrag);
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveTo(third);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(server.saved.single['titleIds'], [2, 3, 1]);
    });

    testWidgets('a short hold does not drag', (tester) async {
      final server = await openList(tester);
      await chooseFromMenu(tester, 'Edit');

      final first = tester.getCenter(poster('1. Film 1'));
      final third = tester.getCenter(poster('3. Film 3'));

      final gesture = await tester.startGesture(first);
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveTo(third);
      await gesture.up();
      await tester.pumpAndSettle();

      // Nothing moved, so Cancel just closes
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsNothing);
      expect(server.saved, isEmpty);
    });

    testWidgets('Delete asks first; Cancel keeps the list', (tester) async {
      final server = await openList(tester);
      await chooseFromMenu(tester, 'Delete');

      expect(find.text('Delete the list?'), findsOneWidget);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(server.deleted, isEmpty);
      expect(find.text('Rainy day'), findsOneWidget);
    });

    testWidgets('Delete removes it and goes back to the List tab',
        (tester) async {
      final server = await openList(tester);
      await chooseFromMenu(tester, 'Delete');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(server.deleted, [1]);
      expect(find.text('"Rainy day" deleted.'), findsOneWidget);
      expect(find.textContaining("haven't made any lists"), findsOneWidget);
    });
  });
}