import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_application_1/api/api_client.dart';
import 'package:flutter_application_1/screens/search_screen.dart';
import 'package:flutter_application_1/theme/noireel_theme.dart';

/// A pretend server. "nolan" matches 45 titles (3 pages of 20); anything
/// else matches nothing. "down" fails as if the server were off
class FakeSearch {
  final requests = <Uri>[];
  Duration delayFor(String q) => Duration.zero;

  late final client = MockClient((req) async {
    requests.add(req.url);
    final q = req.url.queryParameters['q'] ?? '';
    final page = int.parse(req.url.queryParameters['page'] ?? '1');
    final limit = int.parse(req.url.queryParameters['limit'] ?? '20');
    await Future<void>.delayed(delayFor(q));
    if (q == 'down') throw const _Offline();

    final total = q == 'nolan' ? 45 : 0;
    final start = (page - 1) * limit;
    final count = (total - start).clamp(0, limit);
    return http.Response(
      jsonEncode({
        'query': q,
        'page': page,
        'limit': limit,
        'total': total,
        'titles': [
          for (var i = start; i < start + count; i++)
            {
              'titleId': i + 1,
              'type': i.isEven ? 'movie' : 'tv',
              'name': '$q film ${i + 1}',
              'year': 2000 + i,
              'posterUrl': null,
            },
        ],
      }),
      200,
    );
  });

  ApiClient get api => ApiClient(baseUrl: 'http://test', client: client);
}

class _Offline implements Exception {
  const _Offline();
}

void main() {
  Future<FakeSearch> pumpSearch(WidgetTester tester, [FakeSearch? fake]) async {
    final server = fake ?? FakeSearch();
    await tester.pumpWidget(
      MaterialApp(
        theme: NoiReelPalette.defaultTheme.toThemeData(),
        home: SearchScreen(api: server.api),
      ),
    );
    await tester.pumpAndSettle();
    return server;
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump(SearchScreen.typingPause); // finished typing
    await tester.pumpAndSettle();
  }

  testWidgets('shows a hint before searching', (tester) async {
    await pumpSearch(tester);
    expect(find.text('Find a movie or show'), findsOneWidget);
  });

  testWidgets('shows results with year and type', (tester) async {
    await pumpSearch(tester);
    await type(tester, 'nolan');

    expect(find.text('45 results'), findsOneWidget);
    expect(find.text('nolan film 1'), findsOneWidget);
    expect(find.text('2000  ·  Movie'), findsOneWidget);
    expect(find.text('2001  ·  TV show'), findsOneWidget);
  });

  testWidgets('waits for a pause in typing before searching', (tester) async {
    final server = await pumpSearch(tester);

    for (final text in ['n', 'no', 'nol', 'nola', 'nolan']) {
      await tester.enterText(find.byType(TextField), text);
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(SearchScreen.typingPause);
    await tester.pumpAndSettle();

    expect(server.requests.length, 1);
    expect(server.requests.single.queryParameters['q'], 'nolan');
  });

  testWidgets('no results shows a suggestion (GU-02.04)', (tester) async {
    await pumpSearch(tester);
    await type(tester, 'zzzz');

    expect(find.text('No results for "zzzz"'), findsOneWidget);
    expect(find.textContaining('try fewer or different words'), findsOneWidget);
  });

  testWidgets('loads the next page when scrolled to the end', (tester) async {
    final server = await pumpSearch(tester);
    await type(tester, 'nolan');

    await tester.dragUntilVisible(
      find.text('nolan film 45'),
      find.byType(ListView),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    expect(find.text('nolan film 45'), findsOneWidget);
    final pages = [for (final r in server.requests) r.queryParameters['page']];
    expect(pages, ['1', '2', '3']);
  });

  testWidgets('a slow old search never replaces a newer one', (tester) async {
    await pumpSearch(tester, FakeSearchSlow());

    await tester.enterText(find.byType(TextField), 'nolan'); // slow reply
    await tester.pump(SearchScreen.typingPause);
    await tester.enterText(find.byType(TextField), 'zzzz'); // fast reply
    await tester.pump(SearchScreen.typingPause);
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.text('No results for "zzzz"'), findsOneWidget);
    expect(find.text('nolan film 1'), findsNothing);
  });

  testWidgets('server down: message and Try again', (tester) async {
    await pumpSearch(tester);
    await type(tester, 'down');

    expect(find.text("Couldn't search"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('clear button empties the search', (tester) async {
    await pumpSearch(tester);
    await type(tester, 'nolan');

    await tester.tap(find.byTooltip('Clear'));
    await tester.pumpAndSettle();

    expect(find.text('Find a movie or show'), findsOneWidget);
    expect(find.text('nolan film 1'), findsNothing);
  });
}

/// Same server, but "nolan" takes 2 seconds to answer
class FakeSearchSlow extends FakeSearch {
  @override
  Duration delayFor(String q) =>
      q == 'nolan' ? const Duration(seconds: 2) : Duration.zero;
}
