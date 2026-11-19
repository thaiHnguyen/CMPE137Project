import 'package:flutter/material.dart';

import '../api/models.dart';

/// Poster, title and year for one movie or show (GU-01.04, GU-02.03)
class PosterCard extends StatelessWidget {
  /// Creates a [PosterCard].
  const PosterCard({super.key, required this.title, this.onTap});

  /// Width of the poster. Height follows the 2:3 poster shape
  static const width = 120.0;

  /// The title to show
  final TitleCard title;

  /// Called when the card is tapped
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final url = title.posterUrl;

    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PosterImage(url: url, type: title.type),
            const SizedBox(height: 6),
            Text(
              title.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (title.year != null)
              Text('${title.year}', style: text.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// A rounded 2:3 poster. Shows a movie or TV placeholder while it
/// loads, if it fails, or if there's no poster (GU-02.03)
class PosterImage extends StatelessWidget {
  /// Creates a [PosterImage]
  const PosterImage({super.key, required this.url, required this.type});

  final String? url; // Poster image, or null for the placeholder
  final String type; // `movie` or `tv`, picks the placeholder icon

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: url == null
            ? _Placeholder(type: type)
            : Image.network(
                url,
                fit: BoxFit.cover,
                // Show the placeholder while loading or if it fails
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : _Placeholder(type: type),
                errorBuilder: (context, error, stack) =>
                    _Placeholder(type: type),
              ),
      ),
    );
  }
}

/// Shown when a title has no poster, or while it loads
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.secondary,
      child: Center(
        child: Icon(
          type == 'tv' ? Icons.tv : Icons.movie_outlined,
          size: 40,
          color: colors.onSecondary,
        ),
      ),
    );
  }
}
