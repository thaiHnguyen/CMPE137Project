import 'package:mysql_client/mysql_client.dart';
import 'package:server/models/title.dart';

/// One of a user's lists, as shown on the Lists tab
class UserListSummary {
  /// Builds a [UserListSummary] from a row selected by `ListDao`
  UserListSummary.fromRow(ResultSetRow row)
    : id = int.parse(row.colByName('watchlist_id')!),
      name = row.colByName('name')!,
      description = row.colByName('description'),
      entryCount = int.parse(row.colByName('entry_count')!),
      posterUrls = (row.colByName('posters') ?? '')
          .split('\n')
          .where((url) => url.isNotEmpty)
          .toList(),
      updatedAt = row.colByName('updated_at')!;

  /// `watchlists.watchlist_id`
  final int id;
  /// List name
  final String name;
  /// Optional description
  final String? description;
  /// How many titles are in the list
  final int entryCount;
  /// The first few posters, in list order, for the list's card
  final List<String> posterUrls;
  /// When the list last changed, e.g. "2026-11-25 13:00:00"
  final String updatedAt;

  /// JSON sent to the app
  Map<String, dynamic> toJson() => {
    'listId': id,
    'name': name,
    'description': description,
    'entryCount': entryCount,
    'posterUrls': posterUrls,
    'updatedAt': updatedAt,
  };
}

/// A list with all its entries, in the order they were added
class UserListDetails {
  /// Creates a [UserListDetails]
  UserListDetails({
    required this.id,
    required this.name,
    required this.description,
    required this.entries,
  });

  /// `watchlists.watchlist_id`
  final int id;
  /// List name
  final String name;
  /// Optional description
  final String? description;
  /// The titles, in the order they were added
  final List<TitleCard> entries;

  /// JSON sent to the app
  Map<String, dynamic> toJson() => {
    'listId': id,
    'name': name,
    'description': description,
    'entryCount': entries.length,
    'entries': [for (final e in entries) e.toJson()],
  };
}
