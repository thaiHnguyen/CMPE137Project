import 'package:flutter/material.dart';

/// The color for a switched-on title action (a filled heart for Favorites,
/// a filled clock for Watchlist), taken from the current theme so it
/// changes with it.
///
/// It's the theme's button color when that stands out on [background]
/// (at least 3:1 contrast, the minimum for icons), otherwise whichever
/// theme text color stands out more. On is still told apart from off by
/// the filled icon, not only the color
Color activeActionColor(BuildContext context, {required Color background}) {
  final colors = Theme.of(context).colorScheme;
  final button = colors.primary;
  if (_contrast(button, background) >= 3) return button;

  final candidates = [colors.onSecondary, colors.onSurface, colors.onPrimary];
  candidates.sort(
    (a, b) => _contrast(b, background).compareTo(_contrast(a, background)),
  );
  return candidates.first;
}

/// WCAG contrast ratio between two colors (1 to 21)
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}