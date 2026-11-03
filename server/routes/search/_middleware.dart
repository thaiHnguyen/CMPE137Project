import 'package:dart_frog/dart_frog.dart';
import 'package:server/dao/title_dao.dart';
import 'package:server/db.dart';

final _titles = TitleDao(db);

/// Makes [TitleDao] available to the /search route
Handler middleware(Handler handler) {
  return handler.use(provider<TitleDao>((_) => _titles));
}
