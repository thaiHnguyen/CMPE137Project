class MoodTextMatcher {
  static const Map<String, List<String>> keywords = {
    'Hopeful': [
      'hopeful',
      'optimistic',
      'inspired',
      'positive',
      'better',
    ],
    'Gloomy': [
      'down',
      'sad',
      'depressed',
      'dark',
      'unhappy',
      'low',
    ],
    'Happy': [
      'happy',
      'joyful',
      'good',
      'fun',
      'cheerful',
      'great',
    ],
    'Melancholy': [
      'melancholy',
      'lonely',
      'nostalgic',
      'bittersweet',
      'emotional',
    ],
    'Calm': [
      'calm',
      'peaceful',
      'relaxed',
      'quiet',
      'comfortable',
    ],
    'Excited': [
      'excited',
      'energetic',
      'thrilled',
      'hyped',
      'adventurous',
    ],
  };

  static String? match(String phrase) {
    final text = phrase.toLowerCase();

    if (text.contains('feel down')) return 'Gloomy';
    if (text.contains('feel happy')) return 'Happy';
    if (text.contains('feel calm')) return 'Calm';
    if (text.contains('feel excited')) return 'Excited';

    final words = text
        .split(RegExp(r'[^a-z]+'))
        .where((word) => word.isNotEmpty)
        .toSet();

    String? bestMood;
    var bestScore = 0;

    for (final entry in keywords.entries) {
      final score = entry.value.where(words.contains).length;

      if (score > bestScore) {
        bestScore = score;
        bestMood = entry.key;
      }
    }

    return bestMood;
  }
}