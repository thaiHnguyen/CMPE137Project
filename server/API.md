# NoiReel server API

Base URL in development: `http://localhost:8080`. All bodies are JSON.

## Auth

The app stores the `token` it gets from register/login (e.g. in secure storage)
and sends it on every request that needs a logged-in user:

```
Authorization: Bearer <token>
```

Sessions last until logout, or until 30 days without use.

| Method & path | Body | Success | Errors |
|---|---|---|---|
| `POST /auth/register` | `{email, username, password}` | `201 {token, userId, role}` | `400 {error:"invalid", field, message}` · `409 {error:"taken", field, message}` |
| `POST /auth/login` | `{login, password}` (login = email **or** username) | `200 {token, userId, role}` | `401 {error:"incorrect", message}` · `423 {error:"locked", message, until}` · `403 {error:"suspended"\|"banned", reason, until}` |
| `GET /auth/session` | none (Bearer token) | `200 {status:"valid", userId, username, role}` | `401 {status:"expired"}` |
| `POST /auth/logout` | none (Bearer token) | `204` | `401 {error:"no_token"}` |

Rules (from the FR doc):

- **Username:** 3-20 letters, digits or underscores. **Password:** 8+ characters with a letter and a digit.
- Email and username are case-insensitive and must be unique. Every new account gets a private default "Watchlist".
- 5 wrong passwords lock the account for 15 minutes.
- `field` in a 400/409 tells the app which input box to highlight.
- On app start, call `GET /auth/session`. If it returns `expired`, delete the stored token and show the guest home screen.

## Browsing

None of these need a login. Lists take optional `?page=` (default 1) and `?limit=` (default 20, max 50). A bad value returns `400 {error:"invalid", message}`. Fields with no data are `null` or `[]`, so the app can hide them (GU-03.04).

| Method & path | Success | Errors |
|---|---|---|
| `GET /moods` | `200 {moods: [Mood]}` | none |
| `GET /moods/:id/titles` | `200 {mood: Mood, page, limit, total, titles: [TitleCard]}` | `404 {error:"not_found", message}` |
| `GET /titles/:id` | `200` title details (below) | `404 {error:"not_found", message}` |
| `GET /search?q=` | `200 {query, page, limit, total, titles: [TitleCard]}` | `400 {error:"invalid", field:"q", message}` |
| `GET /discover?limit=30` | `200 {titles: [TitleCard]}` | `400 {error:"invalid", message}` |

```
Mood      {moodId, name, description, colorHex, counterMoodIds: [int]}
TitleCard {titleId, type: "movie"|"tv", name, year, posterUrl}
```

`colorHex` is only a fallback. The app should use the current theme's color for a mood when it has one. A `null` `posterUrl` means show a placeholder.

Title details:

```json
{
  "titleId": 4, "type": "movie", "name": "Example", "year": 2020, "posterUrl": null,
  "originalName": "例", "backdropUrl": "https://image.tmdb.org/t/p/w1280/....jpg",
  "synopsis": "...", "runtimeMin": 120, "seasons": null, "episodes": null,
  "avgRating": 4.5, "ratingCount": 12,
  "ratingHistogram": [0, 0, 0, 1, 0, 2, 1, 3, 2, 3],
  "genres": ["Drama"],
  "directors": [{"personId": 1, "name": "..."}],
  "creators": [],
  "cast": [{"personId": 2, "name": "...", "character": "..."}],
  "moods": {
    "primary": {"moodId": 5, "name": "Calm", "colorHex": "#EAE9E5", "votes": 3},
    "secondary": [
      {"moodId": 6, "name": "Excited", "colorHex": "#BE280F", "votes": 2},
      {"moodId": 2, "name": "Gloomy", "colorHex": "#1D5632", "votes": 0}
    ],
    "voters": 4,
    "votes": [
      {"moodId": 5, "name": "Calm", "colorHex": "#EAE9E5", "votes": 3},
      {"moodId": 6, "name": "Excited", "colorHex": "#BE280F", "votes": 2}
    ]
  }
}
```

Rules:

- **Mood rows:** ranked by mood fit (`mood_score`). TMDB rating, then popularity, only break ties. `mood_score` is genre fit + votes + admin curation. Titles with 1-199 TMDB votes are left out unless users voted the mood or an admin curated it.
- **Mood tags:** the mood with the most votes is `primary`, then `secondary` in order of votes, up to 5 tags in total. Every vote counts right away. Moods nobody voted for yet come after the voted ones, ordered by genre fit, so before anyone votes all tags come from the title's genres (0 votes). Ties in votes go to the better genre fit. `voters` is how many different users voted any mood on the title.
- **Vote results:** `votes` is the Fragrantica-style results panel: every mood with at least one vote, in the same order as the tags.
- **Details page extras:** `originalName` is the title in its own language, only when it differs from `name` (otherwise `null`). `backdropUrl` is a wide still for behind the header, or `null`. `ratingHistogram` always has 10 counts, for 0.5, 1.0, ... 5.0 stars, in that order. Both new fields are filled by the TMDB importer.
- **Discover:** random titles for the home page's Discovery grid, different on every call. Only titles with a poster and at least 200 TMDB votes (or no TMDB score at all, e.g. added by an admin). `limit` is 1-60, default 30.
- **Search:** matches part of a title, director, creator or cast name, ignoring case. Results go exact title, title starts with the keyword, title contains it, then person match. The keyword is 1-100 characters. For `total: 0`, show "No results" and a suggestion to broaden the search (GU-02.04).
- **Shuffled mood page:** `GET /moods/:id/titles?shuffle=<number>` returns the same titles in a random order. The same number always gives the same order, so keep it while loading more pages (no repeats) and send a new one to reshuffle. The number is 1-2147483647.

## Mood voting

Needs a logged-in registered user (`Authorization: Bearer <token>`). Each user can vote **up to 3 moods per title**, and opposite moods (like Hopeful and Gloomy) are allowed.

| Method & path | Success | Errors |
|---|---|---|
| `GET /titles/:id/votes` | `200` vote state (below) | `401` · `404 {error:"not_found"}` |
| `PUT /titles/:id/votes/:moodId` | `200` vote state | `401` · `403 {error:"forbidden"}` (admin) · `404` · `409 {error:"vote_limit", message, maxVotes}` |
| `DELETE /titles/:id/votes/:moodId` | `200` vote state | `401` · `403` · `404` |

Vote state:

```json
{
  "titleId": 4,
  "myMoodIds": [5, 2],
  "maxVotes": 3,
  "moods": {"primary": {...}, "secondary": [...], "voters": 4, "votes": [...]}
}
```

- `myMoodIds` are the moods this user voted on this title. Use them to highlight the user's choices.
- `moods` has the same shape as in title details, already updated with this vote, so the app can redraw without loading the title again.
- `PUT` and `DELETE` are safe to repeat: voting a mood twice or removing a vote that isn't there changes nothing and still returns `200`.
- `401 {error:"unauthorized", message}` means the token is missing or expired. Send the user to the login screen.
- `409 vote_limit` means the user already has 3 moods on this title. Show the message; they can remove one and pick another.

## Your lists

Needs a logged-in registered user (`Authorization: Bearer <token>`). Lists are private to their owner, and deleting an account deletes its lists. The default Watchlist is not included here.

| Method & path | Body | Success | Errors |
|---|---|---|---|
| `GET /me/lists` | none | `200 {lists: [ListSummary]}` | `401` · `403` (admin) |
| `POST /me/lists` | `{name, description?, titleIds: [int]}` | `201 {list: ListDetails}` | `400 {error:"invalid", field, message}` · `401` · `403` |
| `GET /me/lists/:id` | none | `200 {list: ListDetails}` | `401` · `404 {error:"not_found"}` |
| `PUT /me/lists/:id` | `{name, description?, titleIds: [int]}` | `200 {list: ListDetails}` | `400` · `401` · `404` |
| `DELETE /me/lists/:id` | none | `204` | `401` · `404` |

```
ListSummary {listId, name, description, entryCount, posterUrls: [string], updatedAt}
ListDetails {listId, name, description, entryCount, entries: [TitleCard]}
```

- `name`: 1-60 characters after trimming. `description`: optional, up to 500 characters.
- `titleIds`: the entries **in the order they were added**, up to 500. Duplicates are dropped (the first one is kept). Unknown ids give a `400` naming them.
- `entries` come back in that same order. `posterUrls` holds the first 4 posters, for the list's card.
- Lists are sorted most recently changed first.
- `PUT` saves an edit. It replaces the whole list: name, description and entries in the order sent, so reordering or removing entries is just sending the new order. Same checks as `POST`.
- `DELETE` removes the list and its entries. Someone else's list gives `404`, same as a missing one.

## Your profile

Needs a logged-in user (`Authorization: Bearer <token>`, else `401`). Works for admins too.

| Method & path | Body | Success | Errors |
|---|---|---|---|
| `GET /me/profile` | none | `200 {profile: Profile}` | `401` |
| `PUT /me/profile` | `{displayName?, bio?, pronoun?, email}` | `200 {profile: Profile}` | `400 {error:"invalid", field, message}` · `409 {error:"taken", field:"email"}` |
| `PUT /me/profile/goat` | `{titleIds: [5 × int or null]}` | `200 {profile: Profile}` | `400 {error:"invalid", field:"titleIds"}` |
| `POST /me/profile/avatar` | multipart form, file field `avatar` | `200 {profile: Profile}` | `400 {error:"invalid", field:"avatar"}` · `413 {error:"too_large"}` |
| `DELETE /me/profile/avatar` | none | `200 {profile: Profile}` | `401` |

```
Profile {userId, username, email, role, displayName, bio, pronoun, avatarUrl,
         goat: [TitleCard or null, × 5]}
```

- `displayName`: up to 50 characters, `bio`: up to 160. A blank one clears it (the app then shows the username).
- `pronoun`: `null` or one of `he/him`, `she/her`, `they/them`, `he/they`, `she/they`, `xe/xem`, `ze/hir`, `it/its`.
- `email` is required on every save: trimmed, lowercased, and must not belong to another account (`409`). The username can't be changed.
- `goat` is the Greatest Of All Time: always 5 slots, left to right, `null` for an empty one. Saving sends all 5; a title can fill only one slot. Unknown ids give a `400`.
- Avatars: JPEG, PNG or WebP, up to 5 MB (checked by the file's contents, not its name). They're saved in `server/public/avatars/` and `avatarUrl` is a path such as `/avatars/7-1764123456789.jpg`, served by Dart Frog from `public/`. Put the server address in front to show it. Changing or removing an avatar deletes the old file.
