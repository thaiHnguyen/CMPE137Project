import 'package:dart_frog/dart_frog.dart';
import 'package:server/dao/mood_dao.dart';
import 'package:server/dao/review_dao.dart';
import 'package:server/dao/session_dao.dart';
import 'package:server/dao/title_dao.dart';
import 'package:server/dao/vote_dao.dart';
import 'package:server/db.dart';

final _titles = TitleDao(db);
final _moods = MoodDao(db);
final _reviews = ReviewDao(db);
final _votes = VoteDao(db);
final _sessions = SessionDao(db);

/// Makes the DAOs available to every route under /titles
Handler middleware(Handler handler) {
  return handler
      .use(provider<TitleDao>((_) => _titles))
      .use(provider<MoodDao>((_) => _moods))
      .use(provider<ReviewDao>((_) => _reviews))
      .use(provider<VoteDao>((_) => _votes))
      .use(provider<SessionDao>((_) => _sessions));
}
