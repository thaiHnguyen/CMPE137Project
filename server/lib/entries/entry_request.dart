import 'package:server/auth/validators.dart';
import 'package:server/dao/vote_dao.dart';
import 'package:server/models/title_entry.dart';

/// Longest review (`reviews.body` is VARCHAR(5000))
const maxReview = 5000;

final _date = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// Checks a `PUT /me/titles/:id/entry` body:
/// `{watchedOn?, stars?, review?, spoiler?, moodIds?}`. [today] is the
/// server's date; a watch date may be at most one day after it (the user
/// may be in a time zone that's already tomorrow). Mood ids are checked
/// against [activeMoodIds]. Returns the entry, or the first problem
(TitleEntry?, FieldError?) parseEntry(
  Map<String, dynamic> body, {
  required DateTime today,
  required Set<int> activeMoodIds,
}) {
  // Watch date
  final rawDate = body['watchedOn'];
  String? watchedOn;
  if (rawDate != null) {
    final m = rawDate is String ? _date.firstMatch(rawDate) : null;
    final date = m == null
        ? null
        : DateTime.utc(
            int.parse(m[1]!),
            int.parse(m[2]!),
            int.parse(m[3]!),
          );
    // DateTime.utc rolls over bad days (Feb 31 -> Mar 3); reject those
    if (date == null ||
        date.month != int.parse(m![2]!) ||
        date.day != int.parse(m[3]!)) {
      return (null, (field: 'watchedOn', message: 'Pick a valid date.'));
    }
    final latest = DateTime.utc(today.year, today.month, today.day + 1);
    if (date.isAfter(latest)) {
      return (
        null,
        (field: 'watchedOn', message: "The date can't be in the future."),
      );
    }
    if (date.year < 1870) {
      return (null, (field: 'watchedOn', message: 'Pick a valid date.'));
    }
    watchedOn = rawDate as String;
  }

  // Rating: half stars from 0.5 to 5
  final rawStars = body['stars'];
  double? stars;
  if (rawStars != null) {
    final value = rawStars is num ? rawStars.toDouble() : null;
    if (value == null ||
        value < 0.5 ||
        value > 5 ||
        (value * 2) != (value * 2).roundToDouble()) {
      return (
        null,
        (field: 'stars', message: 'Rate from half a star to 5 stars.'),
      );
    }
    stars = value;
  }

  // Review
  final rawReview = body['review'];
  if (rawReview != null && rawReview is! String) {
    return (null, (field: 'review', message: 'The review must be text.'));
  }
  final trimmed = (rawReview as String?)?.trim() ?? '';
  if (trimmed.runes.length > maxReview) {
    return (
      null,
      (field: 'review', message: 'Use at most $maxReview characters.'),
    );
  }
  final review = trimmed.isEmpty ? null : trimmed;

  final spoiler = body['spoiler'];
  if (spoiler != null && spoiler is! bool) {
    return (null, (field: 'spoiler', message: 'Must be true or false.'));
  }

  // Moods
  final rawMoods = body['moodIds'] ?? <Object>[];
  if (rawMoods is! List || rawMoods.any((id) => id is! int)) {
    return (null, (field: 'moodIds', message: 'Must be a list of mood ids.'));
  }
  final moodIds = <int>[];
  for (final id in rawMoods.cast<int>()) {
    if (!activeMoodIds.contains(id)) {
      return (null, (field: 'moodIds', message: 'Unknown mood id: $id.'));
    }
    if (!moodIds.contains(id)) moodIds.add(id);
  }
  if (moodIds.length > VoteDao.maxPerTitle) {
    return (
      null,
      (
        field: 'moodIds',
        message: 'Pick up to ${VoteDao.maxPerTitle} moods.',
      ),
    );
  }

  final entry = TitleEntry(
    watchedOn: watchedOn,
    stars: stars,
    review: review,
    spoiler: review != null && spoiler == true,
    moodIds: moodIds,
  );
  if (!entry.logged && moodIds.isEmpty) {
    return (
      null,
      (
        field: 'entry',
        message: 'Add a date, a rating, a mood or a review first.',
      ),
    );
  }
  return (entry, null);
}
