import 'package:flutter/widgets.dart';

import 'auth_controller.dart';

/// Makes the [AuthController] reachable from any page, so pages opened
/// from many places (like a title's details) don't need it passed in
/// Pages that read it rebuild when someone logs in or out
class AuthScope extends InheritedNotifier<AuthController> {
  /// Provides [auth] to everything under [child]
  const AuthScope({
    super.key,
    required AuthController auth,
    required super.child,
  }) : super(notifier: auth);

  /// The nearest [AuthController], or null if there isn't one (e.g. in a
  /// test that shows a page on its own)
  static AuthController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AuthScope>()?.notifier;
}
