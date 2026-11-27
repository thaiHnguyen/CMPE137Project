import 'package:mysql_client/mysql_client.dart';
import 'package:server/models/title.dart';

/// Who wrote a review or comment
class Author {
  /// Reads the author columns of a `ReviewDao` row
  Author.fromRow(ResultSetRow row)
      : id = int.parse(row.colByName('user_id')!),
        username = row.colByName('username')!,
        displayName = row.colByName('display_name'),
        avatarUrl = row.colByName('avatar_url');

  /// `user_accounts.user_id`
  final int id;
  /// Username
  final String username;
  /// Display name, or null to show the username
  final String? displayName;
  /// Avatar path (e.g. `/avatars/7-123.jpg`), or null
  final String? avatarUrl;

  /// JSON sent to the app
  Map<String, dynamic> toJson() => {
    'userId': id,
    'username': username,
    'displayName': displayName,
    'avatarUrl': avatarUrl,
  };
}

/// A review as shown in a list or on its own page
class Review {
  /// Reads a `ReviewDao` row. [viewerId] is who's asking (0 for a guest)
  Review.fromRow(ResultSetRow row, {required int viewerId})
      : id = int.parse(row.colByName('review_id')!),
        author = Author.fromRow(row),
        title = TitleCard.fromRow(row),
        body = row.colByName('body')!,
        spoiler = row.colByName('is_spoiler') == '1',
        edited = row.colByName('is_edited') == '1',
        createdAt = int.parse(row.colByName('created_unix')!),
        stars = switch (row.colByName('stars')) {
          final String s => double.parse(s),
          _ => null,
        },
        watchedOn = row.colByName('watched_on'),
        favorite = row.colByName('favorite') == '1',
        likeCount = int.parse(row.colByName('like_count')!),
        commentCount = int.parse(row.colByName('comment_count')!),
        likedByMe = row.colByName('liked_by_me') == '1',
        isMine = int.parse(row.colByName('user_id')!) == viewerId;

  /// `reviews.review_id`
  final int id;
  /// Who wrote it
  final Author author;
  /// The title it's about
  final TitleCard title;
  /// The review text
  final String body;
  /// The author marked it as giving away the plot
  final bool spoiler;
  /// Changed after it was first posted
  final bool edited;
  /// When it was posted, in seconds since 1970 (UTC)
  final int createdAt;
  /// The author's rating of the title, or null
  final double? stars;
  /// The author's latest watch date (`YYYY-MM-DD`), or null
  final String? watchedOn;
  /// The title is in the author's Favorites (the heart)
  final bool favorite;
  /// Number of likes
  final int likeCount;
  /// Number of visible comments
  final int commentCount;
  /// The person asking has liked it
  final bool likedByMe;
  /// The person asking wrote it
  final bool isMine;

  /// JSON sent to the app
  Map<String, dynamic> toJson() => {
    'reviewId': id,
    'author': author.toJson(),
    'title': title.toJson(),
    'body': body,
    'spoiler': spoiler,
    'edited': edited,
    'createdAt': createdAt,
    'stars': stars,
    'watchedOn': watchedOn,
    'favorite': favorite,
    'likeCount': likeCount,
    'commentCount': commentCount,
    'likedByMe': likedByMe,
    'isMine': isMine,
  };
}

/// A comment under a review
class ReviewComment {
  /// Reads a `ReviewDao` comment row. [viewerId] is who's asking
  ReviewComment.fromRow(ResultSetRow row, {required int viewerId})
      : id = int.parse(row.colByName('comment_id')!),
        author = Author.fromRow(row),
        body = row.colByName('body')!,
        createdAt = int.parse(row.colByName('created_unix')!),
        likeCount = int.parse(row.colByName('like_count')!),
        likedByMe = row.colByName('liked_by_me') == '1',
        isMine = int.parse(row.colByName('user_id')!) == viewerId;

  /// `review_comments.comment_id`
  final int id;
  /// Who wrote it
  final Author author;
  /// The comment text
  final String body;
  /// When it was posted, in seconds since 1970 (UTC)
  final int createdAt;
  /// Number of likes
  final int likeCount;
  /// The person asking has liked it
  final bool likedByMe;
  /// The person asking wrote it
  final bool isMine;

  /// JSON sent to the app
  Map<String, dynamic> toJson() => {
    'commentId': id,
    'author': author.toJson(),
    'body': body,
    'createdAt': createdAt,
    'likeCount': likeCount,
    'likedByMe': likedByMe,
    'isMine': isMine,
  };
}
