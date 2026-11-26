import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_application_1/api/api_client.dart';
import 'package:flutter_application_1/auth/auth_controller.dart';
import 'package:flutter_application_1/screens/app_shell.dart';
import 'package:flutter_application_1/theme/noireel_theme.dart';
import 'package:flutter_application_1/theme/theme_controller.dart';
import 'package:flutter_application_1/widgets/nav_bar.dart';

void main() {
  final calm = NoiReelPalette.byName('Calm');

  Widget barApp({required int current, ValueChanged<int>? onTap}) =>
      MaterialApp(
        theme: calm.toThemeData(),
        home: Scaffold(
          bottomNavigationBar: NoiReelNavBar(
            currentIndex: current,
            onTap: onTap ?? (_) {},
          ),
        ),
      );

  Icon iconOf(WidgetTester tester, IconData data) =>
      tester.widget<Icon>(find.byIcon(data));

  testWidgets('selected tab is filled and in full nav text color',
      (tester) async {
    await tester.pumpWidget(barApp(current: 2));

    final mood = iconOf(tester, Icons.theater_comedy);
    expect(mood.color, calm.navText);
    expect(find.byIcon(Icons.theater_comedy_outlined), findsNothing);
  });

  testWidgets('other tabs are outlined and dimmed', (tester) async {
    await tester.pumpWidget(barApp(current: 2));

    for (final tab in navTabs.where((t) => t.label != 'Mood')) {
      final icon = iconOf(tester, tab.icon);
      expect(icon.color, isNot(calm.navText), reason: tab.label);
      expect(icon.color!.a, closeTo(NoiReelNavBar.unselectedOpacity, 0.01));
    }
  });

  testWidgets('tapping a tab reports its index', (tester) async {
    int? tapped;
    await tester.pumpWidget(barApp(current: 0, onTap: (i) => tapped = i));

    await tester.tap(find.byIcon(Icons.explore_outlined)); // Pick for me
    expect(tapped, 3);
  });

  testWidgets('the bar spans the full width of the screen', (tester) async {
    await tester.pumpWidget(barApp(current: 0));

    final bar = tester.getRect(find.byType(NoiReelNavBar));
    final screen = tester.getRect(find.byType(Scaffold));
    expect(bar.left, screen.left);
    expect(bar.right, screen.right);
    expect(bar.bottom, screen.bottom);
  });

  group('shell', () {
    // A pretend server: 3 random titles for Discovery, no moods
    late int discoverCalls;
    late ApiClient api;

    setUp(() {
      discoverCalls = 0;
      api = ApiClient(
        baseUrl: 'http://test',
        client: MockClient((req) async {
          if (req.url.path == '/discover') {
            discoverCalls++;
            return http.Response(
              jsonEncode({
                'titles': [
                  for (var i = 1; i <= 3; i++)
                    {
                      'titleId': i,
                      'type': 'movie',
                      'name': 'Film $i',
                      'year': 2000 + i,
                      'posterUrl': null,
                    },
                ],
              }),
              200,
            );
          }
          return http.Response(jsonEncode({'moods': <Object>[]}), 200);
        }),
      );
    });

    Future<void> pumpShell(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: calm.toThemeData(),
          home: AppShell(
            api: api,
            themes: ThemeController(calm),
            auth: AuthController(api), // guest
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('Home shows the Discovery grid', (tester) async {
      await pumpShell(tester);

      expect(find.text('Discovery'), findsOneWidget);
      expect(find.byTooltip('Film 1'), findsOneWidget);
      expect(find.byTooltip('Film 3'), findsOneWidget);
    });

    testWidgets('switching tabs shows that tab and keeps the bar',
        (tester) async {
      await pumpShell(tester);

      await tester.tap(find.byIcon(Icons.search_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Find a movie or show'), findsOneWidget);
      expect(find.byIcon(Icons.home_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.theater_comedy_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Browse by mood'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.home_outlined));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.home), findsOneWidget);
      expect(find.text('Discovery'), findsOneWidget);
    });

    testWidgets('tapping Home reshuffles the grid', (tester) async {
      await pumpShell(tester);
      expect(discoverCalls, 1);

      // Already on Home: tap it again
      await tester.tap(find.byIcon(Icons.home));
      await tester.pumpAndSettle();
      expect(discoverCalls, 2);

      // Coming back to Home from another tab
      await tester.tap(find.byIcon(Icons.search_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.home_outlined));
      await tester.pumpAndSettle();
      expect(discoverCalls, 3);
    });
  });
}
