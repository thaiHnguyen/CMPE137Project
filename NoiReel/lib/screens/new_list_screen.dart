import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../auth/auth_controller.dart';
import '../widgets/dialogs.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/form_parts.dart';
import '../widgets/leave_guard.dart';
import '../widgets/poster_card.dart';
import 'search_screen.dart';

/// Create a list (RU-08.01): a name, an optional description, and entries
/// added through search, kept in the order they were added.
///
/// Leaving with unsaved changes, through Back or the nav bar, asks
/// "Discard changes?" first. Returns the new list when Done succeeds
class NewListScreen extends StatefulWidget {
  /// Creates the New List page
  const NewListScreen({super.key, required this.api, required this.auth});

  final ApiClient api;        // Connection to the server
  final AuthController auth;  // The logged-in user (lists need a token)

  /// Longest list name (the server allows 60)
  static const maxName = 60;

  /// Longest description (the server allows 500)
  static const maxDescription = 500;

  @override
  State<NewListScreen> createState() => _NewListScreenState();
}

class _NewListScreenState extends State<NewListScreen> {
  final _name = TextEditingController();
  String _description = '';
  final List<TitleCard> _entries = []; // In the order they were added

  bool _saving = false;
  bool _leaving = false;  // Saved or discarded: let the page close
  String? _nameError;
  String? _error;

  LeaveGuard? _guard;
  ModalRoute<Object?>? _route;

  /// True once anything has been typed or added
  bool get _dirty =>
      _name.text.trim().isNotEmpty ||
      _description.trim().isNotEmpty ||
      _entries.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {})); // updates _dirty for PopScope
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
    _name.dispose();
    super.dispose();
  }

  /// Asked by the nav bar before switching tabs. Returns true to go ahead;
  /// on "Yes, discard" this page closes first
  Future<bool> _confirmLeave() async {
    if (!_dirty || _leaving) return true;
    if (!await confirmDiscard(context) || !mounted) return false;
    _close();
    return true;
  }

  /// Closes this page, along with anything opened on top of it
  /// (search, the description editor)
  void _close([UserListDetails? created]) {
    setState(() => _leaving = true);
    final navigator = Navigator.of(context);
    final route = _route;
    if (route != null && !route.isCurrent) {
      navigator.popUntil((r) => r == route);
    }
    navigator.pop(created);
  }

  /// Back button or Android back, while there are unsaved changes
  Future<void> _onBlockedPop() async {
    if (await confirmDiscard(context) && mounted) _close();
  }

  Future<void> _editDescription() async {
    final text = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => _DescriptionScreen(initial: _description),
      ),
    );
    if (text != null && mounted) setState(() => _description = text);
  }

  Future<void> _addEntries() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => StatefulBuilder(
          // Rebuilds the search page's check marks as titles are added
          builder: (context, refresh) => SearchScreen(
            api: widget.api,
            pickedIds: {for (final e in _entries) e.id},
            onPick: (title) => _pick(context, title, () => refresh(() {})),
            appBar: AppBar(
              leadingWidth: BackTextButton.width,
              leading: const BackTextButton(),
              title: const Text('Add entries'),
            ),
          ),
        ),
      ),
    );
  }

  /// Adds [title] at the end and goes back to the list
  void _pick(BuildContext searchContext, TitleCard title, VoidCallback done) {
    if (_entries.any((e) => e.id == title.id)) {
      ScaffoldMessenger.of(searchContext)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('${title.name} is already in this list.')),
        );
      return;
    }
    setState(() => _entries.add(title));
    done();
    Navigator.of(searchContext).pop();
  }

  void _remove(TitleCard title) =>
      setState(() => _entries.removeWhere((e) => e.id == title.id));

  Future<void> _done() async {
    final name = _name.text.trim();
    setState(() {
      _nameError = name.isEmpty ? 'Give your list a name.' : null;
      _error = null;
    });
    if (name.isEmpty || _saving) return;

    final token = widget.auth.value?.token;
    if (token == null) {
      setState(() => _error = 'Log in again to save this list.');
      return;
    }

    setState(() => _saving = true);
    try {
      final created = await widget.api.createList(
        token,
        name: name,
        description: _description.trim().isEmpty ? null : _description.trim(),
        titleIds: [for (final e in _entries) e.id],
      );
      if (mounted) _close(created);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.field == 'name') {
          _nameError = e.message;
        } else if (e.statusCode == 401) {
          _error = 'Your session has ended. Log in again to save this list.';
        } else {
          _error = e.message;
        }
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final navText = theme.colorScheme.onSecondary;

    return PopScope(
      canPop: !_dirty || _leaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBlockedPop();
      },
      child: Scaffold(
        appBar: AppBar(
          leadingWidth: BackTextButton.width,
          leading: const BackTextButton(),
          title: const Text('New List'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _saving
                  ? Padding(
                      padding: const EdgeInsets.all(14),
                      child: SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: navText,
                        ),
                      ),
                    )
                  : TextButton(
                      onPressed: _done,
                      style: TextButton.styleFrom(
                        foregroundColor: navText,
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      child: const Text('Done'),
                    ),
            ),
          ],
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              children: [
                FadeSlideIn(
                  child: TextField(
                    controller: _name,
                    maxLength: NewListScreen.maxName,
                    textInputAction: TextInputAction.done,
                    textCapitalization: TextCapitalization.sentences,
                    style: text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: InputDecoration(
                      labelText: 'List name',
                      errorText: _nameError,
                      counterText: '',
                    ),
                    onChanged: (_) {
                      if (_nameError != null) {
                        setState(() => _nameError = null);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),
                FadeSlideIn.staggered(
                  index: 1,
                  child: _FieldBox(
                    icon: Icons.notes,
                    label: 'Description',
                    value: _description.trim().isEmpty
                        ? null
                        : _description.trim(),
                    hint: 'Add a description',
                    onTap: _editDescription,
                  ),
                ),
                const SizedBox(height: 16),
                FadeSlideIn.staggered(
                  index: 2,
                  child: _FieldBox(
                    icon: Icons.add_circle_outline,
                    label: 'Add entries',
                    hint: 'Tap to search for movies and shows',
                    onTap: _addEntries,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  FadeSlideIn(child: FormMessage(text: _error!)),
                ],
                if (_entries.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    '${_entries.length} '
                    '${_entries.length == 1 ? 'entry' : 'entries'}',
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: posterGridDelegate,
                    itemCount: _entries.length,
                    itemBuilder: (context, i) => FadeSlideIn(
                      key: ValueKey(_entries[i].id),
                      distance: 16,
                      child: _EntryTile(
                        title: _entries[i],
                        position: i + 1,
                        onRemove: () => _remove(_entries[i]),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A tappable bordered box, like Letterboxd's list fields: a label, then
/// the value or a hint
class _FieldBox extends StatelessWidget {
  const _FieldBox({
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
    this.value,
  });

  final IconData icon;
  final String label;
  final String hint;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = Theme.of(context).colorScheme.onSurface;
    final radius = BorderRadius.circular(12);

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: color.withValues(alpha: 0.5), width: 1.5),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value ?? hint,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: value == null
                            ? text.bodyMedium?.copyWith(
                                color: color.withValues(alpha: 0.7),
                              )
                            : text.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// An entry in the list being made: its poster, its place in the list, and
/// a remove button
class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.title,
    required this.position,
    required this.onRemove,
  });

  final TitleCard title;
  final int position; // 1 = added first
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Semantics(
          label: '$position. ${title.name}',
          child: PosterImage(url: title.posterUrl, type: title.type),
        ),
        Positioned(
          left: 4,
          top: 4,
          child: _Badge(child: Text('$position')),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: IconButton(
            tooltip: 'Remove ${title.name}',
            onPressed: onRemove,
            icon: const _Badge(child: Icon(Icons.close, size: 16)),
          ),
        ),
      ],
    );
  }
}

/// A small dark circle that stays readable on any poster
class _Badge extends StatelessWidget {
  const _Badge({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(13),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
        child: IconTheme(
          data: const IconThemeData(color: Colors.white),
          child: child,
        ),
      ),
    );
  }
}

/// Full-screen description editor. Back and Done both keep what was
/// typed and return to New List
class _DescriptionScreen extends StatefulWidget {
  const _DescriptionScreen({required this.initial});

  final String initial;

  @override
  State<_DescriptionScreen> createState() => _DescriptionScreenState();
}

class _DescriptionScreenState extends State<_DescriptionScreen> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _finish() => Navigator.of(context).pop(_text.text);

  @override
  Widget build(BuildContext context) {
    final navText = Theme.of(context).colorScheme.onSecondary;
    return PopScope(
      canPop: false, // Back returns the text too, so nothing is lost
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        appBar: AppBar(
          leadingWidth: BackTextButton.width,
          leading: const BackTextButton(),
          title: const Text('Description'),
          actions: [
            TextButton(
              onPressed: _finish,
              style: TextButton.styleFrom(
                foregroundColor: navText,
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              child: const Text('Done'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _text,
            autofocus: true,
            maxLines: null,
            expands: true,
            maxLength: NewListScreen.maxDescription,
            textAlignVertical: TextAlignVertical.top,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Say something about this list...',
              alignLabelWithHint: true,
            ),
          ),
        ),
      ),
    );
  }
}
