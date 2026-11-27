import 'package:flutter/material.dart';

/// Five stars showing a rating in half stars. Read-only unless [onChanged]
/// is set: then tapping or dragging picks a rating (the left half of a
/// star is half a star), and tapping the current rating clears it
class StarRating extends StatelessWidget {
  /// Creates the stars for [value] (0.5 to 5, or null for none)
  const StarRating({
    super.key,
    required this.value,
    this.onChanged,
    this.size = 44,
    this.color,
  });

  final double? value;
  final ValueChanged<double?>? onChanged;
  final double size;
  final Color? color; // Filled stars; defaults to the theme's button color

  /// The rating at [dx] pixels from the left: whole or half stars
  double _valueAt(double dx) {
    final halves = (dx / (size / 2)).ceil().clamp(1, 10);
    return halves / 2;
  }

  void _set(double next) {
    final change = onChanged;
    if (change == null) return;
    change(next == value ? null : next);
  }

  void _drag(double dx) {
    final next = _valueAt(dx);
    if (next != value) onChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filled = color ?? theme.colorScheme.primary;
    final empty = theme.colorScheme.onSurface.withValues(alpha: 0.25);
    final v = value ?? 0;

    final stars = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            v >= i
                ? Icons.star_rounded
                : v >= i - 0.5
                ? Icons.star_half_rounded
                : Icons.star_rounded,
            size: size,
            color: v >= i - 0.5 ? filled : empty,
          ),
      ],
    );

    final label = value == null
        ? 'No rating'
        : '${value! % 1 == 0 ? value!.toInt() : value} '
              '${value == 1 ? 'star' : 'stars'}';

    if (onChanged == null) {
      return Semantics(
        container: true,
        label: label,
        excludeSemantics: true,
        child: stars,
      );
    }
    return Semantics(
      container: true,
      label: 'Rating',
      value: label,
      increasedValue: 'Higher',
      decreasedValue: 'Lower',
      onIncrease: () => onChanged!((v + 0.5).clamp(0.5, 5)),
      onDecrease: () => onChanged!(v <= 0.5 ? null : v - 0.5),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) => _set(_valueAt(d.localPosition.dx)),
        onHorizontalDragUpdate: (d) => _drag(d.localPosition.dx),
        child: stars,
      ),
    );
  }
}
