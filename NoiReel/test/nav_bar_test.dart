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

    await tester.tap(find.text('Lists'));
    expect(tapped, 3);
  });

  testWidgets('switching tabs shows that tab and keeps the bar',
      (tester) async {
    // A fake server with no moods, so the home page loads instantly
    final api = ApiClient(
      baseUrl: 'http://test',
      client: MockClient(
        (_) async => http.Response(jsonEncode({'moods': <Object>[]}), 200),
      ),
    );
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
    expect(find.textContaining('No moods yet'), findsOneWidget);

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(find.text('Find a movie or show'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsWidgets); // filled = selected
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.home), findsOneWidget);
    expect(find.textContaining('No moods yet'), findsOneWidget);
  });
}
