import 'package:flutter/material.dart';

import '../theme/noireel_theme.dart';

/// A mood as a rounded chip. Picked: in that mood theme's own header
/// colors (like the tags on a details page). Not picked: outlined in the
/// current theme's text color
class MoodChip extends StatelessWidget {
  /// Creates a chip for the mood called [name]
  const MoodChip({
    super.key,
    required this.name,
    this.selected = true,
    this.onTap,
  });

  final String name;
  final bool selected;
  final VoidCallback? onTap; // Null: not tappable

  @override
  Widget build(BuildContext context) {
    final palette = NoiReelPalette.byName(name);
    final bodyText = Theme.of(context).colorScheme.onSurface;
    final radius = BorderRadius.circular(20);

    final chip = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? palette.navBar : Colors.transparent,
        border: Border.all(
          color: selected
              ? palette.swatchBorder
              : bodyText.withValues(alpha: 0.5),
          width: 2,
        ),
        borderRadius: radius,
      ),
      child: Text(
        name,
        style: TextStyle(
          color: selected ? palette.navText : bodyText,
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    );

    if (onTap == null) return chip;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(onTap: onTap, borderRadius: radius, child: chip),
    );
  }
}
