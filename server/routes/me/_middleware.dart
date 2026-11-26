import 'package:dart_frog/dart_frog.dart';
import 'package:server/dao/list_dao.dart';
import 'package:server/dao/session_dao.dart';
import 'package:server/db.dart';

final _lists = ListDao(db);
final _sessions = SessionDao(db);

/// Makes the DAOs available to every route under /me (the logged-in
/// user's own things)
Handler middleware(Handler handler) {
  return handler
      .use(provider<ListDao>((_) => _lists))
      .use(provider<SessionDao>((_) => _sessions));
}
