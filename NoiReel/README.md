# NoiReel

A mood-based movie and TV discovery app. Flutter frontend, Dart Frog + MySQL backend.

CMPE-137 SJSU, Fall 2026

## Members

- Thai Nguyen | thai.nguyen02@sjsu.edu
- Jan Michael Maturan | janmichael.maturan@sjsu.edu

## Project layout

```
NoiReel/
├── .env.example   ← Flutter app config template (commit this)
├── .env           ← your copy, never committed
├── lib/           ← Flutter app code
└── server/        ← Dart Frog backend (see server/README.md)
```

There are **two separate `.env` files**: one here for the Flutter app, one in `server/` for the backend. They hold different things.

## 1. Set up the server first

Follow [server/README.md](server/README.md). You're done when http://localhost:8080/health shows:

```json
{"status":"ok","db":"connected"}
```

Leave `dart_frog dev` running in its own terminal.

## 2. Set up the Flutter app

### Install dependencies

From the `NoiReel/` folder (the one with the Flutter `pubspec.yaml`):

```
flutter pub get
```

### Create `NoiReel/.env`

```
copy .env.example .env      # Windows cmd / PowerShell
cp .env.example .env        # Git Bash / macOS / Linux
```

Then fill it in:

```
API_URL=http://localhost:8080
TMDB_API_KEY=ask_thai
```

- `API_URL`: where the Flutter app finds the server. Use `http://localhost:8080` for Chrome/Windows. Use `http://10.0.2.2:8080` only if running on the Android emulator.
- `TMDB_API_KEY`: ask Thai on Discord.
- Format: one `KEY=value` per line, no spaces around `=`, no quotes.

> **This file gets bundled into the app and anyone can read it.** Never put database passwords or other secrets here. Those go in `server/.env` only.

> **Before typing any real values, make sure git ignores `.env`:**
>
> ```
> git check-ignore .env
> ```
>
> If it prints `.env`, you're safe. If it prints nothing, **stop** and tell Thai.

### Run the app

```
flutter run -d chrome
```

Use a full restart (stop and run again) after changing `.env`; hot reload won't pick it up.

### Troubleshooting

- **"Unable to load asset: .env"**: the file isn't next to `pubspec.yaml`, or you skipped `flutter pub get`.
- **A value comes back empty**: the key name in `.env` doesn't match the code exactly.
- **Requests to the server fail**: check the server is running (`dart_frog dev` in `server/`) and `API_URL` matches the port it prints.