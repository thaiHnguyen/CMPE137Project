## Server setup

# server

[![style: dart frog lint][dart_frog_lint_badge]][dart_frog_lint_link]
[![License: MIT][license_badge]][license_link]
[![Powered by Dart Frog](https://img.shields.io/endpoint?url=https://tinyurl.com/dartfrog-badge)](https://dart-frog.dev)

Backend for NoiReel, built with Dart Frog and MySQL.

[dart_frog_lint_badge]: https://img.shields.io/badge/style-dart_frog_lint-1DF9D2.svg
[dart_frog_lint_link]: https://pub.dev/packages/dart_frog_lint
[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT

## Server setup

### 1. Install the Dart Frog CLI

```
dart pub global activate dart_frog_cli
```

If `dart_frog` isn't recognized afterward, add `%LOCALAPPDATA%\Pub\Cache\bin` to your User PATH (Environment Variables → User variables → Path), then open a new terminal.

### 2. Install dependencies

```
cd server
dart pub get
```

### 3. Create the database

In MySQL Workbench, open your local connection and run:

```sql
CREATE DATABASE noireel;
```

Click refresh in the Schemas panel. `noireel` should appear.

### 4. Create `server/.env`

Copy the example file (from inside `server/`):

```
copy .env.example .env      # Windows cmd / PowerShell
cp .env.example .env        # Git Bash / macOS / Linux
```

Then fill in the blanks:

```
DB_HOST=localhost
DB_PORT=3306
DB_NAME=noireel
DB_USER=your_root_user_name_MySQL
DB_PASSWORD=your_mysql_root_password
TMDB_API_KEY=
```

- `DB_PASSWORD` is **your own** MySQL root password (the one you use to log into Workbench).
- `TMDB_API_KEY`: ask me on Discord. It is not in the repo for security reasons.
- Format: one `KEY=value` per line, no spaces around `=`, no quotes.

> **Before typing any real values, make sure git ignores `.env`:**
>
> ```
> git check-ignore .env
> ```
>
> If it prints `.env`, you're safe. If it prints nothing, **stop** and tell Thai. Never commit `.env`; only `.env.example` goes in the repo.

### 5. Run the server

From inside `server/`:

```
dart_frog dev
```

Serves on http://localhost:8080. You should see "Welcome to Dart Frog!".

### 6. Check the database connection

Open http://localhost:8080/health. You should see:

```json
{"status":"ok","db":"connected"}
```

If you get an error, the most common causes are:

- MySQL isn't running (start it from Workbench or Windows Services).
- Wrong `DB_PASSWORD` in `.env`.
- The `noireel` database wasn't created (step 3).
- `dart_frog dev` was run from outside `server/`, so `.env` wasn't found.