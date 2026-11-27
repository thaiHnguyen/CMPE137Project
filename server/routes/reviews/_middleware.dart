import 'package:dart_frog/dart_frog.dart';
import 'package:server/dao/review_dao.dart';
import 'package:server/dao/session_dao.dart';
import 'package:server/db.dart';

final _reviews = ReviewDao(db);
final _sessions = SessionDao(db);

/// Makes the DAOs available to every route under /reviews
Handler middleware(Handler handler) {
  return handler
      .use(provider<ReviewDao>((_) => _reviews))
      .use(provider<SessionDao>((_) => _sessions));
}
