import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../auth/auth_controller.dart';
import '../widgets/dialogs.dart';
import '../widgets/leave_guard.dart';

/// "Add Comment": one big text field. x closes (asking "Discard changes?"
/// if anything was typed, as do Android back and the nav bar) and the
/// check mark posts. Returns the new [ReviewComment], or null
class AddCommentScreen extends StatefulWidget {
  /// Creates the page for a comment on review [reviewId]
  const AddCommentScreen({
    super.key,
    required this.api,
    required this.auth,
    required this.reviewId,
  });

  final ApiClient api;
  final AuthController auth;
  final int reviewId;

  /// Longest comment (same as the server)
  static const maxLength = 2000;

  @override
  State<AddCommentScreen> createState() => _AddCommentScreenState();
}

class _AddCommentScreenState extends State<AddCommentScreen> {
  final _text = TextEditingController();
  bool _posting = false;
  bool _leaving = false;

  LeaveGuard? _guard;
  ModalRoute<Object?>? _route;

  bool get _dirty => _text.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {})); // updates _dirty
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
    _text.dispose();
    super.dispose();
  }

  /// Asked by the nav bar before switching tabs
  Future<bool> _confirmLeave() async {
    if (!_dirty || _leaving) return true;
    if (!await confirmDiscard(context) || !mounted) return false;
    _close();
    return true;
  }

  void _close([ReviewComment? posted]) {
    setState(() => _leaving = true);
    final navigator = Navigator.of(context);
    final route = _route;
    if (route != null && !route.isCurrent) {
      navigator.popUntil((r) => r == route);
    }
    navigator.pop(posted);
  }

  Future<void> _onBlockedPop() async {
    if (await confirmDiscard(context) && mounted) _close();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _post() async {
    final body = _text.text.trim();
    if (body.isEmpty) {
      _snack('Write a comment first.');
      return;
    }
    final token = widget.auth.value?.token;
    if (token == null) {
      _snack('Log in again to comment.');
      return;
    }
    setState(() => _posting = true);
    try {
      final comment = await widget.api.addComment(
        token,
        widget.reviewId,
        body,
      );
      if (mounted) _close(comment);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _posting = false);
      _snack(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final navText = theme.colorScheme.onSecondary;

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
          title: const Text('Add Comment'),
          actions: [
            if (_posting)
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
                tooltip: 'Post',
                icon: Icon(Icons.check, color: navText),
                onPressed: _post,
              ),
            const SizedBox(width: 4),
          ],
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: TextField(
                controller: _text,
                autofocus: true,
                enabled: !_posting,
                expands: true,
                minLines: null,
                maxLines: null,
                maxLength: AddCommentScreen.maxLength,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                textAlignVertical: TextAlignVertical.top,
                style: theme.textTheme.bodyLarge,
                decoration: const InputDecoration(
                  hintText: 'Add a comment...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  filled: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
