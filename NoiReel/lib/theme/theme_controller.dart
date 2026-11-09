import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'noireel_theme.dart';

/// Holds the current theme and remembers it on this device (GU-06.03)
///
/// The app rebuilds whenever [value] changes, so calling [choose]
/// recolors every screen right away, without a restart (GU-06.02)
class ThemeController extends ValueNotifier<NoiReelPalette> {
  /// Creates a controller starting on [initial].
  ThemeController([super.initial = NoiReelPalette.defaultTheme]);

  static const _key = 'theme';

  /// Loads the theme saved on this device, or Default if none (GU-06.04)
  static Future<ThemeController> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return ThemeController(NoiReelPalette.byName(prefs.getString(_key)));
    } on Exception catch (e) {
      // Device storage isn't available: not fatal
      debugPrint('Could not load the saved theme: $e');
      return ThemeController();
    }
  }

  /// Switches to [palette] and saves the choice on this device
  Future<void> choose(NoiReelPalette palette) async {
    value = palette;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, palette.name);
    } on Exception catch (e) {
      debugPrint('Could not save the theme: $e');
    }
  }
}
