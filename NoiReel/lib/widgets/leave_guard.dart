import 'package:flutter/material.dart';

/// Lets a page with unsaved work (e.g. New List) stop the nav bar from
/// switching tabs until the user decides what to do with it
///
/// The page registers a check while it's open; the shell asks
/// [canLeave] before switching tabs
class LeaveGuard {
  Future<bool> Function()? _check;

  /// Starts asking [check] before tab switches. Returns true to go ahead
  void register(Future<bool> Function() check) => _check = check;

  /// Stops asking [check], if it's still the one registered
  void unregister(Future<bool> Function() check) {
    if (identical(_check, check)) _check = null;
  }

  /// True if nothing is open, or the open page says it's fine to leave
  Future<bool> canLeave() async => await _check?.call() ?? true;
}

/// Makes the shell's [LeaveGuard] available to the pages under it
class LeaveGuardScope extends InheritedWidget {
  /// Creates the scope
  const LeaveGuardScope({super.key, required this.guard, required super.child});

  final LeaveGuard guard;

  /// The nearest guard, or null outside the shell
  static LeaveGuard? maybeOf(BuildContext context) => context
      .getInheritedWidgetOfExactType<LeaveGuardScope>()
      ?.guard;

  @override
  bool updateShouldNotify(LeaveGuardScope oldWidget) =>
      guard != oldWidget.guard;
}
