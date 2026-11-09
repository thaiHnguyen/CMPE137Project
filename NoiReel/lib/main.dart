import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'api/api_client.dart';
import 'screens/home_screen.dart';
import 'theme/noireel_theme.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  final themes = await ThemeController.load();
  runApp(NoiReelApp(themes: themes, api: ApiClient()));
}

/// The NoiReel app. Rebuilds with new colors whenever the theme changes
class NoiReelApp extends StatelessWidget {
  /// Creates the app
  const NoiReelApp({super.key, required this.themes, required this.api});

  /// The current theme
  final ThemeController themes;

  /// Connection to the NoiReel server
  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<NoiReelPalette>(
      valueListenable: themes,
      builder: (context, palette, _) => MaterialApp(
        title: 'NoiReel',
        debugShowCheckedModeBanner: false,
        theme: palette.toThemeData(),
        home: HomeScreen(api: api, themes: themes),
      ),
    );
  }
}
