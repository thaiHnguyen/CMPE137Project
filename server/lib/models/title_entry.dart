/// One user's review and log of one title: when they watched it, their
/// star rating, their review, and the moods they voted. Stored across
/// `watch_logs`, `ratings`, `reviews` and `user_mood_tags`
class TitleEntry {
  /// Creates a [TitleEntry]
  const TitleEntry({
    this.watchedOn,
    this.stars,
    this.review,
    this.spoiler = false,
    this.moodIds = const [],
    this.updatedAt,
  });

  /// Watch date as `YYYY-MM-DD`, or null if they didn't give one
  final String? watchedOn;
  /// 0.5 to 5.0 in half stars, or null for no rating
  final double? stars;
  /// Review text, or null for no review
  final String? review;
  /// True if the review gives away the plot
  final bool spoiler;
  /// Moods they voted on this title (up to 3)
  final List<int> moodIds;
  /// Last change to the date, rating or review (`YYYY-MM-DD HH:MM:SS`)
  final String? updatedAt;

  /// True once they've given a date, a rating or a review: the app then
  /// says "My review and log" instead of "Review or log"
  bool get logged => watchedOn != null || stars != null || review != null;

  /// JSON sent to the app
  Map<String, dynamic> toJson() => {
    'watchedOn': watchedOn,
    'stars': stars,
    'review': review,
    'spoiler': spoiler,
    'moodIds': moodIds,
    'updatedAt': updatedAt,
  };
}
