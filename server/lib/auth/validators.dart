import 'dart:convert';

/// A field that failed validation, and a message the app can show.
typedef FieldError = ({String field, String message});

final _username = RegExp(r'^[A-Za-z0-9_]{3,20}$');
final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final _letter = RegExp('[A-Za-z]');
final _digit = RegExp(r'\d');

/// GU-07.02: checks sign-up fields. Returns the first invalid field,
/// or null if everything is valid.
FieldError? validateRegistration({
  required String email,
  required String username,
  required String password,
}) {
  if (email.length > 254 || !_email.hasMatch(email)) {
    return (field: 'email', message: 'Enter a valid email address.');
  }
  if (!_username.hasMatch(username)) {
    return (
      field: 'username',
      message: 'Username must be 3-20 letters, digits or underscores.',
    );
  }
  return validatePassword(password);
}

/// Password rule: 8+ characters with at least one letter and one digit.
/// Also capped at 72 bytes, the most bcrypt can use.
FieldError? validatePassword(String password) {
  if (password.length < 8 ||
      !_letter.hasMatch(password) ||
      !_digit.hasMatch(password)) {
    return (
      field: 'password',
      message: 'Password must be at least 8 characters with a letter '
          'and a digit.',
    );
  }
  if (utf8.encode(password).length > 72) {
    return (field: 'password', message: 'Password is too long.');
  }
  return null;
}
