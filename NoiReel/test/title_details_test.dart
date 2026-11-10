import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/api/models.dart';
import 'package:flutter_application_1/screens/title_details_screen.dart';

void main() {
  // Same shape as the example in server/API.md
  final json = <String, dynamic>{
    'titleId': 4,
    'type': 'movie',
    'name': 'Example',
    'year': 2020,
    'posterUrl': null,
    'synopsis': 'A story.',
    'runtimeMin': 130,
    'seasons': null,
    'episodes': null,
    'avgRating': 4.5,
    'ratingCount': 12,
    'genres': ['Drama'],
    'directors': [
      {'personId': 1, 'name': 'A Director'},
    ],
    'creators': <Object>[],
    'cast': [
      {'personId': 2, 'name': 'An Actor', 'character': 'Hero'},
    ],
    'moods': {
      'primary': {
        'moodId': 5,
        'name': 'Calm',
        'colorHex': '#EAE9E5',
        'votes': 3,
        'isConfirmed': true,
      },
      'secondary': [
        {
          'moodId': 2,
          'name': 'Gloomy',
          'colorHex': null,
          'votes': 0,
          'isConfirmed': false,
        },
      ],
      'voters': 5,
      'votes': [
        {'moodId': 5, 'name': 'Calm', 'votes': 3, 'isConfirmed': true},
        {'moodId': 6, 'name': 'Excited', 'votes': 2, 'isConfirmed': false},
      ],
    },
  };

  test('reads title details from the server JSON', () {
    final d = TitleDetails.fromJson(json);
    expect(d.card.name, 'Example');
    expect(d.card.posterUrl, isNull);
    expect(d.runtimeMin, 130);
    expect(d.avgRating, 4.5);
    expect(d.genres, ['Drama']);
    expect(d.directors.single.name, 'A Director');
    expect(d.creators, isEmpty);
    expect(d.cast.single.character, 'Hero');
    expect(d.primaryMood!.name, 'Calm');
    expect(d.primaryMood!.isConfirmed, isTrue);
    expect(d.secondaryMoods.single.votes, 0);
    expect(d.voters, 5);
    expect(d.votes.map((v) => v.name), ['Calm', 'Excited']);
  });

  test('a title with no moods or rating yet', () {
    final d = TitleDetails.fromJson({
      ...json,
      'avgRating': null,
      'ratingCount': 0,
      'moods': {
        'primary': null,
        'secondary': <Object>[],
        'voters': 0,
        'votes': <Object>[],
      },
    });
    expect(d.primaryMood, isNull);
    expect(d.votes, isEmpty);
    expect(d.avgRating, isNull);
  });

  test('avgRating can come back as a whole number', () {
    expect(TitleDetails.fromJson({...json, 'avgRating': 4}).avgRating, 4.0);
  });

  test('formats runtimes', () {
    expect(formatRuntime(45), '45m');
    expect(formatRuntime(120), '2h');
    expect(formatRuntime(130), '2h 10m');
  });
}
