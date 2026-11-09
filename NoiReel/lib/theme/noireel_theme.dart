import 'package:flutter/material.dart';

/// One NoiReel color theme: Default, or one per mood.
///
/// Colors come from "CMPE-137 Color palette" and the Figma mockups
/// To change a theme, edit its entry in [NoiReelPalette.all]; every screen
/// reads its colors from here, so nothing else needs to change
@immutable
class NoiReelPalette {
  /// Creates a palette
  const NoiReelPalette({
    required this.name,
    required this.background,
    required this.navBar,
    required this.navText,
    required this.button,
    required this.buttonText,
    required this.hover,
    required this.clicked,
    required this.activeButtonText,
    required this.bodyText,
    this.pickerBorder,
  });

  final String name;              // Theme name
  final Color background;         // "Primary" in the sheet: the screen background
  final Color navBar;             // "Secondary" in the sheet: header and navigation bar background
  final Color navText;            // Header and navigation bar text and icons
  final Color button;             // Default button color
  final Color buttonText;         // Default button text (text color 1)
  final Color hover;              // Button color while the mouse is over it
  final Color clicked;            // Button color while it's being pressed
  final Color activeButtonText;   // Hovered and clicked button text (text color 2)

  /// Text sitting directly on [background]: screen titles, mood row names,
  /// movie titles. Picked from the theme's own colors so it's readable
  /// (at least 4.5:1 contrast, the WCAG level for normal text)
  final Color bodyText;

  /// Border of this theme's color square in the theme picker, if it
  /// shouldn't be [navBar]. Use [swatchBorder] to read it
  final Color? pickerBorder;

  /// Border of this theme's color square in the theme picker
  Color get swatchBorder => pickerBorder ?? navBar;

  /// True if this theme has a dark background
  bool get isDark =>
      ThemeData.estimateBrightnessForColor(background) == Brightness.dark;

  /// The Default theme, used until the user picks a mood
  static const defaultTheme = NoiReelPalette(
    name: 'Default',
    background: Color(0xFF8C7A58),
    navBar: Color(0xFF0D0909),
    navText: Color(0xFFF2D98D),
    button: Color(0xFF0D0909),
    buttonText: Color(0xFFF2D98D),
    hover: Color(0xFFE6CD88),
    clicked: Color(0xFF574C37),
    activeButtonText: Color(0xFF0D0909),
    bodyText: Color(0xFF0D0909),
  );

  /// Every theme, in the order shown in the theme picker
  /// (opposite moods next to each other)
  static const all = [
    defaultTheme,
    NoiReelPalette(
      name: 'Hopeful',
      background: Color(0xFFD9B13B),
      navBar: Color(0xFF49808C),
      navText: Color(0xFFE4E2BF), 
      button: Color(0xFFE4E2BF),
      buttonText: Color(0xFF49808C),
      hover: Color(0xFFBF1F1F),
      clicked: Color(0xFF730202),
      activeButtonText: Color(0xFFE4E2BF),
      bodyText: Color(0xFF730202),
    ),
    NoiReelPalette(
      name: 'Gloomy',
      background: Color(0xFF143A25),
      navBar: Color(0xFF1D5632),
      navText: Color(0xFFB5E4C9),
      button: Color(0xFF73AB90),
      buttonText: Color(0xFFB5E4C9),
      hover: Color(0xFF739664),
      clicked: Color(0xFF4D5328),
      activeButtonText: Color(0xFF666A38),
      bodyText: Color(0xFFB5E4C9),
    ),
    NoiReelPalette(
      name: 'Happy',
      background: Color(0xFFEBEBD7),
      navBar: Color(0xFF75BD47),
      navText: Color(0xFFFAFFFD),
      button: Color(0xFF75BD47),
      buttonText: Color(0xFFFAFFFD),
      hover: Color(0xFFEB6661),
      clicked: Color(0xFF7F3337),
      activeButtonText: Color(0xFF37608A),
      bodyText: Color(0xFF37608A),
    ),
    NoiReelPalette(
      name: 'Melancholy',
      background: Color(0xFF325D7F),
      navBar: Color(0xFF839899),
      navText: Color(0xFF042F52),
      button: Color(0xFFDC8D64),
      buttonText: Color(0xFF042F52),
      hover: Color(0xFF819886),
      clicked: Color(0xFF44473C),
      activeButtonText: Color(0xFFE5D5A2),
      bodyText: Color(0xFFE5D5A2),
      pickerBorder: Color(0xFFDC8D64),
    ),
    NoiReelPalette(
      name: 'Calm',
      background: Color(0xFF21294E),
      navBar: Color(0xFF6597CD),
      navText: Color(0xFFEAE9E5), 
      button: Color(0xFFEAE9E5),
      buttonText: Color(0xFF4A88BF),
      hover: Color(0xFF4A88BF),
      clicked: Color(0xFF3A6082),
      activeButtonText: Color(0xFFEAE9E5),
      bodyText: Color(0xFFEAE9E5),
    ),
    NoiReelPalette(
      name: 'Excited',
      background: Color(0xFF19374D),
      navBar: Color(0xFFDBD7D6),
      navText: Color(0xFFD42C08),
      button: Color(0xFFDBD7D6),
      buttonText: Color(0xFFD42C08),
      hover: Color(0xFFD42C08),
      clicked: Color(0xFF0D0A09),
      activeButtonText: Color(0xFFDBD7D6),
      bodyText: Color(0xFFDBD7D6),
      pickerBorder: Color(0xFFD42C08),
    ),
  ];

  /// The theme called [name], or the Default theme if there isn't one
  static NoiReelPalette byName(String? name) =>
      all.firstWhere((p) => p.name == name, orElse: () => defaultTheme);

  /// Builds the Flutter theme, so standard widgets (buttons, dialogs,
  /// text, the app bar) pick up these colors automatically
  ThemeData toThemeData() {
    final brightness = isDark ? Brightness.dark : Brightness.light;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: button,
          brightness: brightness,
        ).copyWith(
          primary: button,
          onPrimary: buttonText,
          secondary: navBar,
          onSecondary: navText,
          surface: background,
          onSurface: bodyText,
        );

    // Button color and text for each state: default, hover, clicked.
    Color buttonColor(Set<WidgetState> states) {
      if (states.contains(WidgetState.pressed)) return clicked;
      if (states.contains(WidgetState.hovered)) return hover;
      return button;
    }

    Color buttonTextColor(Set<WidgetState> states) {
      if (states.contains(WidgetState.pressed) ||
          states.contains(WidgetState.hovered)) {
        return activeButtonText;
      }
      return buttonText;
    }

    final buttonStyle = ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith(buttonColor),
      foregroundColor: WidgetStateProperty.resolveWith(buttonTextColor),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      elevation: const WidgetStatePropertyAll(0),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: navBar,
        foregroundColor: navText,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: navText,
          fontSize: 28,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: buttonStyle),
      // Sheets (like the theme picker) use the screen background, so
      // bodyText stays readable on them
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: background,
        dragHandleColor: bodyText,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: bodyText),
      textTheme: ThemeData(brightness: brightness).textTheme
          .apply(bodyColor: bodyText, displayColor: bodyText),
    );
  }
}