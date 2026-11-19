import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';

/// The logged-in user, as kept on this device
@immutable
class Session {
  /// Creates a [Session]
  const Session({
    required this.token,
    required this.userId,
    required this.username,
    required this.role,
  });

  /// Reads a session saved by [toJson]
  factory Session.fromJson(Map<String, dynamic> json) => Session(
    token: json['token'] as String,
    userId: json['userId'] as int,
    username: json['username'] as String,
    role: json['role'] as String,
  );

  final String token;    // Sent as `Authorization: Bearer <token>`
  final int userId;
  final String username;
  final String role;     // `user` or `admin`

  /// True for admin accounts, which can't vote on moods
  bool get isAdmin => role == 'admin';

  /// What's saved on the device
  Map<String, dynamic> toJson() => {
    'token': token,
    'userId': userId,
    'username': username,
    'role': role,
  };
}

/// Who is logged in: `value` is the [Session], or null for a guest.
///
/// The session is saved on the device, so the user stays logged in after
/// a restart. On start the app shows the saved session right away, then
/// asks the server whether it's still valid (RU-01.02)
class AuthController extends ValueNotifier<Session?> {
  /// Creates a controller starting on [initial] (null = guest)
  AuthController(this._api, [super.initial]);

  final ApiClient _api;

  static const _key = 'session';

  /// Loads the session saved on this device, then checks it with the
  /// server in the background
  static Future<AuthController> load(ApiClient api) async {
    final controller = AuthController(api, await _readSaved());
    controller._checkSaved(); // no await: the app doesn't wait for it
    return controller;
  }

  /// True when someone is logged in
  bool get isLoggedIn => value != null;

  /// GU-08: logs in with a username or email. Throws an [ApiException]
  /// with the server's message if it fails (wrong password, locked,
  /// suspended or banned)
  Future<void> login(String login, String password) async {
    final result = await _api.login(login: login.trim(), password: password);
    // The login reply has no username (the user may have typed an email)
    final info = await _api.checkSession(result.token);
    await _set(
      Session(
        token: result.token,
        userId: result.userId,
        username: info?.username ?? login.trim(),
        role: result.role,
      ),
    );
  }

  /// GU-07: creates an account and logs it in. Throws an [ApiException];
  /// if a field was rejected, [ApiException.field] says which
  Future<void> register({
    required String email,
    required String username,
    required String password,
  }) async {
    final result = await _api.register(
      email: email.trim().toLowerCase(),
      username: username.trim(),
      password: password,
    );
    await _set(
      Session(
        token: result.token,
        userId: result.userId,
        username: username.trim(),
        role: result.role,
      ),
    );
  }

  /// RU-01.03: logs out. The device forgets the session even if the
  /// server can't be reached
  Future<void> logout() async {
    final token = value?.token;
    await _set(null);
    if (token == null) return;
    try {
      await _api.logout(token);
    } on ApiException catch (e) {
      debugPrint('Logout request failed: $e');
    }
  }

  Future<void> _checkSaved() async {
    final saved = value;
    if (saved == null) return;
    try {
      final info = await _api.checkSession(saved.token);
      if (value?.token != saved.token) return; // changed meanwhile
      if (info == null) {
        await _set(null); // expired: back to guest
      } else if (info.username != saved.username || info.role != saved.role) {
        await _set(
          Session(
            token: saved.token,
            userId: info.userId,
            username: info.username,
            role: info.role,
          ),
        );
      }
    } on ApiException catch (e) {
      // Server unreachable: keep the saved session and try again next time
      debugPrint('Could not check the saved session: $e');
    }
  }

  Future<void> _set(Session? session) async {
    value = session;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (session == null) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(_key, jsonEncode(session.toJson()));
      }
    } on Exception catch (e) {
      debugPrint('Could not save the session: $e');
    }
  }

  static Future<Session?> _readSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      if (saved == null) return null;
      return Session.fromJson(jsonDecode(saved) as Map<String, dynamic>);
    } on Exception catch (e) {
      debugPrint('Could not read the saved session: $e');
      return null;
    }
  }
}
