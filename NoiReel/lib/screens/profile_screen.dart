import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../widgets/fade_slide_in.dart';
import 'login_screen.dart';
import 'register_screen.dart';

/// The Profile tab. A guest sees Log in and Create account; a logged-in
/// user sees their account and Log out
class ProfileScreen extends StatelessWidget {
  /// Creates the Profile tab
  const ProfileScreen({super.key, required this.auth});

  final AuthController auth; // Who is logged in

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NOIREEL')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            // Switches between the two views by itself when someone logs
            // in or out
            child: ValueListenableBuilder<Session?>(
              valueListenable: auth,
              builder: (context, session, _) => session == null
                  ? _GuestView(
                      key: const ValueKey('guest'),
                      auth: auth,
                    )
                  : _AccountView(
                      key: ValueKey(session.token),
                      session: session,
                      auth: auth,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GuestView extends StatelessWidget {
  const _GuestView({super.key, required this.auth});

  final AuthController auth;

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final bodyText = Theme.of(context).colorScheme.onSurface;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeSlideIn(
          child: Icon(Icons.person_outline, size: 72, color: bodyText),
        ),
        const SizedBox(height: 16),
        FadeSlideIn.staggered(
          index: 1,
          child: Text(
            'Join NoiReel',
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 8),
        FadeSlideIn.staggered(
          index: 2,
          child: const Text(
            'Log in or create an account to vote on moods, rate and '
            'review, and keep a watchlist.',
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 28),
        FadeSlideIn.staggered(
          index: 3,
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => _open(context, LoginScreen(auth: auth)),
              child: const Text('Log in'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FadeSlideIn.staggered(
          index: 4,
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () => _open(context, RegisterScreen(auth: auth)),
              style: OutlinedButton.styleFrom(
                foregroundColor: bodyText,
                side: BorderSide(color: bodyText, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              child: const Text('Create account'),
            ),
          ),
        ),
      ],
    );
  }
}

class _AccountView extends StatefulWidget {
  const _AccountView({super.key, required this.session, required this.auth});

  final Session session;
  final AuthController auth;

  @override
  State<_AccountView> createState() => _AccountViewState();
}

class _AccountViewState extends State<_AccountView> {
  bool _busy = false;

  Future<void> _logout() async {
    setState(() => _busy = true);
    await widget.auth.logout(); // the view switches to guest by itself
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final bodyText = Theme.of(context).colorScheme.onSurface;
    final session = widget.session;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeSlideIn(
          child: CircleAvatar(
            radius: 40,
            backgroundColor: Theme.of(context).colorScheme.secondary,
            foregroundColor: Theme.of(context).colorScheme.onSecondary,
            child: Text(
              session.username.substring(0, 1).toUpperCase(),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
            ),
          ),
        ),
        const SizedBox(height: 16),
        FadeSlideIn.staggered(
          index: 1,
          child: Text(
            '@${session.username}',
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        if (session.isAdmin) ...[
          const SizedBox(height: 6),
          FadeSlideIn.staggered(
            index: 1,
            child: Text(
              'Admin',
              style: text.labelLarge?.copyWith(color: bodyText),
            ),
          ),
        ],
        const SizedBox(height: 8),
        FadeSlideIn.staggered(
          index: 2,
          child: const Text(
            'Your ratings, reviews and lists will show up here.',
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 28),
        FadeSlideIn.staggered(
          index: 3,
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Log out'),
            ),
          ),
        ),
      ],
    );
  }
}
