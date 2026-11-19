// Form checks for Create account and Log in. Same rules as the server
// (server/lib/auth/validators.dart), so most mistakes are caught before
// anything is sent. 
//
//The server still checks everything.
//
// Each returns an error message, or null if the value is fine, so they
// plug straight into TextFormField's `validator`

import 'dart:convert';

final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final _username = RegExp(r'^[A-Za-z0-9_]{3,20}$');
final _letter = RegExp('[A-Za-z]');
final _digit = RegExp(r'\d');

/// Email: something@something.something, at most 254 characters
String? checkEmail(String? value) {
  final email = (value ?? '').trim();
  if (email.isEmpty) return 'Enter your email.';
  if (email.length > 254 || !_email.hasMatch(email)) {
    return 'Enter a valid email address.';
  }
  return null;
}

/// Username: 3-20 letters, digits or underscores
String? checkUsername(String? value) {
  final username = (value ?? '').trim();
  if (username.isEmpty) return 'Choose a username.';
  if (!_username.hasMatch(username)) {
    return 'Use 3-20 letters, digits or underscores.';
  }
  return null;
}

/// New password: 8+ characters with at least one letter and one digit
String? checkNewPassword(String? value) {
  final password = value ?? '';
  if (password.isEmpty) return 'Choose a password.';
  if (password.length < 8 ||
      !_letter.hasMatch(password) ||
      !_digit.hasMatch(password)) {
    return 'Use at least 8 characters with a letter and a digit.';
  }
  // bcrypt only uses the first 72 bytes, so the server refuses longer ones
  if (utf8.encode(password).length > 72) return 'That password is too long.';
  return null;
}

/// Log in: anything that isn't blank (the server decides if it's right)
String? checkFilled(String? value, String what) =>
    (value ?? '').trim().isEmpty ? 'Enter your $what.' : null;
