# NoiReel

A mood-based movie and TV discovery app. Flutter frontend, Dart Frog + MySQL backend.

CMPE-137 SJSU, Fall 2026

## Members

- Thai Nguyen | thai.nguyen02@sjsu.edu
- Jan Michael Maturan | janmichael.maturan@sjsu.edu

## What works so far

### App

- **Navigation bar:** Letterboxd-style, full width, icons only: Home, Search, Mood, Pick for me (compass) and Profile. The selected tab shows a filled icon in the theme's colors. Each tab keeps its own history, so a details page opens above the bar.
- **Home:** "Discovery", a grid of random posters. It reshuffles every time you tap Home, and when you pull down.
- **Mood tab:** one row of posters per mood (Hopeful, Gloomy, Happy, Melancholy, Calm, Excited), ranked by how well each title fits the mood, not by popularity. Tap a mood's name to open its own page: every title for that mood in a shuffled grid that loads more as you scroll.
- **Mood themes:** the **Theme** button opens "How are you feeling today?" and recolors the whole app to the chosen mood. The choice is saved on the device.
- **Title details page:** tap a poster to see its facts, genres, mood tags, community vote results, overview, director or creator, and top cast. Empty fields are hidden.
- **Search:**
  - Find movies and shows by title, director, creator or cast. Results appear as you type, and more load as you scroll.
  - Each result shows its poster, year and Movie/TV.
  - When nothing matches, it suggests trying fewer words.
- **Accounts:**
  - Log in with a username or email, or create an account, from the Profile tab.
  - You stay logged in after a restart. Sign out is in Profile Settings.
  - Errors show clearly: wrong password, the 15-minute lockout, suspended or banned accounts, and taken usernames.
- **Profile tab:** "Settings" at the top left, your name as the title, and four tabs: **Profile, Favorite, List, Watchlist**. A guest sees Log in and Create account.
  - **Profile:** photo, name, @username · pronoun, bio, and **Greatest Of All Time**: 5 spots. Tap an empty spot to pick a title through search. Tap a filled one to view, replace or remove it.
  - **Profile Settings:** Sign out, photo (add, change or remove), name, email, bio and pronoun. ✕ cancels and ✓ saves; nothing is saved until ✓.
- **Lists** (the List tab on Profile):
  - The **+** button above the nav bar makes a new list: name, description, and entries added through search, kept in the order added. A guest is asked to register or sign in first.
  - Lists show as cards with their first posters. Tap one to see its entries in a poster grid.
  - The **…** menu on a list edits it (rename, change the description, add or remove entries, or **hold a poster to drag it** to a new spot) or deletes it ("Delete the list?").
  - Leaving the editor or Profile Settings with unsaved changes, through Back, Cancel, ✕ or the nav bar, asks "Discard changes?" first.
- **Animations:** pages, tabs, rows and sections fade in while sliding up. They're skipped if the device has reduced motion turned on.

### Server

All routes are in [server/API.md](server/API.md).

- **Accounts:** register, log in, log out and session checks (`/auth`).
- **Browsing:** moods, mood rows, random Discovery titles, title details and search (`/moods`, `/discover`, `/titles/:id`, `/search`).
- **Mood voting:** logged-in users vote up to 3 moods per title (`/titles/:id/votes`). The mood with the most votes becomes the title's primary tag.
- **Lists:** create, read, edit (including the order of entries) and delete your own lists (`/me/lists`). They're private, and deleting an account deletes them.
- **Profile:** name, bio, pronoun, email, Greatest Of All Time, and photo uploads (`/me/profile`). Photos are saved in `server/public/avatars/` and served by Dart Frog.
- **Catalog:** imported from TMDB. Each title's starting moods come from its genres.

### Not built yet

- **Pick for me** (guided picks by mood, match-or-lift, and available time) shows "Coming soon".
- **Favorite** and **Watchlist** tabs on Profile, and the "Add to favorite" / "Add to watchlist" buttons on the details page.
- Vote buttons on the details page (the server side is done).
- Ratings, reviews, delete account, search filters, and password reset.

## Project layout

```
CMPE137Project/
├── README.md                           setup for the whole project
├── .gitignore
├── .vscode/settings.json
│
├── NoiReel/                            Flutter app
│   ├── .env.example                    template for .env (API_URL, TMDB_API_KEY)
│   ├── .env                            never committed
│   ├── .gitignore
│   ├── .metadata
│   ├── .vscode/settings.json
│   ├── analysis_options.yaml           lint rules
│   ├── pubspec.yaml                    dependencies
│   ├── pubspec.lock                    exact package versions
│   ├── lib/
│   │   ├── main.dart                   starts the app, loads .env, the saved theme and the saved login
│   │   ├── api/
│   │   │   ├── api_client.dart         every call to the server goes through here
│   │   │   └── models.dart             Mood, TitleCard, TitleDetails, UserListSummary/Details, Profile, ...
│   │   ├── auth/
│   │   │   ├── auth_controller.dart    who is logged in; saves the session on the device
│   │   │   └── validators.dart         email, username and password checks (same rules as the server)
│   │   ├── screens/
│   │   │   ├── app_shell.dart          the tabs, each with its own page history, and the nav bar
│   │   │   ├── home_screen.dart        Home: theme button and the Discovery grid
│   │   │   ├── mood_screen.dart        Mood tab: one row per mood
│   │   │   ├── mood_titles_screen.dart one mood's page: shuffled grid, loads more on scroll
│   │   │   ├── title_details_screen.dart  details page: facts, mood tags, vote bars, cast
│   │   │   ├── search_screen.dart      Search tab; also "pick a title" mode for lists and GOAT
│   │   │   ├── profile_screen.dart     Profile tab: the 4 tabs, profile view, Greatest Of All Time
│   │   │   ├── profile_settings_screen.dart  Profile Settings: photo, name, email, bio, pronoun, Sign out
│   │   │   ├── lists_screen.dart       the List tab's contents and the + button's flow
│   │   │   ├── new_list_screen.dart    New List and Edit List (hold-to-drag reordering)
│   │   │   ├── list_detail_screen.dart one list's page, with the … menu (Edit, Delete)
│   │   │   ├── login_screen.dart       Log in form
│   │   │   ├── register_screen.dart    Create account form
│   │   │   └── coming_soon_screen.dart placeholder (Pick for me)
│   │   ├── theme/
│   │   │   ├── noireel_theme.dart      all theme colors, and how they become a Flutter theme
│   │   │   └── theme_controller.dart   current theme; saves it on the device
│   │   └── widgets/
│   │       ├── nav_bar.dart            the bottom bar and its tabs and icons
│   │       ├── mood_row.dart           one mood row, loads its own titles
│   │       ├── poster_card.dart        poster, title and year; PosterImage is shared with other pages
│   │       ├── theme_picker.dart       "How are you feeling today?" box with the theme tiles
│   │       ├── fade_slide_in.dart      the fade + slide-up animation used on every page
│   │       ├── form_parts.dart         password field, form error box, submit button
│   │       ├── dialogs.dart            "Discard changes?", "Delete the list?", the guest sign-in popup,
│   │       │                           and the Back / Cancel app bar buttons
│   │       ├── leave_guard.dart        lets an editor ask "Discard changes?" when a nav bar tab is tapped
│   │       └── profile_avatar.dart     round profile photo with the default silhouette
│   ├── test/
│   │   ├── widget_test.dart            theme tests
│   │   ├── title_details_test.dart     details JSON and runtime format tests
│   │   ├── nav_bar_test.dart           nav bar icons, colors and tab switching
│   │   ├── theme_picker_test.dart      theme picker and animation tests
│   │   ├── auth_test.dart              log in, create account, sessions and form checks
│   │   ├── search_test.dart            search results, paging, no results, errors
│   │   ├── mood_titles_test.dart       one mood's page: grid, paging, Back
│   │   ├── list_test.dart              making, editing, reordering and deleting lists
│   │   └── profile_test.dart           profile view, Greatest Of All Time, Profile Settings
│   ├── android/app/src/debug/AndroidManifest.xml
│   │                                   lets the emulator use http:// in debug builds
│   ├── ios/Runner/Info.plist           includes the photo library permission text (iOS only)
│   └── android/ ios/ linux/ macos/ web/ windows/
│                                       platform files generated by Flutter (don't edit)
│
└── server/                             Dart Frog backend
    ├── README.md                       server setup
    ├── API.md                          every route and its JSON (the app follows this)
    ├── .env.example                    template for .env (DB_*, TMDB_API_KEY)
    ├── .env                            never committed
    ├── .gitignore
    ├── .vscode/extensions.json
    ├── analysis_options.yaml
    ├── pubspec.yaml
    ├── bin/
    │   ├── README_SQL.md               database setup, TMDB import, and update scripts
    │   └── import_tmdb.dart            imports movies, TV shows and their starting moods
    ├── db/
    │   ├── README.md
    │   ├── schema.sql                  all tables, views and the vote procedure
    │   ├── seed_moods.sql              the 6 moods and genre-to-mood mappings
    │   ├── update_vote_rule.sql        switches an older database to the vote-count rules
    │   └── update_profile.sql          adds pronoun + Greatest Of All Time to an existing database
    ├── lib/
    │   ├── db.dart                     MySQL connection pool
    │   ├── auth/
    │   │   ├── auth_service.dart       register, login, logout, sessions
    │   │   ├── current_user.dart       the logged-in user from the Bearer token
    │   │   ├── http_helpers.dart       JSON body and Bearer token helpers
    │   │   └── validators.dart         email, username and password rules
    │   ├── browse/
    │   │   └── paging.dart             ?page= and ?limit=, 400 and 404 responses
    │   ├── dao/                        all SQL lives here
    │   │   ├── list_dao.dart           your lists: create, edit, reorder, delete
    │   │   ├── mood_dao.dart
    │   │   ├── profile_dao.dart        profile fields, Greatest Of All Time, avatar
    │   │   ├── session_dao.dart
    │   │   ├── title_dao.dart          includes Discovery and mood-page shuffles
    │   │   ├── user_dao.dart
    │   │   └── vote_dao.dart           mood votes and the 3-per-title limit
    │   ├── lists/
    │   │   └── list_request.dart       checks list request bodies
    │   ├── models/
    │   │   ├── mood.dart               Mood, TitleMood, TitleMoods
    │   │   ├── profile.dart
    │   │   ├── title.dart
    │   │   ├── user.dart
    │   │   └── user_list.dart          UserListSummary, UserListDetails
    │   ├── profile/
    │   │   ├── profile_request.dart    checks Profile Settings and GOAT bodies
    │   │   └── avatar_files.dart       saves and deletes photos in public/avatars/
    │   └── votes/
    │       └── vote_response.dart      reply after a vote: your votes and the updated tags
    ├── public/
    │   └── avatars/                    uploaded profile photos (git-ignored; the folder is kept)
    ├── routes/                         each file is one URL
    │   ├── _middleware.dart            CORS, so the app in Chrome can call the server
    │   ├── index.dart                  GET /
    │   ├── health.dart                 GET /health
    │   ├── auth/
    │   │   ├── _middleware.dart
    │   │   ├── register.dart           POST /auth/register
    │   │   ├── login.dart              POST /auth/login
    │   │   ├── logout.dart             POST /auth/logout
    │   │   └── session.dart            GET /auth/session
    │   ├── discover/
    │   │   ├── _middleware.dart
    │   │   └── index.dart              GET /discover (random posters for Home)
    │   ├── me/                         the logged-in user's own things
    │   │   ├── _middleware.dart
    │   │   ├── lists/
    │   │   │   ├── index.dart          GET, POST /me/lists
    │   │   │   └── [id].dart           GET, PUT, DELETE /me/lists/:id
    │   │   └── profile/
    │   │       ├── index.dart          GET, PUT /me/profile
    │   │       ├── goat.dart           PUT /me/profile/goat
    │   │       └── avatar.dart         POST, DELETE /me/profile/avatar
    │   ├── moods/
    │   │   ├── _middleware.dart
    │   │   ├── index.dart              GET /moods
    │   │   └── [id]/titles.dart        GET /moods/:id/titles
    │   ├── titles/
    │   │   ├── _middleware.dart
    │   │   └── [id]/
    │   │       ├── index.dart          GET /titles/:id
    │   │       └── votes/
    │   │           ├── index.dart      GET /titles/:id/votes
    │   │           └── [moodId].dart   PUT and DELETE /titles/:id/votes/:moodId
    │   └── search/
    │       ├── _middleware.dart
    │       └── index.dart              GET /search?q=
    └── test/
        ├── browse/paging_test.dart
        └── routes/
            ├── index_test.dart
            └── validators_test.dart
```

There are **two separate `.env` files**: one in `NoiReel/` for the Flutter app, one in `server/` for the backend. They hold different things.

## 1. Set up the server first

Follow [server/README.md](server/README.md), then [server/bin/README_SQL.md](server/bin/README_SQL.md) to create the database and fill it. In short:

1. Run `db/schema.sql` in Workbench to create the tables. **This wipes all data**, so only do it for a fresh database.
2. Import titles from TMDB, from `server/`:
   ```
   dart run bin/import_tmdb.dart --pages 1
   ```
3. Run `db/seed_moods.sql` in Workbench **once** to add the moods.

You're done when http://localhost:8080/health shows:

```json
{"status":"ok","db":"connected"}
```

**More titles:** run the importer again with more pages, for example `--pages 5`. It adds new titles without duplicates, keeps votes and accounts, and refreshes the moods by itself. You don't need `seed_moods.sql` again unless you wiped the database or changed the moods.

### Updating an existing database

`schema.sql` always has the full, current design, but running it wipes everything. If you already have data, run these update scripts instead. Each keeps your data and is safe to run twice:

| Script | Run it if | How to check |
|---|---|---|
| `db/update_vote_rule.sql` | your database is from before November 18 | `SHOW COLUMNS FROM title_moods LIKE 'is_confirmed';` returns a row |
| `db/update_profile.sql` | your database is from before November 25 (profile page) | `SHOW TABLES LIKE 'goat_picks';` returns nothing |

Lists need no update script; they use the `watchlists` tables that were already there.

After pulling server changes, **restart `dart_frog dev`** (Ctrl+C, then run it again). New routes, and the `public/` folder for photos, are only picked up when it starts.

## 2. Set up the Flutter app

### Install dependencies

From the `NoiReel/` folder (the one with the Flutter `pubspec.yaml`):

```
flutter pub get
```

"N packages have newer versions incompatible with dependency constraints" is only a notice. You can ignore it.

Run `flutter pub get` again whenever `pubspec.yaml` changes (for example after `image_picker` was added for profile photos), then stop and re-run the app: hot reload and hot restart don't load new native code. To add a package yourself, use `flutter pub add <name>`; it updates `pubspec.yaml` and downloads it.

> **Windows, once per computer:** turn on Developer Mode, or the app won't build ("Building with plugins requires symlink support"). Run `start ms-settings:developers` and switch **Developer Mode** on.

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

- `API_URL`: where the Flutter app finds the server. Use `http://localhost:8080` for Chrome/Windows. Use `http://10.0.2.2:8080` for the Android emulator, unless you use `adb reverse` (see below).
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

## 3. Run the app

### In Chrome

1. From `server/`:
   ```
   dart_frog dev
   ```
2. In another terminal, from `NoiReel/`:
   ```
   flutter run -d chrome
   ```

To see it at phone size, press **F12** in Chrome, then **Ctrl+Shift+M**, pick a phone, and refresh.

Use a full restart (stop and run again) after changing `.env`; hot reload won't pick it up.

### On the Android emulator (Android Studio)

First time only:

1. Install the **Flutter** plugin: **File → Settings → Plugins → Marketplace**, search "Flutter", then install it and restart.
2. Open the `NoiReel` folder, not the whole repo: **File -> Open -> CMPE137Project\NoiReel**. If asked, the Flutter SDK is at `C:\FlutterSDK\flutter`.
3. In **Device Manager**, click **+ -> Create Virtual Device**, pick a phone such as the Pixel 7 Pro, download the recommended system image, and click **Finish**.

Every time:

1. Start the server: open the terminal with **Alt+F12**, then run `cd ..\server` and `dart_frog dev`.
2. Start the emulator with **Device Manager -> Run**.
3. Point the app at the server, using either option:
   - set `API_URL=http://10.0.2.2:8080` in `.env`, or
   - keep `http://localhost:8080` and run `adb reverse tcp:8080 tcp:8080` after the emulator starts.
4. Pick the emulator in the device dropdown at the top and click **Run**. The first build takes several minutes; later ones take seconds.
5. Use **Hot Reload** (Ctrl+\\) after code changes.

## Changing the look

**Theme colors** are all in `NoiReel/lib/theme/noireel_theme.dart`, in `NoiReelPalette.all`. Edit a theme's entry and every screen picks it up.

| Field | Used for |
|---|---|
| `background` | Screen background |
| `navBar` / `navText` | Header and navigation bar, and their text and icons |
| `button` / `buttonText` | Default button, and its text |
| `hover` / `clicked` | Button while hovered / pressed |
| `activeButtonText` | Text on hovered and pressed buttons |
| `bodyText` | Text, form fields, links and errors on the background (picked to be readable, at least 4.5:1 contrast) |
| `pickerBorder` | Optional border of the theme's square in the picker; defaults to `navBar` |

A mood theme's `name` must match the mood's name in the database exactly (`Melancholy`, not `Melancholic`).

**Mood tags and vote bars** on the details page use each mood theme's `navBar`, `navText` and picker border. They're drawn by `_MoodTag` and `_VoteBar` in `title_details_screen.dart`.

**Nav bar settings** are in `NoiReel/lib/widgets/nav_bar.dart`:
- `showLabels = false` hides the labels.
- `unselectedOpacity` sets how dim the unselected tabs are.
- `navTabs` holds the icons: `_outlined` versions for `icon`, filled ones for `selectedIcon`.

**Animation speed:** `defaultDuration` in `NoiReel/lib/widgets/fade_slide_in.dart`, currently 500 ms.

**Hold-to-drag time** for reordering list entries: `holdToDrag` in `NoiReel/lib/screens/new_list_screen.dart`, currently 1.5 s. Flutter's normal long press is 500 ms. Use a full restart after changing it.

**Pronoun choices:** `Profile.pronouns` in `NoiReel/lib/api/models.dart` and `ProfileDao.pronouns` in `server/lib/dao/profile_dao.dart`. Keep the two in sync.

## Troubleshooting

- **"Unable to load asset: .env"**: the file isn't next to `pubspec.yaml`, or you skipped `flutter pub get`.
- **A value comes back empty**: the key name in `.env` doesn't match the code exactly.
- **Requests to the server fail / "Can't reach the server"**: check the server is running (`dart_frog dev` in `server/`) and `API_URL` matches. On the emulator, use `10.0.2.2` or `adb reverse`.
- **"Building with plugins requires symlink support"**: turn on Windows Developer Mode (see step 2).
- **"Target of URI doesn't exist: package:shared_preferences"**: run `flutter pub get`.
- **Home page says "No moods yet"**: run `server/db/seed_moods.sql` in Workbench.
- **Few titles, or Search can't find a movie**: only imported titles are searchable. Run the importer with more `--pages`.
- **Workbench "Error Code: 1175 ... safe update mode"**: the script needs `SET SQL_SAFE_UPDATES = 0;` at the top (`seed_moods.sql` already has it).
- **Server says "rogue route" for `titles/[id].dart`**: delete `server/routes/titles/[id].dart`; it moved to `[id]/index.dart`.
- **Emulator stuck on "Starting up"**: wait up to 5 minutes the first time. If it's still stuck, use **⋮ → Cold Boot Now**, and make sure **Windows Hypervisor Platform** is on in Windows Features.
- **App is slow in Chrome**: `flutter run -d chrome` is a debug build. Try `flutter run -d chrome --profile` to see real speed.
- **Details page shows no rating**: expected. The rating line appears once users can rate titles.
- **"Something went wrong (405)" when saving a list or profile**: the server is running old route files. Make sure the new `server/` files are in place, then restart `dart_frog dev`.
- **Profile tab shows an error, or Greatest Of All Time won't save**: run `db/update_profile.sql` (see "Updating an existing database").
- **Profile photo doesn't show after uploading**: restart `dart_frog dev` so it serves `server/public/`, and check the folder `server/public/avatars/` exists.
- **Lists or Profile Settings: "Admin accounts can't have lists."**: expected; admins don't have lists.
- **Server freezes under heavy load**: a known bug in the `mysql_client` package. With more than 10 requests at the same moment, it hangs instead of waiting. A related bug: a database transaction that fails partway never gives its connection back, so repeated failures can freeze it too. Restart `dart_frog dev`.