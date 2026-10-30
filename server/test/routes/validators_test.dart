import 'package:server/auth/validators.dart';
import 'package:test/test.dart';

FieldError? _check({
  String email = 'thai@example.com',
  String username = 'thai_n',
  String password = 'movies2026',
}) =>
    validateRegistration(email: email, username: username, password: password);

void main() {
  group('validateRegistration (GU-07.02)', () {
    test('accepts valid input', () => expect(_check(), isNull));

    test('rejects a bad email', () {
      expect(_check(email: 'not-an-email')?.field, 'email');
    });

    test('rejects usernames outside 3-20 letters/digits/underscores', () {
      expect(_check(username: 'ab')?.field, 'username');
      expect(_check(username: 'a' * 21)?.field, 'username');
      expect(_check(username: 'thai n')?.field, 'username');
      expect(_check(username: 'abc'), isNull);
    });

    test('password needs 8+ chars, a letter and a digit', () {
      expect(_check(password: 'short1')?.field, 'password');
      expect(_check(password: 'noDigitsHere')?.field, 'password');
      expect(_check(password: '12345678')?.field, 'password');
      expect(_check(password: 'abcd1234'), isNull);
    });

    test('password over 72 bytes is rejected', () {
      expect(_check(password: 'a1' * 37)?.field, 'password');
    });
  });
}
