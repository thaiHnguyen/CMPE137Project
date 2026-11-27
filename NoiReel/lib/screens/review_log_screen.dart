import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../auth/auth_controller.dart';
import '../widgets/dates.dart';
import '../widgets/dialogs.dart';
import '../widgets/leave_guard.dart';
import '../widgets/library_events.dart';
import '../widgets/mood_chip.dart';
import '../widgets/poster_card.dart';
import '../widgets/star_rating.dart';

/// Review or log a title, like Letterboxd's "I Watched" page: the date
/// (optional), a star rating, mood votes, the review, and whether it has
/// spoilers. x closes (asking "Discard changes?" if anything changed, as
/// do Android back and the nav bar) and the check mark saves.
/// Returns the saved [TitleStatus], or null
class ReviewLogScreen extends StatefulWidget {
  /// Creates the page for [title], starting from [existing] when editing
  const ReviewLogScreen({
    super.key,
    required this.api,
    required this.auth,
    required this.title,
    this.existing,
  });

  final ApiClient api;        // Connection to the server
  final AuthController auth;  // The logged-in user
  final TitleCard title;      // What's being reviewed

  /// The saved review and log when editing, or null for a new one
  final TitleEntry? existing;

  /// Most moods one person can vote on a title (same as the server)
  static const maxMoods = 3;

  /// Longest review (the server allows 5000)
  static const maxReview = 5000;

  @override
  State<ReviewLogScreen> createState() => _ReviewLogScreenState();
}

class _ReviewLogScreenState extends State<ReviewLogScreen> {
  // A new log starts with today's date, like Letterboxd; it can be removed
  late DateTime? _date = widget.existing == null
      ? today()
      : widget.existing!.watchedOn;
  late double? _stars = widget.existing?.stars;
  late final List<int> _moodIds = [...?widget.existing?.moodIds];
  late final _review = TextEditingController(text: widget.existing?.review);
  late bool _spoiler = widget.existing?.spoiler ?? false;

  late final Future<List<Mood>> _moods = widget.api.getMoods();
  bool _saving = false;
  bool _leaving = false;

  LeaveGuard? _guard;
  ModalRoute<Object?>? _route;

  bool get _isEditing => widget.existing != null;

  /// True when anything differs from how the page started
  bool get _dirty {
    final e = widget.existing ?? TitleEntry(watchedOn: today());
    return _date != e.watchedOn ||
        _stars != e.stars ||
        _review.text.trim() != (e.review ?? '') ||
        _spoiler != e.spoiler ||
        _moodIds.length != e.moodIds.length ||
        !_moodIds.every(e.moodIds.contains);
  }

  @override
  void initState() {
    super.initState();
    _review.addListener(() => setState(() {})); // updates _dirty
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route ??= ModalRoute.of(context);
    final guard = LeaveGuardScope.maybeOf(context);
    if (guard != _guard) {
      _guard?.unregister(_confirmLeave);
      _guard = guard?..register(_confirmLeave);
    }
  }

  @override
  void dispose() {
    _guard?.unregister(_confirmLeave);
    _review.dispose();
    super.dispose();
  }

  /// Asked by the nav bar before switching tabs
  Future<bool> _confirmLeave() async {
    if (!_dirty || _leaving) return true;
    if (!await confirmDiscard(context) || !mounted) return false;
    _close();
    return true;
  }

  /// Closes this page, along with anything opened on top of it
  void _close([TitleStatus? saved]) {
    setState(() => _leaving = true);
    final navigator = Navigator.of(context);
    final route = _route;
    if (route != null && !route.isCurrent) {
      navigator.popUntil((r) => r == route);
    }
    navigator.pop(saved);
  }

  Future<void> _onBlockedPop() async {
    if (await confirmDiscard(context) && mounted) _close();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickDate() async {
    final now = today();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(1870),
      lastDate: now,
      helpText: 'Date watched',
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  void _toggleMood(int moodId) {
    setState(() {
      if (_moodIds.contains(moodId)) {
        _moodIds.remove(moodId);
      } else if (_moodIds.length >= ReviewLogScreen.maxMoods) {
        _snack(
          'Pick up to ${ReviewLogScreen.maxMoods} moods. Tap one to '
          'remove it first.',
        );
      } else {
        _moodIds.add(moodId);
      }
    });
  }

  Future<void> _save() async {
    final token = widget.auth.value?.token;
    if (token == null) {
      _snack('Log in again to save your review.');
      return;
    }
    final review = _review.text.trim();
    final entry = TitleEntry(
      watchedOn: _date,
      stars: _stars,
      review: review.isEmpty ? null : review,
      spoiler: review.isNotEmpty && _spoiler,
      moodIds: [..._moodIds],
    );
    if (entry.watchedOn == null &&
        entry.stars == null &&
        entry.review == null &&
        entry.moodIds.isEmpty) {
      _snack('Add a date, a rating, a mood or a review first.');
      return;
    }

    setState(() => _saving = true);
    try {
      final saved = await widget.api.saveEntry(token, widget.title.id, entry);
      notifyLibraryChanged();
      if (mounted) _close(saved);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final colors = theme.colorScheme;
    final navText = colors.onSecondary;
    final bodyText = colors.onSurface;
    final muted = bodyText.withValues(alpha: 0.7);
    final date = _date;
    final line = Divider(
      color: bodyText.withValues(alpha: 0.2),
      height: 1,
      thickness: 1,
    );

    return PopScope(
      canPop: !_dirty || _leaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBlockedPop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Cancel',
            icon: Icon(Icons.close, color: navText),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(_isEditing ? 'Edit review' : 'I Watched'),
          actions: [
            if (_saving)
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
              IconButton(
                tooltip: 'Save',
                icon: Icon(Icons.check, color: navText),
                onPressed: _save,
              ),
            const SizedBox(width: 4),
          ],
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              children: [
                // The title
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 40,
                        child: PosterImage(
                          url: widget.title.posterUrl,
                          type: widget.title.type,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            text: widget.title.name,
                            children: [
                              if (widget.title.year != null)
                                TextSpan(
                                  text: '  ${widget.title.year}',
                                  style: TextStyle(
                                    color: muted,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                            ],
                          ),
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                line,

                // Date (optional)
                InkWell(
                  onTap: _saving ? null : _pickDate,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
                    child: Row(
                      children: [
                        Text('Date', style: text.bodyLarge),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            date == null
                                ? 'Add date'
                                : formatDateWithDay(date),
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodyLarge?.copyWith(
                              color: date == null ? muted : null,
                            ),
                          ),
                        ),
                        if (date != null)
                          IconButton(
                            tooltip: 'Remove date',
                            icon: const Icon(Icons.cancel, size: 22),
                            color: muted,
                            onPressed: _saving
                                ? null
                                : () => setState(() => _date = null),
                          )
                        else
                          const SizedBox(width: 48, height: 48),
                      ],
                    ),
                  ),
                ),
                line,

                // Rating
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StarRating(
                        value: _stars,
                        onChanged: _saving
                            ? null
                            : (v) => setState(() => _stars = v),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _stars == null
                            ? 'Rate'
                            : 'Rated ${_starsText(_stars!)}  ·  tap again '
                                  'to clear',
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                ),
                line,

                // Mood votes
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MOOD  ·  pick up to ${ReviewLogScreen.maxMoods}',
                        style: text.labelLarge?.copyWith(
                          letterSpacing: 1.3,
                          color: muted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FutureBuilder<List<Mood>>(
                        future: _moods,
                        builder: (context, snapshot) {
                          final moods = snapshot.data;
                          if (snapshot.hasError) {
                            return Text(
                              "Couldn't load the moods.",
                              style: text.bodySmall,
                            );
                          }
                          if (moods == null) {
                            return const SizedBox(
                              height: 36,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                  ),
                                ),
                              ),
                            );
                          }
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final m in moods)
                                MoodChip(
                                  name: m.name,
                                  selected: _moodIds.contains(m.id),
                                  onTap: _saving
                                      ? null
                                      : () => _toggleMood(m.id),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                line,

                // Review
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                  child: TextField(
                    controller: _review,
                    enabled: !_saving,
                    minLines: 8,
                    maxLines: null,
                    maxLength: ReviewLogScreen.maxReview,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    style: text.bodyLarge,
                    decoration: const InputDecoration(
                      hintText: 'Add review...',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      filled: false,
                      counterText: '',
                    ),
                  ),
                ),
                line,

                // Spoilers
                _SpoilerToggle(
                  spoiler: _spoiler,
                  enabled: !_saving && _review.text.trim().isNotEmpty,
                  onChanged: (v) => setState(() => _spoiler = v),
                ),
                line,
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _starsText(double stars) {
    final n = stars % 1 == 0 ? '${stars.toInt()}' : '$stars';
    return '$n ${stars == 1 ? 'star' : 'stars'}';
  }
}

/// "No spoilers" / "Contains spoilers" at the bottom. Only usable once
/// there's a review to mark
class _SpoilerToggle extends StatelessWidget {
  const _SpoilerToggle({
    required this.spoiler,
    required this.enabled,
    required this.onChanged,
  });

  final bool spoiler;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bodyText = theme.colorScheme.onSurface;
    final on = spoiler && enabled;
    final color = on
        ? theme.colorScheme.primary
        : bodyText.withValues(alpha: enabled ? 0.75 : 0.35);

    return Semantics(
      toggled: on,
      button: true,
      enabled: enabled,
      label: 'Contains spoilers',
      excludeSemantics: true,
      child: InkWell(
        onTap: enabled ? () => onChanged(!spoiler) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(
                on ? Icons.visibility_off : Icons.visibility_outlined,
                size: 34,
                color: color,
              ),
              const SizedBox(height: 6),
              Text(
                on ? 'Contains spoilers' : 'No spoilers',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: on ? FontWeight.w800 : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
