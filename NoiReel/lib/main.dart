import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'api/api_client.dart';
import 'auth/auth_controller.dart';
import 'screens/app_shell.dart';
import 'theme/noireel_theme.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  final themes = await ThemeController.load();
  final api = ApiClient();
  final auth = await AuthController.load(api); // stays logged in (RU-01.02)
  runApp(NoiReelApp(themes: themes, api: api, auth: auth));
}

/// The NoiReel app. Rebuilds with new colors whenever the theme changes
class NoiReelApp extends StatelessWidget {
  /// Creates the app
  const NoiReelApp({
    super.key,
    required this.themes,
    required this.api,
    required this.auth,
  });

  /// The current theme
  final ThemeController themes;

  /// Connection to the NoiReel server
  final ApiClient api;

  /// Who is logged in
  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<NoiReelPalette>(
      valueListenable: themes,
      builder: (context, palette, _) => MaterialApp(
        title: 'NoiReel',
        debugShowCheckedModeBanner: false,
        theme: palette.toThemeData(),
        // Switch themes at once
        themeAnimationDuration: Duration.zero,
        home: AppShell(api: api, themes: themes, auth: auth),
      ),
    );
  }
}