import 'package:flutter/material.dart';

import '../theme/noireel_theme.dart';
import '../theme/theme_controller.dart';

/// Asks "How are you feeling today?" and switches the app to the chosen
/// mood's theme
Future<void> showThemePicker(BuildContext context, ThemeController controller) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _ThemePicker(controller: controller),
  );
}

class _ThemePicker extends StatelessWidget {
  const _ThemePicker({required this.controller});

  final ThemeController controller;

  @override
  Widget build(BuildContext context) {
    final current = controller.value;
    final text = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How are you feeling today?',
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            for (final palette in NoiReelPalette.all)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: MoodSwatch(palette: palette),
                title: Text(
                  palette.name,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                trailing: palette.name == current.name
                    ? Icon(Icons.check, color: text.titleMedium?.color)
                    : null,
                onTap: () {
                  controller.choose(palette);
                  Navigator.pop(context);
                },
              ),
          ],
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