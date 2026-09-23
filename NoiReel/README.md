# flutter_application_1

A new Flutter project.

## Members
- Thai Nguyen | Email: thai.nguyen02@sjsu.edu

- Jan Michael Maturan | Email: janmichael.maturan@sjsu.edu

## Server setup (can also be found in server/README.md)

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

4. Run from inside `server/`:
```
   dart_frog dev
```
   Serves on http://localhost:8080

