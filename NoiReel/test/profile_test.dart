import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/api/api_client.dart';
import 'package:flutter_application_1/auth/auth_controller.dart';
import 'package:flutter_application_1/screens/profile_screen.dart';
import 'package:flutter_application_1/screens/search_screen.dart';
import 'package:flutter_application_1/theme/noireel_theme.dart';

/// A pretend server holding one profile (user `thai`, token `tok`).
/// Search finds "Film 1" to "Film 5"
class FakeServer {
  final profile = <String, dynamic>{
    'userId': 1,
    'username': 'thai',
    'email': 'thai@example.com',
    'role': 'user',
    'displayName': 'Thai Nguyen',
    'bio': 'Ozu and Wong Kar-wai forever.',
    'pronoun': 'he/him',
    'avatarUrl': null,
    'goat': <Object?>[null, null, null, null, null],
  };
  final profileSaves = <Map<String, dynamic>>[]; // PUT /me/profile bodies
  final goatSaves = <List<Object?>>[];            // PUT /me/profile/goat
  final avatarUploads = <String>[];               // POST content types

  Map<String, Object?> card(int id) => {
    'titleId': id,
    'type': 'movie',
    'name': 'Film $id',
    'year': 2000 + id,
    'posterUrl': null,
  };

  late final client = MockClient((req) async {
    // UTF-8 with a charset, like the real server (the default is
    // Latin-1, which can't hold titles like 菊次郎の夏)
    http.Response json(int status, Object body) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
    final route = '${req.method} ${req.url.path}';

    if (req.url.path.startsWith('/me/') &&
        req.headers['Authorization'] != 'Bearer tok') {
      return json(401, {'error': 'unauthorized', 'message': 'Log in.'});
    }
    switch (route) {
      case 'GET /me/profile':
        return json(200, {'profile': profile});
      case 'PUT /me/profile':
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        profileSaves.add(body);
        if (body['email'] == 'taken@example.com') {
          return json(409, {
            'error': 'taken',
            'field': 'email',
            'message': 'That email is already used by another account.',
          });
        }
        String? blankToNull(Object? v) =>
            v is String && v.trim().isNotEmpty ? v.trim() : null;
        profile
          ..['displayName'] = blankToNull(body['displayName'])
          ..['bio'] = blankToNull(body['bio'])
          ..['pronoun'] = body['pronoun']
          ..['email'] = body['email'];
        return json(200, {'profile': profile});
      case 'PUT /me/profile/goat':
        final ids = (jsonDecode(req.body) as Map)['titleIds'] as List;
        goatSaves.add(ids);
        profile['goat'] = [for (final id in ids) id == null ? null : card(id)];
        return json(200, {'profile': profile});
      case 'POST /me/profile/avatar':
        avatarUploads.add(req.headers['content-type'] ?? '');
        profile['avatarUrl'] = '/avatars/1-123.jpg';
        return json(200, {'profile': profile});
      case 'DELETE /me/profile/avatar':
        profile['avatarUrl'] = null;
        return json(200, {'profile': profile});
      case 'GET /search':
        return json(200, {
          'total': 5,
          'titles': [for (var i = 1; i <= 5; i++) card(i)],
        });
      case 'GET /me/lists':
        return json(200, {'lists': <Object>[]});
      case 'POST /auth/logout':
        return http.Response('', 204);
    }
    return http.Response('Route not found', 404);
  });

  ApiClient get api => ApiClient(baseUrl: 'http://test', client: client);
}

/// A real 1x1 pixel PNG, so the photo preview can draw it
const _tinyPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

const _user = Session(token: 'tok', userId: 1, username: 'thai', role: 'user');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<FakeServer> pumpProfile(
    WidgetTester tester, {
    Session? session = _user,
    FakeServer? server,
  }) async {
    server ??= FakeServer();
    await tester.pumpWidget(
      MaterialApp(
        theme: NoiReelPalette.defaultTheme.toThemeData(),
        home: ProfileScreen(
          api: server.api,
          auth: AuthController(server.api, session),
          // A 1x1 PNG "photo", instead of opening the phone's library
          pickPhoto: () async => base64Decode(_tinyPng),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return server;
  }

  /// A Greatest Of All Time spot, by its screen-reader label
  Finder spot(int number, [String? name]) => find.bySemanticsLabel(
    name == null
        ? 'Greatest of all time, spot $number, empty'
        : 'Greatest of all time, spot $number: $name',
  );

  Future<void> pickFromSearch(WidgetTester tester, String name) async {
    await tester.enterText(find.byType(TextField), 'film');
    await tester.pump(SearchScreen.typingPause);
    await tester.pumpAndSettle();
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
  }

  group('Profile tab', () {
    testWidgets('shows Settings, the name, pronoun, bio and 5 GOAT spots',
        (tester) async {
      await pumpProfile(tester);

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Thai Nguyen'), findsNWidgets(2)); // app bar + page
      expect(find.text('@thai  ·  He / him'), findsOneWidget);
      expect(find.text('Ozu and Wong Kar-wai forever.'), findsOneWidget);
      expect(find.text('GREATEST OF ALL TIME'), findsOneWidget);
      for (var i = 1; i <= 5; i++) {
        expect(spot(i), findsOneWidget);
      }
    });

    testWidgets('a guest sees Join NoiReel and no Settings', (tester) async {
      await pumpProfile(tester, session: null);

      expect(find.text('Join NoiReel'), findsOneWidget);
      expect(find.text('Settings'), findsNothing);
      expect(find.text('List'), findsOneWidget); // tabs are still there
    });

    testWidgets('tapping an empty spot picks a title for it', (tester) async {
      final server = await pumpProfile(tester);

      await tester.tap(spot(3));
      await tester.pumpAndSettle();
      expect(find.text('Pick a title'), findsOneWidget);
      await pickFromSearch(tester, 'Film 2');

      expect(server.goatSaves.single, [null, null, 2, null, null]);
      expect(spot(3, 'Film 2'), findsOneWidget);
    });

    testWidgets("a title can't fill two spots", (tester) async {
      final server = FakeServer();
      server.profile['goat'] = [server.card(4), null, null, null, null];
      await pumpProfile(tester, server: server);

      await tester.tap(spot(2));
      await tester.pumpAndSettle();
      await pickFromSearch(tester, 'Film 4');

      expect(
        find.text('Film 4 is already in your Greatest Of All Time.'),
        findsOneWidget,
      );
      expect(find.text('Pick a title'), findsOneWidget); // still searching
      expect(server.goatSaves, isEmpty);
    });

    testWidgets('a filled spot can be removed', (tester) async {
      final server = FakeServer();
      server.profile['goat'] = [null, server.card(5), null, null, null];
      await pumpProfile(tester, server: server);

      await tester.tap(spot(2, 'Film 5'));
      await tester.pumpAndSettle();
      expect(find.text('View details'), findsOneWidget);
      expect(find.text('Replace'), findsOneWidget);
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(server.goatSaves.single, [null, null, null, null, null]);
      expect(spot(2), findsOneWidget);
    });
  });

  group('Profile Settings', () {
    Future<FakeServer> openSettings(WidgetTester tester) async {
      final server = await pumpProfile(tester);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      return server;
    }

    Finder field(String label) => find.widgetWithText(TextField, label);

    testWidgets('starts with the saved profile', (tester) async {
      await openSettings(tester);

      expect(find.text('Profile Settings'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
      expect(find.text('Thai Nguyen'), findsOneWidget); // in the Name field
      expect(find.text('thai@example.com'), findsOneWidget);
      expect(find.text('Ozu and Wong Kar-wai forever.'), findsOneWidget);
      expect(find.text('He / him'), findsOneWidget);
      expect(find.byTooltip('Cancel'), findsOneWidget);
      expect(find.byTooltip('Save'), findsOneWidget);
    });

    testWidgets('✓ saves, and Profile shows the changes', (tester) async {
      final server = await openSettings(tester);

      await tester.enterText(field('Name'), 'Thai N.');
      await tester.enterText(field('Bio'), 'Mood first.');
      // The pronoun menu is below the bottom of the test screen
      await tester.ensureVisible(find.text('He / him'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('He / him'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('They / them').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Save'));
      await tester.pumpAndSettle();

      expect(server.profileSaves.single, {
        'displayName': 'Thai N.',
        'bio': 'Mood first.',
        'pronoun': 'they/them',
        'email': 'thai@example.com',
      });
      expect(find.text('Profile Settings'), findsNothing);
      expect(find.text('Profile saved.'), findsOneWidget);
      expect(find.text('@thai  ·  They / them'), findsOneWidget);
      expect(find.text('Mood first.'), findsOneWidget);
    });

    testWidgets('a taken email shows under the field', (tester) async {
      await openSettings(tester);

      await tester.enterText(field('Email Address'), 'taken@example.com');
      await tester.tap(find.byTooltip('Save'));
      await tester.pumpAndSettle();

      expect(
        find.text('That email is already used by another account.'),
        findsOneWidget,
      );
      expect(find.text('Profile Settings'), findsOneWidget); // still open
    });

    testWidgets('✕ with changes asks first', (tester) async {
      final server = await openSettings(tester);
      await tester.enterText(field('Name'), 'Someone else');
      await tester.pump(); // let the page see the change

      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('No'));
      await tester.pumpAndSettle();
      expect(find.text('Someone else'), findsOneWidget);

      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();
      expect(find.text('Profile Settings'), findsNothing);
      expect(server.profileSaves, isEmpty);
    });

    testWidgets('✕ without changes just closes', (tester) async {
      await openSettings(tester);

      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('Profile Settings'), findsNothing);
    });

    testWidgets('a new photo uploads when saving', (tester) async {
      final server = await openSettings(tester);

      await tester.tap(find.text('Add photo'));
      await tester.pumpAndSettle();
      expect(find.text('Remove photo'), findsOneWidget);
      expect(server.avatarUploads, isEmpty); // not until ✓

      await tester.tap(find.byTooltip('Save'));
      await tester.pumpAndSettle();
      expect(server.avatarUploads.single, startsWith('multipart/form-data'));
      expect(server.profile['avatarUrl'], '/avatars/1-123.jpg');
    });

    testWidgets('Sign out goes back to the guest view', (tester) async {
      await openSettings(tester);

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      expect(find.text('Join NoiReel'), findsOneWidget);
    });
  });
}