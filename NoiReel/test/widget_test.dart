import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/theme/noireel_theme.dart';

void main() {
  test('there is a theme for Default and each of the 6 moods', () {
    expect(NoiReelPalette.all.map((p) => p.name), [
      'Default',
      'Hopeful',
      'Gloomy',
      'Happy',
      'Melancholy',
      'Calm',
      'Excited',
    ]);
  });

  test('an unknown theme name falls back to Default', () {
    expect(NoiReelPalette.byName('Nope'), NoiReelPalette.defaultTheme);
    expect(NoiReelPalette.byName(null), NoiReelPalette.defaultTheme);
    expect(NoiReelPalette.byName('Calm').name, 'Calm');
  });

  test('text on the background is readable in every theme', () {
    for (final p in NoiReelPalette.all) {
      expect(
        _contrast(p.bodyText, p.background),
        greaterThanOrEqualTo(4.5),
        reason: '${p.name} body text',
      );
    }
  });

  test('header and nav bar text stands out from the nav bar', () {
    for (final p in NoiReelPalette.all) {
      expect(
        _contrast(p.navText, p.navBar),
        greaterThan(1.5),
        reason: '${p.name} nav text',
      );
    }
  });

  test('buttons use the default, hover and clicked colors', () {
    final calm = NoiReelPalette.byName('Calm');
    final style = calm.toThemeData().elevatedButtonTheme.style!;
    Color? bg(Set<WidgetState> s) => style.backgroundColor!.resolve(s);
    Color? fg(Set<WidgetState> s) => style.foregroundColor!.resolve(s);

    expect(bg({}), calm.button);
    expect(fg({}), calm.buttonText);
    expect(bg({WidgetState.hovered}), calm.hover);
    expect(fg({WidgetState.hovered}), calm.activeButtonText);
    expect(bg({WidgetState.pressed, WidgetState.hovered}), calm.clicked);
    expect(fg({WidgetState.pressed}), calm.activeButtonText);
  });
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}
