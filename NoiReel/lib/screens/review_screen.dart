import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_scope.dart';
import '../widgets/action_colors.dart';
import '../widgets/dates.dart';
import '../widgets/dialogs.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/library_events.dart';
import '../widgets/poster_card.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/review_card.dart';
import '../widgets/star_rating.dart';
import 'add_comment_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'review_log_screen.dart';

/// One review on its own page, like Letterboxd's: the author, the title,
/// their stars and heart, the date watched, the review (a spoiler one is
/// hidden until "Show review"), its likes, and every comment below it on
/// the same page. The + button adds a comment. The author's 3 dots menu
/// edits or deletes it.
///
/// Returns true when it closes if anything changed (likes, comments, an
/// edit or a delete), so the page that opened it can reload
class ReviewScreen extends StatefulWidget {
  /// Creates the page for review [reviewId]. [preview] (e.g. the tapped
  /// card) is shown while the rest loads
  const ReviewScreen({
    super.key,
    required this.api,
    required this.reviewId,
    this.preview,
  });

  final ApiClient api;
  final int reviewId;
  final Review? preview;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late Review? _review = widget.preview;
  List<ReviewComment>? _comments; // Null until loaded
  String? _error;
  bool _revealed = false; // Spoiler review shown anyway
  bool _changed = false;
  bool _busy = false;     // Editing or deleting
  final _liking = <int>{}; // Comment ids with a like being saved

  AuthController? get _auth => AuthScope.maybeOf(context);
  String? get _token => _auth?.value?.token;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_comments == null && _error == null) _load();
  }

  Future<void> _load() async {
    try {
      final data = await widget.api.getReview(widget.reviewId, token: _token);
      if (!mounted) return;
      setState(() {
        _review = data.review;
        _comments = data.comments;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _leave() => Navigator.of(context).pop(_changed);

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// The user's token if they can like and comment; otherwise asks a
  /// guest to sign in (or tells an admin they can't) and returns null
  Future<String?> _signedIn() async {
    final auth = _auth;
    final session = auth?.value;
    if (auth == null || session == null) {
      final choice = await askGuestToSignIn(context, 'to like and comment');
      if (choice == null || !mounted || auth == null) return null;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => choice == GuestChoice.signIn
              ? LoginScreen(auth: auth)
              : RegisterScreen(auth: auth),
        ),
      );
      return null;
    }
    if (session.isAdmin) {
      _snack("Admin accounts can't like or comment.");
      return null;
    }
    return session.token;
  }

  Future<void> _toggleReviewLike() async {
    final review = _review;
    if (review == null || review.isMine) return;
    final token = await _signedIn();
    if (token == null || !mounted) return;

    final like = !review.likedByMe;
    // Shown right away; put back if saving fails
    setState(() {
      _review = review.withLikes(
        count: review.likeCount + (like ? 1 : -1),
        mine: like,
      );
    });
    try {
      final saved = await widget.api.setReviewLike(
        token,
        review.id,
        like: like,
      );
      _changed = true;
      if (mounted) {
        setState(() {
          _review = _review?.withLikes(count: saved.count, mine: saved.mine);
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _review = review);
      _snack(e.message);
    }
  }

  Future<void> _toggleCommentLike(ReviewComment comment) async {
    if (comment.isMine || _liking.contains(comment.id)) return;
    final token = await _signedIn();
    if (token == null || !mounted) return;

    final like = !comment.likedByMe;
    void replace(ReviewComment c) => setState(() {
      _comments = [
        for (final x in _comments ?? <ReviewComment>[])
          x.id == c.id ? c : x,
      ];
    });

    _liking.add(comment.id);
    replace(
      comment.withLikes(
        count: comment.likeCount + (like ? 1 : -1),
        mine: like,
      ),
    );
    try {
      final saved = await widget.api.setCommentLike(
        token,
        comment.id,
        like: like,
      );
      if (mounted) {
        replace(comment.withLikes(count: saved.count, mine: saved.mine));
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      replace(comment);
      _snack(e.message);
    } finally {
      _liking.remove(comment.id);
    }
  }

  Future<void> _addComment() async {
    final token = await _signedIn();
    final auth = _auth;
    if (token == null || auth == null || !mounted) return;
    final posted = await Navigator.of(context).push<ReviewComment>(
      MaterialPageRoute(
        builder: (_) => AddCommentScreen(
          api: widget.api,
          auth: auth,
          reviewId: widget.reviewId,
        ),
      ),
    );
    if (posted == null || !mounted) return;
    _changed = true;
    setState(() => _comments = [...?_comments, posted]);
    _snack('Comment posted.');
  }

  Future<void> _deleteComment(ReviewComment comment) async {
    final yes = await confirmDelete(
      context,
      title: 'Delete your comment?',
      message: 'It will be gone for good, along with its likes.',
    );
    final token = _token;
    if (!yes || token == null || !mounted) return;
    try {
      await widget.api.deleteComment(token, comment.id);
      _changed = true;
      if (!mounted) return;
      setState(() {
        _comments = [
          for (final c in _comments ?? <ReviewComment>[])
            if (c.id != comment.id) c,
        ];
      });
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    }
  }

  /// The author's Edit: opens the review editor filled in
  Future<void> _edit() async {
    final review = _review;
    final auth = _auth;
    final token = _token;
    if (review == null || auth == null || token == null) return;

    setState(() => _busy = true);
    try {
      final status = await widget.api.getTitleStatus(token, review.title.id);
      if (!mounted) return;
      setState(() => _busy = false);
      final saved = await Navigator.of(context).push<TitleStatus>(
        MaterialPageRoute(
          builder: (_) => ReviewLogScreen(
            api: widget.api,
            auth: auth,
            title: review.title,
            existing: status.entry,
          ),
        ),
      );
      if (saved == null || !mounted) return;
      _changed = true;
      if (saved.entry.reviewId != widget.reviewId) {
        // The review text was removed, so this review is gone
        _leave();
        return;
      }
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(e.message);
    }
  }

  /// The author's Delete: removes their date, rating, review and moods
  Future<void> _delete() async {
    final review = _review;
    final token = _token;
    if (review == null || token == null) return;
    final yes = await confirmDelete(
      context,
      title: 'Delete your review?',
      message:
      'Your date, rating, review, mood votes and its comments for '
          '${review.title.name} will be removed.',
    );
    if (!yes || !mounted) return;

    setState(() => _busy = true);
    try {
      await widget.api.deleteEntry(token, review.title.id);
      notifyLibraryChanged();
      _changed = true;
      if (mounted) _leave();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final navText = theme.colorScheme.onSecondary;
    final review = _review;
    final comments = _comments;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          leadingWidth: BackTextButton.width,
          leading: const BackTextButton(),
          title: Text(
            review == null
                ? 'Review'
                : review.isMine
                ? 'Your Review'
                : "${review.author.shownName}'s Review",
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            if (_busy)
              Padding(
                padding: const EdgeInsets.all(14),
                child: SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: navText,
                  ),
                ),
              )
            else if (review?.isMine ?? false)
              PopupMenuButton<String>(
                tooltip: 'Review options',
                icon: Icon(Icons.more_vert, color: navText),
                color: theme.scaffoldBackgroundColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (choice) => choice == 'edit' ? _edit() : _delete(),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('Delete'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            const SizedBox(width: 4),
          ],
        ),
        // Add comment, in the middle above the nav bar like the list +
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: review == null
            ? null
            : FloatingActionButton.small(
          tooltip: 'Add comment',
          onPressed: _addComment,
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          shape: const CircleBorder(),
          child: const Icon(Icons.add),
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 96),
                children: [
                  if (review == null)
                    _loadingOrError()
                  else ...[
                    FadeSlideIn(
                      child: _ReviewHeader(api: widget.api, review: review),
                    ),
                    FadeSlideIn.staggered(
                      index: 1,
                      child: _ReviewBody(
                        review: review,
                        revealed: _revealed,
                        onReveal: () => setState(() => _revealed = true),
                      ),
                    ),
                    _LikeRow(review: review, onToggle: _toggleReviewLike),
                    Divider(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.25,
                      ),
                      height: 1.5,
                      thickness: 1.5,
                    ),
                    if (comments == null)
                      _loadingOrError()
                    else
                      _CommentList(
                        api: widget.api,
                        comments: comments,
                        liking: _liking,
                        onLike: _toggleCommentLike,
                        onDelete: _deleteComment,
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _loadingOrError() {
    final error = _error;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: error == null
            ? const CircularProgressIndicator()
            : Column(
          children: [
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                setState(() => _error = null);
                _load();
              },
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The author's photo and name, the title and year, their stars and
/// heart, and when they watched it; the poster on the right
class _ReviewHeader extends StatelessWidget {
  const _ReviewHeader({required this.api, required this.review});

  final ApiClient api;
  final Review review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.7);
    final avatar = review.author.avatarUrl;
    final watched = review.watchedOn;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ProfileAvatar(
                      radius: 18,
                      image: avatar == null
                          ? null
                          : NetworkImage(api.mediaUrl(avatar)),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        review.author.shownName,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: muted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text.rich(
                  TextSpan(
                    text: review.title.name,
                    children: [
                      if (review.title.year != null)
                        TextSpan(
                          text: '  ${review.title.year}',
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w400,
                            color: muted,
                          ),
                        ),
                    ],
                  ),
                  style: text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (review.stars != null)
                      StarRating(value: review.stars, size: 22),
                    if (review.favorite) ...[
                      const SizedBox(width: 6),
                      Semantics(
                        container: true,
                        label: 'In their Favorites',
                        excludeSemantics: true,
                        child: Icon(
                          Icons.favorite,
                          size: 20,
                          color: activeActionColor(
                            context,
                            background: theme.scaffoldBackgroundColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (watched != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Watched ${formatDate(watched)}',
                    style: text.bodyMedium?.copyWith(color: muted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 104,
            child: PosterImage(
              url: review.title.posterUrl,
              type: review.title.type,
            ),
          ),
        ],
      ),
    );
  }
}

/// The review text. Someone else's spoiler review stays hidden until
/// "Show review" is tapped
class _ReviewBody extends StatelessWidget {
  const _ReviewBody({
    required this.review,
    required this.revealed,
    required this.onReveal,
  });

  final Review review;
  final bool revealed;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final bodyText = theme.colorScheme.onSurface;
    final muted = bodyText.withValues(alpha: 0.7);

    if (review.spoiler && !review.isMine && !revealed) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: SpoilerWarning(
          message: 'This review may contain spoilers.',
          onReveal: onReveal,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (review.spoiler)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SpoilerBadge(),
                  if (review.isMine) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Others see a spoiler warning until they tap Show '
                          'review.',
                      style: text.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ],
              ),
            ),
          Text(review.body, style: text.bodyLarge?.copyWith(height: 1.5)),
          if (review.edited)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Edited', style: text.bodySmall),
            ),
        ],
      ),
    );
  }
}

/// "Like?" with a heart, and how many likes. The author sees only the
/// count, since you can't like your own review
class _LikeRow extends StatelessWidget {
  const _LikeRow({required this.review, required this.onToggle});

  final Review review;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final bodyText = theme.colorScheme.onSurface;
    final muted = bodyText.withValues(alpha: 0.7);
    final n = review.likeCount;
    final count = n == 0 ? 'No likes yet' : '$n ${n == 1 ? 'like' : 'likes'}';
    final liked = review.likedByMe;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 20, 12),
      child: Row(
        children: [
          if (!review.isMine)
            Semantics(
              container: true,
              button: true,
              toggled: liked,
              label: 'Like review',
              excludeSemantics: true,
              child: InkWell(
                onTap: onToggle,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        liked ? Icons.favorite : Icons.favorite_border,
                        size: 22,
                        color: liked
                            ? activeActionColor(
                          context,
                          background: theme.scaffoldBackgroundColor,
                        )
                            : muted,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        liked ? 'LIKED' : 'LIKE?',
                        style: text.labelLarge?.copyWith(
                          letterSpacing: 1.2,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: 12),
          Text(count, style: text.bodyMedium?.copyWith(color: muted)),
        ],
      ),
    );
  }
}

/// Every comment, oldest first, each with its likes
class _CommentList extends StatelessWidget {
  const _CommentList({
    required this.api,
    required this.comments,
    required this.liking,
    required this.onLike,
    required this.onDelete,
  });

  final ApiClient api;
  final List<ReviewComment> comments;
  final Set<int> liking;
  final ValueChanged<ReviewComment> onLike;
  final ValueChanged<ReviewComment> onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final bodyText = theme.colorScheme.onSurface;
    final n = comments.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
          child: Text(
            n == 0 ? 'COMMENTS' : '$n ${n == 1 ? 'COMMENT' : 'COMMENTS'}',
            style: text.labelLarge?.copyWith(
              letterSpacing: 1.4,
              color: bodyText.withValues(alpha: 0.8),
            ),
          ),
        ),
        if (n == 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Text(
              'No comments yet. Tap + to add the first one.',
              style: text.bodyMedium?.copyWith(
                color: bodyText.withValues(alpha: 0.7),
              ),
            ),
          ),
        for (final (i, c) in comments.indexed) ...[
          if (i > 0)
            Divider(
              indent: 72,
              height: 1,
              color: bodyText.withValues(alpha: 0.15),
            ),
          FadeSlideIn.staggered(
            index: i < 10 ? i : 0,
            step: const Duration(milliseconds: 40),
            distance: 12,
            child: _CommentTile(
              api: api,
              comment: c,
              busy: liking.contains(c.id),
              onLike: () => onLike(c),
              onDelete: () => onDelete(c),
            ),
          ),
        ],
      ],
    );
  }
}

/// One comment: photo, name, how long ago, the text, and its likes
class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.api,
    required this.comment,
    required this.busy,
    required this.onLike,
    required this.onDelete,
  });

  final ApiClient api;
  final ReviewComment comment;
  final bool busy;
  final VoidCallback onLike;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.7);
    final avatar = comment.author.avatarUrl;
    final liked = comment.likedByMe;
    final n = comment.likeCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfileAvatar(
            radius: 18,
            image: avatar == null ? null : NetworkImage(api.mediaUrl(avatar)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        comment.isMine ? 'You' : comment.author.shownName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: muted,
                        ),
                      ),
                    ),
                    Text(
                      timeAgo(comment.createdAt),
                      style: text.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(comment.body, style: text.bodyLarge),
                Row(
                  children: [
                    if (comment.isMine)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Icon(
                          Icons.favorite_border,
                          size: 18,
                          color: muted.withValues(alpha: 0.4),
                        ),
                      )
                    else
                      IconButton(
                        tooltip: liked ? 'Unlike comment' : 'Like comment',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        onPressed: busy ? null : onLike,
                        icon: Icon(
                          liked ? Icons.favorite : Icons.favorite_border,
                          size: 18,
                          color: liked
                              ? activeActionColor(
                            context,
                            background: theme.scaffoldBackgroundColor,
                          )
                              : muted,
                        ),
                      ),
                    Padding(
                      padding: EdgeInsets.only(left: comment.isMine ? 8 : 0),
                      child: Text(
                        n == 0 ? '' : '$n ${n == 1 ? 'like' : 'likes'}',
                        style: text.bodySmall?.copyWith(color: muted),
                      ),
                    ),
                    const Spacer(),
                    if (comment.isMine)
                      IconButton(
                        tooltip: 'Delete comment',
                        visualDensity: VisualDensity.compact,
                        onPressed: onDelete,
                        icon: Icon(Icons.delete_outline, size: 20, color: muted),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}