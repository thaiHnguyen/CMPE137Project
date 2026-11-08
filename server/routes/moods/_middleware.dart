import 'package:dart_frog/dart_frog.dart';
import 'package:server/dao/mood_dao.dart';
import 'package:server/dao/title_dao.dart';
import 'package:server/db.dart';

final _moods = MoodDao(db);
final _titles = TitleDao(db);

/// Makes the DAOs available to every route under /moods
Handler middleware(Handler handler) {
  return handler
      .use(provider<MoodDao>((_) => _moods))
      .use(provider<TitleDao>((_) => _titles));
}
