import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../auth/auth_controller.dart';
import '../widgets/dialogs.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/poster_card.dart';
import '../widgets/profile_avatar.dart';
import 'lists_screen.dart';
import 'login_screen.dart';
import 'profile_settings_screen.dart';
import 'register_screen.dart';
import 'search_screen.dart';
import 'title_details_screen.dart';

/// The Profile tab, like Letterboxd's: the user's name on top with
/// Settings beside it, and Profile, Favorite, List and Watchlist tabs.
///
/// Profile shows the photo, name, pronoun, bio and Greatest Of All Time.
/// List shows the user's lists, with the + button to make one. A guest
/// sees Log in and Create account on Profile
class ProfileScreen extends StatefulWidget {
  /// Creates the Profile tab
  const ProfileScreen({
    super.key,
    required this.api,
    required this.auth,
    this.pickPhoto,
  });

  final ApiClient api;        // Connection to the server
  final AuthController auth;  // Who is logged in

  /// Passed on to Profile Settings (tests use it to skip the photo picker)
  final Future<Uint8List?> Function()? pickPhoto;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  /// Tab order along the top
  static const _tabs = ['Profile', 'Favorite', 'List', 'Watchlist'];
  static const _listTab = 2;

  late final _tabController = TabController(
    length: _tabs.length,
    vsync: this,
  )..addListener(() => setState(() {})); // shows or hides the + button

  // Bumped to reload the user's lists, e.g. after making one
  final _reload = ValueNotifier<int>(0);

  Future<Profile>? _loading; // The first load, for the spinner and errors
  Profile? _profile;         // The profile as last loaded or saved
  String? _token;            // Whose profile is loaded

  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_onAuthChanged);
    _load();
  }

  @override
  void dispose() {
    widget.auth.removeListener(_onAuthChanged);
    _tabController.dispose();
    _reload.dispose();
    super.dispose();
  }

  // Logging in or out shows that person's profile, or the guest view
  void _onAuthChanged() {
    if (widget.auth.value?.token != _token) _load();
  }

  void _load() {
    final token = widget.auth.value?.token;
    setState(() {
      _token = token;
      _profile = null;
      _loading = token == null ? null : _fetch(token);
    });
  }

  Future<Profile> _fetch(String token) async {
    final profile = await widget.api.getProfile(token);
    if (mounted && token == _token) setState(() => _profile = profile);
    return profile;
  }

  Future<void> _refresh() async {
    final token = _token;
    if (token == null) return;
    try {
      await _fetch(token);
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openSettings() async {
    final profile = _profile;
    if (profile == null) return;
    final saved = await Navigator.of(context).push<Profile>(
      MaterialPageRoute(
        builder: (_) => ProfileSettingsScreen(
          api: widget.api,
          auth: widget.auth,
          profile: profile,
          pickPhoto: widget.pickPhoto,
        ),
      ),
    );
    if (!mounted) return;
    if (saved == null) {
      // Cancelled (a photo may still have saved before something else
      // failed), or signed out, which _onAuthChanged handles
      if (widget.auth.isLoggedIn) _refresh();
      return;
    }
    setState(() => _profile = saved);
    _snack('Profile saved.');
  }

  /// Puts [title] in Greatest Of All Time [slot] (0-4), or empties it with
  /// null. Shows the change right away and undoes it if saving fails
  Future<void> _setGoat(int slot, TitleCard? title) async {
    final before = _profile;
    final token = _token;
    if (before == null || token == null) return;

    final goat = [...before.goat]..[slot] = title;
    setState(() => _profile = before.withGoat(goat));
    try {
      final saved = await widget.api.setGoat(token, [
        for (final t in goat) t?.id,
      ]);
      if (mounted && token == _token) setState(() => _profile = saved);
    } on ApiException catch (e) {
      if (!mounted || token != _token) return;
      setState(() => _profile = before);
      _snack(e.message);
    }
  }

  /// Opens search to pick a title for Greatest Of All Time [slot]
  Future<void> _pickGoat(int slot) async {
    final goat = _profile?.goat ?? const [];
    final picked = await Navigator.of(context).push<TitleCard>(
      MaterialPageRoute(
        builder: (searchContext) => SearchScreen(
          api: widget.api,
          appBar: AppBar(
            leadingWidth: BackTextButton.width,
            leading: const BackTextButton(),
            title: const Text('Pick a title'),
          ),
          pickedIds: {for (final t in goat) ?t?.id},
          onPick: (title) {
            final at = goat.indexWhere((t) => t?.id == title.id);
            if (at >= 0 && at != slot) {
              ScaffoldMessenger.of(searchContext)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(
                      '${title.name} is already in your Greatest Of All '
                      'Time.',
                    ),
                  ),
                );
              return;
            }
            Navigator.of(searchContext).pop(title);
          },
        ),
      ),
    );
    if (picked != null && mounted) _setGoat(slot, picked);
  }

  /// A filled slot: view the title, replace it or remove it
  Future<void> _goatOptions(int slot, TitleCard title) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                title.name,
                textAlign: TextAlign.center,
                style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            for (final (value, icon, label) in const [
              ('view', Icons.info_outline, 'View details'),
              ('replace', Icons.swap_horiz, 'Replace'),
              ('remove', Icons.remove_circle_outline, 'Remove'),
            ])
              ListTile(
                leading: Icon(icon),
                title: Text(label),
                onTap: () => Navigator.pop(sheetContext, value),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'view':
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TitleDetailsScreen(api: widget.api, title: title),
          ),
        );
      case 'replace':
        _pickGoat(slot);
      case 'remove':
        _setGoat(slot, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final session = widget.auth.value;
    final navText = colors.onSecondary;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: session == null ? null : 104,
        // Settings sits where Letterboxd has its gear
        leading: session == null
            ? null
            : TextButton(
                onPressed: _profile == null ? null : _openSettings,
                style: TextButton.styleFrom(
                  foregroundColor: navText,
                  disabledForegroundColor: navText.withValues(alpha: 0.4),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: const Text('Settings'),
              ),
        title: Text(
          session == null
              ? 'NOIREEL'
              : _profile?.shownName ?? session.username,
          overflow: TextOverflow.ellipsis,
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: navText,
          unselectedLabelColor: navText.withValues(alpha: 0.6),
          indicatorColor: navText,
          indicatorWeight: 3,
          labelPadding: EdgeInsets.zero,
          labelStyle: const TextStyle(fontWeight: FontWeight.w900),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          dividerColor: Colors.transparent,
          tabs: [for (final t in _tabs) Tab(text: t)],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          if (session == null)
            _GuestView(auth: widget.auth)
          else
            _ProfileView(
              api: widget.api,
              loading: _loading,
              profile: _profile,
              onRetry: _load,
              onRefresh: _refresh,
              onPickGoat: _pickGoat,
              onGoatOptions: _goatOptions,
            ),
          const ListsComingSoon(
            icon: Icons.favorite_outline,
            text: 'Titles you add to your favorites will show up here.',
          ),
          MyListsView(api: widget.api, auth: widget.auth, reload: _reload),
          const ListsComingSoon(
            icon: Icons.bookmark_outline,
            text: 'Titles you add to your watchlist will show up here.',
          ),
        ],
      ),
      // The + sits in the middle, just above the nav bar
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _tabController.index == _listTab
          ? FloatingActionButton.small(
              tooltip: 'New list',
              onPressed: () => startNewList(
                context,
                api: widget.api,
                auth: widget.auth,
                reload: _reload,
              ),
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              shape: const CircleBorder(),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

/// The Profile tab for a logged-in user: photo, name, pronoun, bio, and
/// Greatest Of All Time
class _ProfileView extends StatelessWidget {
  const _ProfileView({
    required this.api,
    required this.loading,
    required this.profile,
    required this.onRetry,
    required this.onRefresh,
    required this.onPickGoat,
    required this.onGoatOptions,
  });

  final ApiClient api;
  final Future<Profile>? loading;
  final Profile? profile;
  final VoidCallback onRetry;
  final Future<void> Function() onRefresh;
  final ValueChanged<int> onPickGoat;                // Empty slot tapped
  final void Function(int, TitleCard) onGoatOptions; // Filled slot tapped

  @override
  Widget build(BuildContext context) {
    final profile = this.profile;
    if (profile == null) {
      // Still loading, or the first load failed
      return FutureBuilder<Profile>(
        future: loading,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${snapshot.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: onRetry,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      );
    }

    final text = Theme.of(context).textTheme;
    final bodyText = Theme.of(context).colorScheme.onSurface;
    final avatar = profile.avatarUrl;
    final facts = [
      '@${profile.username}',
      ?profile.pronounLabel,
      if (profile.role == 'admin') 'Admin',
    ];
    final hasEmpty = profile.goat.any((t) => t == null);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
        children: [
          FadeSlideIn(
            child: Center(
              child: ProfileAvatar(
                radius: 52,
                image: avatar == null
                    ? null
                    : NetworkImage(api.mediaUrl(avatar)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          FadeSlideIn.staggered(
            index: 1,
            child: Text(
              profile.shownName,
              textAlign: TextAlign.center,
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 4),
          FadeSlideIn.staggered(
            index: 1,
            child: Text(
              facts.join('  ·  '),
              textAlign: TextAlign.center,
              style: text.bodyMedium,
            ),
          ),
          if (profile.bio != null) ...[
            const SizedBox(height: 14),
            FadeSlideIn.staggered(
              index: 2,
              child: Text(profile.bio!, textAlign: TextAlign.center),
            ),
          ],
          const SizedBox(height: 24),
          Divider(color: bodyText.withValues(alpha: 0.25), height: 1),
          const SizedBox(height: 20),
          FadeSlideIn.staggered(
            index: 3,
            child: Text(
              'GREATEST OF ALL TIME',
              style: text.labelLarge?.copyWith(
                letterSpacing: 1.4,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FadeSlideIn.staggered(
            index: 4,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < Profile.goatSlots; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _GoatSlot(
                      number: i + 1,
                      title: profile.goat[i],
                      onTap: () {
                        final title = profile.goat[i];
                        title == null
                            ? onPickGoat(i)
                            : onGoatOptions(i, title);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (hasEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Tap an empty spot to add one of your all-time favorites.',
              style: text.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// One Greatest Of All Time spot: a poster, or an empty outlined spot
/// with a +
class _GoatSlot extends StatelessWidget {
  const _GoatSlot({
    required this.number,
    required this.title,
    required this.onTap,
  });

  final int number;         // 1-5
  final TitleCard? title;   // Null for an empty spot
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    final color = Theme.of(context).colorScheme.onSurface;
    final radius = BorderRadius.circular(8);

    return Semantics(
      button: true,
      label: title == null
          ? 'Greatest of all time, spot $number, empty'
          : 'Greatest of all time, spot $number: ${title.name}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: title == null
            ? AspectRatio(
                aspectRatio: 2 / 3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(
                      color: color.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(Icons.add, color: color.withValues(alpha: 0.7)),
                ),
              )
            : PosterImage(url: title.posterUrl, type: title.type),
      ),
    );
  }
}

/// The Profile tab for a guest: Log in and Create account
class _GuestView extends StatelessWidget {
  const _GuestView({required this.auth});

  final AuthController auth;

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final bodyText = Theme.of(context).colorScheme.onSurface;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FadeSlideIn(child: ProfileAvatar(radius: 44)),
              const SizedBox(height: 16),
              FadeSlideIn.staggered(
                index: 1,
                child: Text(
                  'Join NoiReel',
                  style: text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FadeSlideIn.staggered(
                index: 2,
                child: const Text(
                  'Log in or create an account to vote on moods, make '
                  'lists, and show off your Greatest Of All Time.',
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
                    onPressed: () =>
                        _open(context, RegisterScreen(auth: auth)),
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
          ),
        ),
      ),
    );
  }
}
