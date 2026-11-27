import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import 'action_colors.dart';
import 'profile_avatar.dart';
import 'star_rating.dart';

/// One review in a list, like Letterboxd's: the author's photo, name,
/// stars and heart, then the review. Someone else's spoiler review is
/// hidden behind a warning; tap the card to open the review
class ReviewCard extends StatelessWidget {
  /// Creates the card for [review]
  const ReviewCard({
    super.key,
    required this.api,
    required this.review,
    required this.onTap,
  });

  final ApiClient api;
  final Review review;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final bodyText = theme.colorScheme.onSurface;
    final muted = bodyText.withValues(alpha: 0.7);
    final avatar = review.author.avatarUrl;
    final hidden = review.spoiler && !review.isMine;
    final likes = review.likeCount;
    final comments = review.commentCount;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProfileAvatar(
              radius: 20,
              image: avatar == null ? null : NetworkImage(api.mediaUrl(avatar)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          review.author.shownName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: muted,
                          ),
                        ),
                      ),
                      if (review.stars != null)
                        StarRating(value: review.stars, size: 16),
                      if (review.favorite) ...[
                        const SizedBox(width: 4),
                        Semantics(
                          container: true,
                          label: 'Favorite',
                          excludeSemantics: true,
                          child: Icon(
                            Icons.favorite,
                            size: 16,
                            color: activeActionColor(
                              context,
                              background: theme.scaffoldBackgroundColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Your own spoiler review: readable, but clearly marked
                  if (review.spoiler && review.isMine) ...[
                    const SpoilerBadge(),
                    const SizedBox(height: 4),
                    Text(
                      'Others see a spoiler warning instead of this review.',
                      style: text.bodySmall?.copyWith(color: muted),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (hidden)
                    const SpoilerWarning(
                      message:
                      'This review may contain spoilers. Tap to read it.',
                    )
                  else
                    Text(
                      review.body,
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyLarge?.copyWith(height: 1.4),
                    ),
                  if (likes > 0 || comments > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      [
                        if (likes > 0) '$likes ${likes == 1 ? 'like' : 'likes'}',
                        if (comments > 0)
                          '$comments ${comments == 1 ? 'comment' : 'comments'}',
                      ].join('  ·  '),
                      style: text.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A "Contains spoilers" pill, filled with the theme's button color (or
/// its text color when that wouldn't stand out), so it's easy to spot on
/// any theme. Shown on spoiler reviews you can read: your own, or one
/// you chose to show
class SpoilerBadge extends StatelessWidget {
  /// Creates the badge
  const SpoilerBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = theme.scaffoldBackgroundColor;
    final fill = activeActionColor(context, background: background);
    final onFill = fill == theme.colorScheme.primary
        ? theme.colorScheme.onPrimary
        : background;

    return Semantics(
      container: true,
      label: 'Contains spoilers',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: ShapeDecoration(color: fill, shape: const StadiumBorder()),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.visibility_off, size: 14, color: onFill),
            const SizedBox(width: 6),
            Text(
              'Contains spoilers',
              style: theme.textTheme.labelMedium?.copyWith(
                color: onFill,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The box shown in place of someone else's spoiler review: a bordered
/// card with the eye icon in the middle and the warning under it. On a
/// review's page it also has a "Show review" button
class SpoilerWarning extends StatelessWidget {
  /// Creates the warning; [onReveal] adds a "Show review" button
  const SpoilerWarning({super.key, required this.message, this.onReveal});

  final String message;
  final VoidCallback? onReveal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bodyText = theme.colorScheme.onSurface;
    final muted = bodyText.withValues(alpha: 0.75);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bodyText.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Column(
        children: [
          Icon(Icons.visibility_off, size: 28, color: muted),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
          if (onReveal != null) ...[
            const SizedBox(height: 6),
            TextButton(
              onPressed: onReveal,
              style: TextButton.styleFrom(foregroundColor: bodyText),
              child: const Text('Show review'),
            ),
          ],
        ],
      ),
    );
  }
}