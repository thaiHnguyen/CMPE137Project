import 'package:flutter/material.dart';

/// "Discard changes?" with Yes, and No. Returns true for Yes.
/// Tapping outside the box counts as No, so work is never lost by accident
Future<bool> confirmDiscard(BuildContext context) async {
  final discard = await showDialog<bool>(
    context: context,
    builder: (context) => _NoiReelDialog(
      title: 'Discard changes?',
      message: "Your changes haven't been saved.",
      actions: [
        _DialogButton(
          label: 'Yes',
          primary: true,
          onPressed: () => Navigator.pop(context, true),
        ),
        _DialogButton(
          label: 'No',
          onPressed: () => Navigator.pop(context, false),
        ),
      ],
    ),
  );
  return discard ?? false;
}

/// "Delete the list?" with Delete, and Cancel. Returns true for Delete.
/// Tapping outside the box counts as Cancel
Future<bool> confirmDeleteList(BuildContext context, String name) =>
    confirmDelete(
      context,
      title: 'Delete the list?',
      message: '"$name" and its entries will be gone for good.',
    );

/// A [title] and [message] with Delete, and Cancel. Returns true for
/// Delete. Tapping outside the box counts as Cancel
Future<bool> confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final delete = await showDialog<bool>(
    context: context,
    builder: (context) => _NoiReelDialog(
      title: title,
      message: message,
      actions: [
        _DialogButton(
          label: 'Delete',
          primary: true,
          onPressed: () => Navigator.pop(context, true),
        ),
        _DialogButton(
          label: 'Cancel',
          onPressed: () => Navigator.pop(context, false),
        ),
      ],
    ),
  );
  return delete ?? false;
}

/// What a guest chose in [askGuestToSignIn]
enum GuestChoice {
  /// Open the Log in page
  signIn,

  /// Open the Create account page
  register,
}

/// Tells a guest they need an account for [what], e.g. "to create a list".
/// Returns their choice, or null if they closed it
Future<GuestChoice?> askGuestToSignIn(BuildContext context, String what) {
  return showDialog<GuestChoice>(
    context: context,
    builder: (context) => _NoiReelDialog(
      title: 'Sign in needed',
      message: 'Register or Sign In to your NoiReel account $what.',
      actions: [
        _DialogButton(
          label: 'Sign In',
          primary: true,
          onPressed: () => Navigator.pop(context, GuestChoice.signIn),
        ),
        _DialogButton(
          label: 'Register',
          onPressed: () => Navigator.pop(context, GuestChoice.register),
        ),
        _DialogButton(
          label: 'Not now',
          onPressed: () => Navigator.pop(context),
          plain: true,
        ),
      ],
    ),
  );
}

/// A dialog in the current theme's background and text colors (Flutter's
/// default dialog color can make the theme's text hard to read), with its
/// buttons stacked full width
class _NoiReelDialog extends StatelessWidget {
  const _NoiReelDialog({
    required this.title,
    required this.message,
    required this.actions,
  });

  final String title;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      backgroundColor: theme.scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        title,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w900,
        ),
      ),
      content: Text(message),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, action) in actions.indexed) ...[
              if (i > 0) const SizedBox(height: 8),
              action,
            ],
          ],
        ),
      ],
    );
  }
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.plain = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool primary; // Filled button
  final bool plain;   // Text only

  @override
  Widget build(BuildContext context) {
    if (primary) {
      return SizedBox(
        height: 46,
        child: ElevatedButton(onPressed: onPressed, child: Text(label)),
      );
    }
    if (plain) return TextButton(onPressed: onPressed, child: Text(label));

    final color = Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      height: 46,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        child: Text(label),
      ),
    );
  }
}

/// "‹ Back" for the top left of an app bar. Uses maybePop, so a page with
/// unsaved work can ask first
class BackTextButton extends StatelessWidget {
  /// Creates the button
  const BackTextButton({super.key});

  /// Width to give the app bar's leading slot
  static const width = 104.0;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => Navigator.of(context).maybePop(),
      icon: const Icon(Icons.chevron_left, size: 28),
      label: const Text('Back'),
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.onSecondary,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// "Cancel" for the top left of an app bar, e.g. while editing a list.
/// Uses maybePop, so unsaved changes ask "Discard changes?" first
class CancelTextButton extends StatelessWidget {
  /// Creates the button
  const CancelTextButton({super.key});

  /// Width to give the app bar's leading slot
  static const width = 96.0;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => Navigator.of(context).maybePop(),
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.onSecondary,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      child: const Text('Cancel'),
    );
  }
}
