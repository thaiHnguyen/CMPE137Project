import 'package:server/dao/list_dao.dart';

/// A checked "create list" or "save list" request: trimmed name and
/// description, and the title ids with duplicates removed (first one kept,
/// so order is kept)
typedef NewList = ({String name, String? description, List<int> titleIds});

/// The problem with a list body, for a 400 response
typedef ListProblem = ({String field, String message});

/// Longest list name (watchlists.name is VARCHAR(60))
const maxListName = 60;

/// Longest description (watchlists.description is VARCHAR(500))
const maxListDescription = 500;

/// Checks a `POST /me/lists` or `PUT /me/lists/:id` body. Returns the
/// list, or the problem
(NewList?, ListProblem?) parseNewList(Map<String, dynamic> body) {
  final name = body['name'] is String ? (body['name'] as String).trim() : '';
  if (name.isEmpty) {
    return (null, (field: 'name', message: 'Give your list a name.'));
  }
  if (name.runes.length > maxListName) {
    return (
      null,
      (field: 'name', message: 'Use at most $maxListName characters.'),
    );
  }

  final rawDescription = body['description'];
  if (rawDescription != null && rawDescription is! String) {
    return (null, (field: 'description', message: 'Must be text.'));
  }
  final trimmed = (rawDescription as String?)?.trim() ?? '';
  final description = trimmed.isEmpty ? null : trimmed;
  if (trimmed.runes.length > maxListDescription) {
    return (
      null,
      (
        field: 'description',
        message: 'Use at most $maxListDescription characters.',
      ),
    );
  }

  final rawIds = body['titleIds'] ?? <Object>[];
  if (rawIds is! List || rawIds.any((id) => id is! int || id < 1)) {
    return (
      null,
      (field: 'titleIds', message: 'Must be a list of title ids.'),
    );
  }
  final titleIds = <int>[];
  for (final id in rawIds.cast<int>()) {
    if (!titleIds.contains(id)) titleIds.add(id);
  }
  if (titleIds.length > ListDao.maxEntries) {
    return (
      null,
      (
        field: 'titleIds',
        message: 'A list can have at most ${ListDao.maxEntries} entries.',
      ),
    );
  }

  return ((name: name, description: description, titleIds: titleIds), null);
}
