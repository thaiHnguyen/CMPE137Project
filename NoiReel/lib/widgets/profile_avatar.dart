import 'package:flutter/material.dart';

/// A round profile photo. Without a photo, or if it fails to load, it
/// shows a plain person silhouette, like Letterboxd's default
class ProfileAvatar extends StatelessWidget {
  /// Creates an avatar of the given [radius]
  const ProfileAvatar({super.key, this.image, this.radius = 48});

  /// The photo (e.g. `NetworkImage` or `MemoryImage`), or null for the
  /// default picture
  final ImageProvider? image;

  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final size = radius * 2;

    final placeholder = Container(
      color: colors.secondary,
      alignment: Alignment.bottomCenter,
      child: Icon(
        Icons.person,
        size: size * 0.9,
        color: colors.onSecondary.withValues(alpha: 0.55),
      ),
    );

    return Semantics(
      image: true,
      label: 'Profile photo',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: colors.onSurface.withValues(alpha: 0.25),
            width: 2,
          ),
        ),
        child: ClipOval(
          child: image == null
              ? placeholder
              : Image(
                  image: image!,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => placeholder,
                ),
        ),
      ),
    );
  }
}
