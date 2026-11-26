import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../auth/auth_controller.dart';
import '../widgets/action_colors.dart';
import '../widgets/dates.dart';
import '../widgets/dialogs.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/library_events.dart';
import '../widgets/mood_chip.dart';
import '../widgets/poster_card.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/star_rating.dart';
import 'review_log_screen.dart';

/// "Your Review": the user's review and log of one title, like
/// Letterboxd's. The 3 dots menu edits or deletes it. Returns the latest
/// [TitleStatus] when it closes if anything changed, or null
class MyReviewScreen extends StatefulWidget {
  /// Creates the page for [title], showing [status]
  const MyReviewScreen({
    super.key,
    required this.api,
    required this.auth,
    required this.title,
    required this.status,
  });

  final ApiClient api;          // Connection to the server
  final AuthController auth;    // The logged-in user
  final TitleCard title;        // What was reviewed
  final TitleStatus status;     // Their review and log, as last loaded

  @override
  State<MyReviewScreen> createState() => _MyReviewScreenState();
}

class _MyReviewScreenState extends State<MyReviewScreen> {
  late TitleStatus _status = widget.status;
  bool _changed = false;  // Edited or deleted: tell the details page
  bool _deleting = false;

  late final Future<Profile?> _me = _loadProfile();
  late final Future<List<Mood>> _moods = widget.api.getMoods();

  Future<Profile?> _loadProfile() async {
    final token = widget.auth.value?.token;
    if (token == null) return null;
    try {
      return await widget.api.getProfile(token);
    } on ApiException {
      return null; // the page still works without the name and photo
    }
  }

  void _leave() => Navigator.of(context).pop(_changed ? _status : null);

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<TitleStatus>(
      MaterialPageRoute(
        builder: (_) => ReviewLogScreen(
          api: widget.api,
          auth: widget.auth,
          title: widget.title,
          existing: _status.entry,
        ),
      ),
    );
    if (saved == null || !mounted) return;
    setState(() {
      _status = saved;
      _changed = true;
    });
  }

  Future<void> _delete() async {
    final yes = await confirmDelete(
      context,
      title: 'Delete your review?',
      message:
          'Your date, rating, review and mood votes for '
          '${widget.title.name} will be removed.',
    );
    if (!yes || !mounted) return;
    final token = widget.auth.value?.token;
    if (token == null) {
      _snack('Log in again to delete your review.');
      return;
    }

    setState(() => _deleting = true);
    try {
      _status = await widget.api.deleteEntry(token, widget.title.id);
      _changed = true;
      notifyLibraryChanged();
      if (mounted) _leave();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      _snack(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final navText = theme.colorScheme.onSecondary;
    final bodyText = theme.colorScheme.onSurface;
    final entry = _status.entry;
    final watched = entry.watchedOn;
    final review = entry.review;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          leadingWidth: BackTextButton.width,
          leading: const BackTextButton(),
          title: const Text('Your Review'),
          actions: [
            if (_deleting)
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
            else
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
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              children: [
                FadeSlideIn(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Author(me: _me, api: widget.api),
                            const SizedBox(height: 16),
                            Text.rich(
                              TextSpan(
                                text: widget.title.name,
                                children: [
                                  if (widget.title.year != null)
                                    TextSpan(
                                      text: '  ${widget.title.year}',
                                      style: text.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w400,
                                        color: bodyText.withValues(
                                          alpha: 0.7,
                                        ),
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
                                if (entry.stars != null)
                                  StarRating(value: entry.stars, size: 22),
                                if (_status.favorite) ...[
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.favorite,
                                    size: 20,
                                    color: favoriteColor,
                                    semanticLabel: 'In your Favorites',
                                  ),
                                ],
                              ],
                            ),
                            if (watched != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                'Watched ${formatDate(watched)}',
                                style: text.bodyMedium?.copyWith(
                                  color: bodyText.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 104,
                        child: PosterImage(
                          url: widget.title.posterUrl,
                          type: widget.title.type,
                        ),
                      ),
                    ],
                  ),
                ),
                if (entry.moodIds.isNotEmpty)
                  FutureBuilder<List<Mood>>(
                    future: _moods,
                    builder: (context, snapshot) {
                      final moods = snapshot.data ?? const <Mood>[];
                      final names = {for (final m in moods) m.id: m.name};
                      return Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final id in entry.moodIds)
                              if (names[id] != null)
                                MoodChip(name: names[id]!),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 20),
                if (review != null) ...[
                  if (entry.spoiler)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Icon(
                            Icons.visibility_off,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Contains spoilers',
                            style: text.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  FadeSlideIn.staggered(
                    index: 1,
                    child: Text(
                      review,
                      style: text.bodyLarge?.copyWith(height: 1.5),
                    ),
                  ),
                ] else
                  Text(
                    'No review written. Use the 3 dots menu to add one.',
                    style: text.bodyMedium?.copyWith(
                      color: bodyText.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The user's photo and name above the review
class _Author extends StatelessWidget {
  const _Author({required this.me, required this.api});

  final Future<Profile?> me;
  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Profile?>(
      future: me,
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final avatar = profile?.avatarUrl;
        return Row(
          children: [
            ProfileAvatar(
              radius: 18,
              image: avatar == null ? null : NetworkImage(api.mediaUrl(avatar)),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                profile?.shownName ?? '',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
