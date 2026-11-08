import 'package:mysql_client/mysql_client.dart';
import 'package:server/models/mood.dart';

/// Reads moods and their opposites: `moods`, `mood_counters`
class MoodDao {
  /// Creates a DAO on a connection pool (normally the shared `db`)
  MoodDao(this._db);

  final MySQLConnectionPool _db;

  static const _listMoods = '''
SELECT m.mood_id, m.name, m.description, m.color_hex,
        GROUP_CONCAT(c.mood_id ORDER BY c.mood_id) AS counter_ids
FROM moods m
LEFT JOIN mood_counters mc ON mc.mood_id = m.mood_id
LEFT JOIN moods c ON c.mood_id = mc.counter_mood_id AND c.is_active
WHERE m.is_active
GROUP BY m.mood_id
ORDER BY m.mood_id''';

  static const _findMood = '''
SELECT m.mood_id, m.name, m.description, m.color_hex,
        GROUP_CONCAT(c.mood_id ORDER BY c.mood_id) AS counter_ids
FROM moods m
LEFT JOIN mood_counters mc ON mc.mood_id = m.mood_id
LEFT JOIN moods c ON c.mood_id = mc.counter_mood_id AND c.is_active
WHERE m.is_active AND m.mood_id = :id
GROUP BY m.mood_id''';

  /// RU-05.01: every active mood
  Future<List<Mood>> listActive() async {
    final res = await _db.execute(_listMoods);
    return res.rows.map(Mood.fromRow).toList();
  }

  /// One active mood, or null if it doesn't exist or was deactivated
  Future<Mood?> findActive(int id) async {
    final res = await _db.execute(_findMood, {'id': id});
    return res.rows.isEmpty ? null : Mood.fromRow(res.rows.first);
  }
}
