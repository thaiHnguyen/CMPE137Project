import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../auth/auth_controller.dart';
import '../widgets/dialogs.dart';
import '../widgets/leave_guard.dart';
import '../widgets/profile_avatar.dart';

/// Profile Settings, opened from Settings on the Profile tab: photo, name,
/// email, bio and pronoun, plus Sign out.
///
/// ✕ closes (asking "Discard changes?" if anything changed, as do Android
/// back and the nav bar) and ✓ saves. Returns the saved [Profile], or null
class ProfileSettingsScreen extends StatefulWidget {
  /// Creates Profile Settings for [profile]
  const ProfileSettingsScreen({
    super.key,
    required this.api,
    required this.auth,
    required this.profile,
    this.pickPhoto,
  });

  final ApiClient api;        // Connection to the server
  final AuthController auth;  // The logged-in user
  final Profile profile;      // What the fields start with

  /// Picks a photo and returns its bytes, or null if cancelled. Defaults
  /// to the phone's photo library; tests pass their own
  final Future<Uint8List?> Function()? pickPhoto;

  /// Longest name and bio, matching the server
  static const maxName = 50;
  static const maxBio = 160;

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  late final _name = TextEditingController(
    text: widget.profile.displayName ?? '',
  );
  late final _email = TextEditingController(text: widget.profile.email);
  late final _bio = TextEditingController(text: widget.profile.bio ?? '');
  late String? _pronoun = widget.profile.pronoun;

  Uint8List? _newPhoto;      // Picked but not uploaded yet
  bool _removePhoto = false; // "Remove photo" tapped, not saved yet

  // The photo on the server. Changes if the photo saved but the rest of
  // the save failed (e.g. the email was taken)
  late String? _avatarUrl = widget.profile.avatarUrl;

  final _errors = <String, String>{}; // Field name -> message from server
  bool _saving = false;
  bool _leaving = false;

  LeaveGuard? _guard;
  ModalRoute<Object?>? _route;

  /// True when anything differs from the saved profile
  bool get _dirty {
    final p = widget.profile;
    return _name.text.trim() != (p.displayName ?? '') ||
        _email.text.trim().toLowerCase() != p.email ||
        _bio.text.trim() != (p.bio ?? '') ||
        _pronoun != p.pronoun ||
        _newPhoto != null ||
        _removePhoto;
  }

  @override
  void initState() {
    super.initState();
    // Rebuild on typing, so PopScope knows about unsaved changes
    for (final c in [_name, _email, _bio]) {
      c.addListener(() => setState(() {}));
    }
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
    _email.dispose();
    _bio.dispose();
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
  void _close([Profile? saved]) {
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

  static Future<Uint8List?> _pickFromLibrary() async {
    // Shrunk on the phone, so uploads stay small and quick
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    return file?.readAsBytes();
  }

  Future<void> _changePhoto() async {
    final Uint8List? bytes;
    try {
      bytes = await (widget.pickPhoto ?? _pickFromLibrary)();
    } on Exception {
      _snack("Couldn't open your photos.");
      return;
    }
    if (bytes == null || !mounted) return;
    setState(() {
      _newPhoto = bytes;
      _removePhoto = false;
      _errors.remove('avatar');
    });
  }

  void _removeCurrentPhoto() => setState(() {
    _newPhoto = null;
    _removePhoto = true;
    _errors.remove('avatar');
  });

  Future<void> _signOut() async {
    if (_dirty && !await confirmDiscard(context)) return;
    if (!mounted) return;
    setState(() => _leaving = true);
    await widget.auth.logout();
    if (mounted) _close();
  }

  Future<void> _save() async {
    final token = widget.auth.value?.token;
    if (token == null) {
      _snack('Log in again to save your profile.');
      return;
    }
    if (!_dirty) {
      _close(widget.profile);
      return;
    }

    setState(() {
      _saving = true;
      _errors.clear();
    });
    try {
      // The photo first: if it's refused, nothing else has changed yet
      final photo = _newPhoto;
      if (photo != null) {
        _avatarUrl = (await widget.api.uploadAvatar(token, photo)).avatarUrl;
        _newPhoto = null;
      } else if (_removePhoto) {
        _avatarUrl = (await widget.api.removeAvatar(token)).avatarUrl;
      }
      _removePhoto = false;

      final saved = await widget.api.updateProfile(
        token,
        displayName: _name.text.trim(),
        bio: _bio.text.trim(),
        pronoun: _pronoun,
        email: _email.text.trim(),
      );
      if (mounted) _close(saved);
    } on ApiException catch (e) {
      if (!mounted) return;
      final field = e.field;
      setState(() {
        _saving = false;
        if (field != null) _errors[field] = e.message;
      });
      if (field == null || field == 'avatar') _snack(e.message);
    }
  }

  ImageProvider? get _photo {
    final picked = _newPhoto;
    if (picked != null) return MemoryImage(picked);
    final saved = _avatarUrl;
    if (_removePhoto || saved == null) return null;
    return NetworkImage(widget.api.mediaUrl(saved));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final colors = theme.colorScheme;
    final navText = colors.onSecondary;
    final hasPhoto = _photo != null;

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
          title: const Text('Profile Settings'),
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
              padding: const EdgeInsets.only(bottom: 40),
              children: [
                // Who's signed in, and Sign out
                Container(
                  color: colors.secondary,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Text.rich(
                    TextSpan(
                      text: 'Signed in as ',
                      children: [
                        TextSpan(
                          text: widget.profile.username,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    style: text.titleMedium?.copyWith(color: navText),
                  ),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  leading: const Icon(Icons.logout),
                  title: const Text(
                    'Sign out',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  onTap: _saving ? null : _signOut,
                ),
                Divider(color: colors.onSurface.withValues(alpha: 0.25)),
                const SizedBox(height: 16),

                // Photo
                Center(child: ProfileAvatar(radius: 52, image: _photo)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: _saving ? null : _changePhoto,
                      style: TextButton.styleFrom(
                        foregroundColor: colors.onSurface,
                      ),
                      child: Text(hasPhoto ? 'Change photo' : 'Add photo'),
                    ),
                    if (hasPhoto)
                      TextButton(
                        onPressed: _saving ? null : _removeCurrentPhoto,
                        style: TextButton.styleFrom(
                          foregroundColor: colors.onSurface,
                        ),
                        child: const Text('Remove photo'),
                      ),
                  ],
                ),
                if (_errors['avatar'] != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      _errors['avatar']!,
                      textAlign: TextAlign.center,
                      style: text.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                // Details
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      TextField(
                        controller: _name,
                        maxLength: ProfileSettingsScreen.maxName,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Name',
                          hintText: widget.profile.username,
                          helperText: 'Leave blank to show your username.',
                          errorText: _errors['displayName'],
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          errorText: _errors['email'],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _bio,
                        maxLength: ProfileSettingsScreen.maxBio,
                        minLines: 3,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: 'Bio',
                          alignLabelWithHint: true,
                          errorText: _errors['bio'],
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String?>(
                        initialValue: _pronoun,
                        decoration: InputDecoration(
                          labelText: 'Pronoun',
                          errorText: _errors['pronoun'],
                        ),
                        dropdownColor: theme.scaffoldBackgroundColor,
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Not shown'),
                          ),
                          for (final MapEntry(:key, :value)
                              in Profile.pronouns.entries)
                            DropdownMenuItem(value: key, child: Text(value)),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) => setState(() => _pronoun = value),
                      ),
                    ],
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
