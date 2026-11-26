import 'package:dart_frog/dart_frog.dart';
import 'package:server/dao/collection_dao.dart';
import 'package:server/dao/entry_dao.dart';
import 'package:server/dao/list_dao.dart';
import 'package:server/dao/mood_dao.dart';
import 'package:server/dao/profile_dao.dart';
import 'package:server/dao/session_dao.dart';
import 'package:server/dao/title_dao.dart';
import 'package:server/db.dart';
import 'package:server/profile/avatar_files.dart';

final _collections = CollectionDao(db);
final _entries = EntryDao(db);
final _lists = ListDao(db);
final _moods = MoodDao(db);
final _titles = TitleDao(db);
final _profiles = ProfileDao(db);
final _sessions = SessionDao(db);
final _avatars = AvatarFiles();

/// Makes the DAOs available to every route under /me (the logged-in
/// user's own things)
Handler middleware(Handler handler) {
  return handler
      .use(provider<CollectionDao>((_) => _collections))
      .use(provider<EntryDao>((_) => _entries))
      .use(provider<ListDao>((_) => _lists))
      .use(provider<MoodDao>((_) => _moods))
      .use(provider<TitleDao>((_) => _titles))
      .use(provider<ProfileDao>((_) => _profiles))
      .use(provider<SessionDao>((_) => _sessions))
      .use(provider<AvatarFiles>((_) => _avatars));
}
