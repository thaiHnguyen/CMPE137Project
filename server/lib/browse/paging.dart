import 'package:dart_frog/dart_frog.dart';

/// Which page of a list to return, read from `?page=` and `?limit=`.
class Paging {
  /// Creates a [Paging]
  const Paging(this.page, this.limit);

  /// Page number, starting at 1
  final int page;

  /// Titles per page
  final int limit;

  /// How many rows to skip
  int get offset => (page - 1) * limit;
}

/// Titles per page when `?limit=` is missing (GU-02.02)
const defaultLimit = 20;

/// Largest allowed `?limit=`.
const maxLimit = 50;

const _maxPage = 100000;

/// Reads `page` and `limit` from a query string
/// Returns null if either one is present but invalid
Paging? parsePaging(Map<String, String> query) {
  final page = _positiveInt(query['page'] ?? '1');
  final limit = _positiveInt(query['limit'] ?? '$defaultLimit');
  if (page == null || page > _maxPage) return null;
  if (limit == null || limit > maxLimit) return null;
  return Paging(page, limit);
}

/// A database id from a URL, or null if it isn't a positive whole number
int? parseId(String value) => _positiveInt(value);

int? _positiveInt(String value) {
  // int.tryParse alone would also accept forms like "+5" and "0x10"
  if (!RegExp(r'^[1-9]\d*$').hasMatch(value)) return null;
  return int.tryParse(value);
}

/// 400 response for a bad `?page=` or `?limit=`
Response invalidPaging() => Response.json(
      statusCode: 400,
      body: {
        'error': 'invalid',
        'message': 'page must be a positive number and '
            'limit must be from 1 to $maxLimit.',
      },
    );

/// 404 response for a mood or title that doesn't exist
Response notFound(String thing) => Response.json(
      statusCode: 404,
      body: {'error': 'not_found', 'message': '$thing not found.'},
    );
