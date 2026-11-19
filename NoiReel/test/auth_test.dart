import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/api/api_client.dart';
import 'package:flutter_application_1/auth/auth_controller.dart';
import 'package:flutter_application_1/auth/validators.dart';
import 'package:flutter_application_1/screens/profile_screen.dart';
import 'package:flutter_application_1/theme/noireel_theme.dart';

/// A pretend NoiReel server: account `thai` / `demo1234`, token `tok`
class FakeServer {
  bool sessionValid = true;
  bool reachable = true;
  final calls = <String>[];

  late final client = MockClient((req) async {
    calls.add('${req.method} ${req.url.path}');
    if (!reachable) throw const SocketExceptionLike();
    final body = req.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(req.body) as Map<String, dynamic>;
    http.Response json(int status, Map<String, Object?> data) =>
        http.Response(jsonEncode(data), status);

    switch ('${req.method} ${req.url.path}') {
      case 'POST /auth/login':
        if (body['login'] == 'locked') {
          return json(423, {
            'error': 'locked',
            'message': 'Too many failed attempts. Try again in 15 minutes.',
          });
        }
        if (body['login'] == 'banned') {
          return json(403, {'error': 'banned', 'reason': 'Spam'});
        }
        if (body['password'] != 'demo1234') {
          return json(401, {
            'error': 'incorrect',
            'message': 'Incorrect username or password',
          });
        }
        return json(200, {'token': 'tok', 'userId': 1, 'role': 'user'});
      case 'POST /auth/register':
        if (body['username'] == 'taken_name') {
          return json(409, {
            'error': 'taken',
            'field': 'username',
            'message': 'That username is already in use.',
          });
        }
        return json(201, {'token': 'new', 'userId': 2, 'role': 'user'});
      case 'GET /auth/session':
        if (!sessionValid) return json(401, {'status': 'expired'});
        return json(200, {
          'status': 'valid',
          'userId': 1,
          'username': 'thai',
          'role': 'user',
        });
      case 'POST /auth/logout':
        return http.Response('', 204);
    }
    return http.Response('Route not found', 404);
  });

  ApiClient get api => ApiClient(baseUrl: 'http://test', client: client);
}

/// Stands in for a network error
class SocketExceptionLike implements Exception {
  const SocketExceptionLike();
}

const _saved = {
  'session': '{"token":"tok","userId":1,"username":"thai","role":"user"}',
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AuthController', () {
    test('log in with an email still shows the username', () async {
      final server = FakeServer();
      final auth = AuthController(server.api);

      await auth.login('thai@example.com', 'demo1234');

      expect(auth.value!.username, 'thai');
      expect(auth.value!.token, 'tok');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('session'), contains('"username":"thai"'));
    });

    test('wrong password: no session, server message', () async {
      final auth = AuthController(FakeServer().api);
      await expectLater(
        auth.login('thai', 'nope1234'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.error, 'error', 'incorrect')
              .having((e) => e.message, 'message', contains('Incorrect')),
        ),
      );
      expect(auth.value, isNull);
    });

    test('a taken username names the field', () async {
      final auth = AuthController(FakeServer().api);
      await expectLater(
        auth.register(
          email: 'a@b.co',
          username: 'taken_name',
          password: 'demo1234',
        ),
        throwsA(
          isA<ApiException>().having((e) => e.field, 'field', 'username'),
        ),
      );
    });

    test('register logs the new account in', () async {
      final auth = AuthController(FakeServer().api);
      await auth.register(
        email: ' New@Example.com ',
        username: 'newbie',
        password: 'demo1234',
      );
      expect(auth.value!.username, 'newbie');
      expect(auth.value!.token, 'new');
    });

    test('stays logged in after a restart', () async {
      SharedPreferences.setMockInitialValues(_saved);
      final auth = await AuthController.load(FakeServer().api);
      expect(auth.value!.username, 'thai');
    });

    test('an expired saved session goes back to guest', () async {
      SharedPreferences.setMockInitialValues(_saved);
      final server = FakeServer()..sessionValid = false;

      final auth = await AuthController.load(server.api);
      expect(auth.value, isNotNull); // shown right away...
      await pumpEventQueue();
      expect(auth.value, isNull); // ...until the server says it expired
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('session'), isNull);
    });

    test('server unreachable: keeps the saved session', () async {
      SharedPreferences.setMockInitialValues(_saved);
      final server = FakeServer()..reachable = false;

      final auth = await AuthController.load(server.api);
      await pumpEventQueue();
      expect(auth.value!.username, 'thai');
    });

    test('log out forgets the session even if the server is down', () async {
      SharedPreferences.setMockInitialValues(_saved);
      final server = FakeServer()..reachable = false;
      final auth = await AuthController.load(server.api);

      await auth.logout();

      expect(auth.value, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('session'), isNull);
    });
  });

  group('validators match the server', () {
    test('email', () {
      expect(checkEmail('a@b.co'), isNull);
      expect(checkEmail('nope'), isNotNull);
      expect(checkEmail(''), isNotNull);
    });
    test('username', () {
      expect(checkUsername('thai_n2'), isNull);
      expect(checkUsername('ab'), isNotNull);
      expect(checkUsername('has space'), isNotNull);
      expect(checkUsername('a' * 21), isNotNull);
    });
    test('password', () {
      expect(checkNewPassword('demo1234'), isNull);
      expect(checkNewPassword('demo123'), isNotNull); // 7 characters
      expect(checkNewPassword('abcdefgh'), isNotNull); // no digit
      expect(checkNewPassword('12345678'), isNotNull); // no letter
      expect(checkNewPassword('a1${'x' * 71}'), isNotNull); // over 72 bytes
    });
  });

  group('Profile tab', () {
    Future<AuthController> pumpProfile(WidgetTester tester) async {
      final auth = AuthController(FakeServer().api);
      await tester.pumpWidget(
        MaterialApp(
          theme: NoiReelPalette.defaultTheme.toThemeData(),
          home: ProfileScreen(auth: auth),
        ),
      );
      await tester.pumpAndSettle();
      return auth;
    }

    testWidgets('guest can log in and then log out', (tester) async {
      final auth = await pumpProfile(tester);
      expect(find.text('Join NoiReel'), findsOneWidget);

      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'thai');
      await tester.enterText(find.byType(TextFormField).at(1), 'demo1234');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Log in'));
      await tester.pumpAndSettle();

      expect(find.text('@thai'), findsOneWidget); // back on Profile
      expect(auth.isLoggedIn, isTrue);

      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();
      expect(find.text('Join NoiReel'), findsOneWidget);
    });

    testWidgets('wrong password shows the server message', (tester) async {
      await pumpProfile(tester);
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'thai');
      await tester.enterText(find.byType(TextFormField).at(1), 'wrong999');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Log in'));
      await tester.pumpAndSettle();

      expect(find.text('Incorrect username or password'), findsOneWidget);
    });

    testWidgets('banned account shows the reason', (tester) async {
      await pumpProfile(tester);
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'banned');
      await tester.enterText(find.byType(TextFormField).at(1), 'demo1234');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Log in'));
      await tester.pumpAndSettle();

      expect(find.textContaining('banned. Reason: Spam'), findsOneWidget);
    });

    testWidgets('sign-up form checks fields before sending', (tester) async {
      await pumpProfile(tester);
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'not-an-email');
      await tester.enterText(find.byType(TextFormField).at(1), 'ab');
      await tester.enterText(find.byType(TextFormField).at(2), 'short');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create account'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(
        find.text('Use 3-20 letters, digits or underscores.'),
        findsOneWidget,
      );
      expect(
        find.text('Use at least 8 characters with a letter and a digit.'),
        findsOneWidget,
      );
    });

    testWidgets('a taken username shows under that field', (tester) async {
      await pumpProfile(tester);
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'a@b.co');
      await tester.enterText(find.byType(TextFormField).at(1), 'taken_name');
      await tester.enterText(find.byType(TextFormField).at(2), 'demo1234');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create account'));
      await tester.pumpAndSettle();

      expect(find.text('That username is already in use.'), findsOneWidget);

      // Editing the field clears it
      await tester.enterText(find.byType(TextFormField).at(1), 'other_name');
      await tester.pumpAndSettle(); // error text fades out over ~150 ms
      expect(find.text('That username is already in use.'), findsNothing);
    });
  });
}