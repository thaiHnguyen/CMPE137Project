import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_application_1/api/api_client.dart';
import 'package:flutter_application_1/screens/mood_screen.dart';
import 'package:flutter_application_1/theme/noireel_theme.dart';
import 'package:flutter_application_1/widgets/theme_picker.dart';

/// A pretend server with one mood, Calm, that has 70 titles
class FakeMoods {
  static const total = 70;
  final shuffles = <String?>[]; // `shuffle` sent with each mood-page call

  late final client = MockClient((req) async {
    final q = req.url.queryParameters;
    if (req.url.path == '/moods') {
      return http.Response(
        jsonEncode({
          'moods': [
            {
              'moodId': 5,
              'name': 'Calm',
              'description': 'Slow and soothing',
              'colorHex': null,
              'counterMoodIds': [6],
            },
          ],
        }),
        200,
      );
    }
    if (req.url.path == '/moods/5/titles') {
      if (q.containsKey('shuffle')) shuffles.add(q['shuffle']);
      final page = int.parse(q['page'] ?? '1');
      final limit = int.parse(q['limit'] ?? '20');
      final start = (page - 1) * limit;
      final count = (total - start).clamp(0, limit);
      return http.Response(
        jsonEncode({
          'page': page,
          'limit': limit,
          'total': total,
          'titles': [
            for (var i = start; i < start + count; i++)
              {
                'titleId': i + 1,
                'type': 'movie',
                'name': 'Calm film ${i + 1}',
                'year': 2000,
                'posterUrl': null,
              },
          ],
        }),
        200,
      );
    }
    return http.Response('Route not found', 404);
  });

  ApiClient get api => ApiClient(baseUrl: 'http://test', client: client);
}

void main() {
  Future<FakeMoods> pumpMoodTab(WidgetTester tester) async {
    final server = FakeMoods();
    await tester.pumpWidget(
      MaterialApp(
        theme: NoiReelPalette.defaultTheme.toThemeData(),
        home: MoodScreen(api: server.api),
      ),
    );
    await tester.pumpAndSettle();
    return server;
  }

  Future<void> openCalm(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
  }

  testWidgets('mood rows have a color square and a ›', (tester) async {
    await pumpMoodTab(tester);

    expect(find.text('Calm'), findsOneWidget);
    expect(find.byType(MoodSwatch), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('tapping the heading opens the mood page with Back',
      (tester) async {
    await pumpMoodTab(tester);
    await openCalm(tester);

    expect(find.text('Back'), findsOneWidget);
    expect(find.text('Slow and soothing'), findsOneWidget);
    expect(find.text('70 titles'), findsOneWidget);
    expect(find.byTooltip('Calm film 1'), findsOneWidget);
  });

  testWidgets('scrolling loads every title, in one shuffle', (tester) async {
    final server = await pumpMoodTab(tester);
    await openCalm(tester);

    await tester.dragUntilVisible(
      find.textContaining("That's every Calm title"),
      find.byType(CustomScrollView),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();

    expect(server.shuffles.length, 3); // 30 + 30 + 10
    expect(server.shuffles.toSet().length, 1); // same number every page
  });

  testWidgets('pulling down reshuffles', (tester) async {
    final server = await pumpMoodTab(tester);
    await openCalm(tester);
    final first = server.shuffles.single;

    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, 500),
      1000,
    );
    await tester.pumpAndSettle();

    expect(server.shuffles.length, 2);
    expect(server.shuffles.last, isNot(first));
  });

  testWidgets('Back returns to the Mood tab', (tester) async {
    await pumpMoodTab(tester);
    await openCalm(tester);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Browse by mood'), findsOneWidget);
    expect(find.text('Back'), findsNothing);
  });
}
