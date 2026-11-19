import 'package:flutter/material.dart';

import '../theme/noireel_theme.dart';
import '../theme/theme_controller.dart';

/// Asks "How are you feeling today?" in a box in the middle of the screen
/// and switches the app to the chosen mood's theme.
///
/// The box slides up and fades in. Tapping outside it (or the back button)
/// slides it back down to close.
///
/// The new theme is applied only after the box has finished sliding away,
/// so the recoloring doesn't stutter the close animation
Future<void> showThemePicker(
  BuildContext context,
  ThemeController controller,
) async {
  final route = RawDialogRoute<NoiReelPalette>(
    barrierDismissible: true,
    barrierLabel: 'Close theme picker',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, _, _) => _ThemePicker(current: controller.value),
    transitionBuilder: (context, animation, _, child) {
      // Same curve both ways, so closing plays the slide-up backwards
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.25), // a quarter of the screen lower
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );

  // The root navigator, so the box covers the whole screen, nav bar included
  final picked = await Navigator.of(context, rootNavigator: true).push(route);
  if (picked == null || picked.name == controller.value.name) return;

  await route.completed; // the box has slid away
  await controller.choose(picked);
}

class _ThemePicker extends StatelessWidget {
  const _ThemePicker({required this.current});

  final NoiReelPalette current; // The theme in use, marked with a check

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;

    return Center(
      child: SafeArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Material(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How are you feeling today?',
                      style: text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _TwoColumns(
                      children: [
                        for (final palette in NoiReelPalette.all)
                          _ThemeTile(
                            palette: palette,
                            selected: palette.name == current.name,
                            // Closes the box; showThemePicker applies it
                            onTap: () => Navigator.pop(context, palette),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lays children out 2 per row. An odd last child gets half a row,
/// like the others
class _TwoColumns extends StatelessWidget {
  const _TwoColumns({required this.children});

  final List<Widget> children;

  static const _gap = 10.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < children.length; i += 2)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : _gap),
            child: Row(
              children: [
                Expanded(child: children[i]),
                const SizedBox(width: _gap),
                Expanded(
                  child: i + 1 < children.length
                      ? children[i + 1]
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// One theme in the picker: a rounded, bordered box with the theme's color
/// square and name. The current theme has a thicker border and a check
class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final NoiReelPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final bodyText = Theme.of(context).colorScheme.onSurface;
    final radius = BorderRadius.circular(14);

    return Semantics(
      selected: selected,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? bodyText : bodyText.withValues(alpha: 0.35),
            width: selected ? 2.5 : 1.5,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                MoodSwatch(palette: palette, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    palette.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (selected) Icon(Icons.check, size: 20, color: bodyText),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small square in a theme's colors: its background with a border in
/// its border color. Shown in the theme picker
class MoodSwatch extends StatelessWidget {
  /// Creates a [MoodSwatch].
  const MoodSwatch({super.key, required this.palette, this.size = 32});

  final NoiReelPalette palette; // The theme to show
  final double size;            // Width and height

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: palette.background,
        border: Border.all(color: palette.swatchBorder, width: size / 6),
        borderRadius: BorderRadius.circular(size / 6),
      ),
    );
  }
}