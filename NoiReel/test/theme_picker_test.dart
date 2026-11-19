import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/theme/noireel_theme.dart';
import 'package:flutter_application_1/theme/theme_controller.dart';
import 'package:flutter_application_1/widgets/fade_slide_in.dart';
import 'package:flutter_application_1/widgets/theme_picker.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<ThemeController> openPicker(WidgetTester tester) async {
    final themes = ThemeController();
    await tester.pumpWidget(
      MaterialApp(
        theme: themes.value.toThemeData(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: ElevatedButton(
                onPressed: () => showThemePicker(context, themes),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return themes;
  }

  testWidgets('opens in the middle of the screen', (tester) async {
    await openPicker(tester);

    expect(find.text('How are you feeling today?'), findsOneWidget);
    final screen = tester.getRect(find.byType(Scaffold)).center;
    final box = tester.getCenter(find.text('Melancholy'));
    expect((box.dy - screen.dy).abs(), lessThan(150));
  });

  testWidgets('themes are 2 per row', (tester) async {
    await openPicker(tester);

    double y(String name) => tester.getCenter(find.text(name)).dy;
    // Left edges, not centers: the selected tile also shows a check mark,
    // which makes its label narrower
    double x(String name) => tester.getTopLeft(find.text(name)).dx;
    expect(y('Default'), y('Hopeful'));
    expect(y('Gloomy'), y('Happy'));
    expect(y('Gloomy'), greaterThan(y('Default')));
    expect(x('Default'), lessThan(x('Hopeful')));
    expect(x('Default'), x('Gloomy'));
  });

  testWidgets('tapping outside closes it without changing the theme',
      (tester) async {
    final themes = await openPicker(tester);

    await tester.tapAt(const Offset(5, 5)); // top-left corner, outside the box
    await tester.pumpAndSettle();

    expect(find.text('How are you feeling today?'), findsNothing);
    expect(themes.value.name, 'Default');
  });

  testWidgets('picking a theme switches to it and closes', (tester) async {
    final themes = await openPicker(tester);

    await tester.tap(find.text('Calm'));
    await tester.pumpAndSettle();

    expect(themes.value, NoiReelPalette.byName('Calm'));
    expect(find.text('How are you feeling today?'), findsNothing);
  });

  testWidgets('the theme changes only after the box has slid away',
      (tester) async {
    final themes = await openPicker(tester);

    await tester.tap(find.text('Excited'));
    await tester.pump(const Duration(milliseconds: 100)); // still closing
    expect(themes.value.name, 'Default');

    await tester.pumpAndSettle();
    expect(themes.value.name, 'Excited');
  });

  test('each theme is built once and reused', () {
    final calm = NoiReelPalette.byName('Calm');
    expect(identical(calm.toThemeData(), calm.toThemeData()), isTrue);
  });

  testWidgets('FadeSlideIn ends fully shown and in place', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FadeSlideIn(
          delay: Duration(milliseconds: 100),
          child: Text('hello'),
        ),
      ),
    );
    final fade = find
        .ancestor(of: find.text('hello'), matching: find.byType(Opacity))
        .first;
    final start = tester.widget<Opacity>(fade).opacity;
    await tester.pumpAndSettle();
    final end = tester.widget<Opacity>(fade).opacity;

    expect(start, 0);
    expect(end, 1);
  });
}