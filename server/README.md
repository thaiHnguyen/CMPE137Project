# server

[![style: dart frog lint][dart_frog_lint_badge]][dart_frog_lint_link]
[![License: MIT][license_badge]][license_link]
[![Powered by Dart Frog](https://img.shields.io/endpoint?url=https://tinyurl.com/dartfrog-badge)](https://dart-frog.dev)

An example application built with dart_frog

[dart_frog_lint_badge]: https://img.shields.io/badge/style-dart_frog_lint-1DF9D2.svg
[dart_frog_lint_link]: https://pub.dev/packages/dart_frog_lint
[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT


## Server setup

1. Install the CLI:
```
   dart pub global activate dart_frog_cli
```
   If `dart_frog` isn't recognized afterward, add
   `%LOCALAPPDATA%\Pub\Cache\bin` to your User PATH (Environment Variables -> User Variable -> Path) and open a new terminal.

2. Install dependencies:
```
   cd server
   dart pub get
```

3. Create `server/.env` by copying `.env.example`, then fill in:
```
   TMDB_API_KEY=
   DB_PASSWORD=
```
   Ask Thai via discord for the TMDB key, it is not in the repo (for security purpose)
   DB password is your MySQL root password.

   (BEFORE TYPE IT IN, MAKE SURE .ENV IS IGNORE BY GIT)

4. Run from inside `server/`:
```
   dart_frog dev
```
   Serves on http://localhost:8080