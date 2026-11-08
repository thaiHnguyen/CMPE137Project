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

```
Mood      {moodId, name, description, colorHex, counterMoodIds: [int]}
TitleCard {titleId, type: "movie"|"tv", name, year, posterUrl}
```

`colorHex` is only a fallback. The app should use the current theme's color for a mood when it has one. A `null` `posterUrl` means show a placeholder.

Title details:

```json
{
  "titleId": 4, "type": "movie", "name": "Example", "year": 2020, "posterUrl": null,
  "synopsis": "...", "runtimeMin": 120, "seasons": null, "episodes": null,
  "avgRating": 4.5, "ratingCount": 12,
  "genres": ["Drama"],
  "directors": [{"personId": 1, "name": "..."}],
  "creators": [],
  "cast": [{"personId": 2, "name": "...", "character": "..."}],
  "moods": {
    "primary": {"moodId": 5, "name": "Calm", "colorHex": "#EAE9E5", "votes": 3, "isConfirmed": true},
    "secondary": [{"moodId": 2, "name": "Gloomy", "colorHex": "#1D5632", "votes": 0, "isConfirmed": false}],
    "voters": 5,
    "votes": [
      {"moodId": 5, "name": "Calm", "colorHex": "#EAE9E5", "votes": 3, "isConfirmed": true},
      {"moodId": 6, "name": "Excited", "colorHex": "#BE280F", "votes": 2, "isConfirmed": false}
    ]
  }
}
```

Rules:

- **Mood rows:** ranked by mood fit (`mood_score`). TMDB rating, then popularity, only break ties. Titles with 1-199 TMDB votes are left out unless the community confirmed the mood or an admin curated it.
- **Mood tags:** `primary` and `secondary` hold up to 5 public tags in total, which can come from the title's genres, so a tag can have 0 votes. `votes` is the Fragrantica-style results panel: every mood with at least one vote, highest first, including moods the majority hasn't adopted.
- **Search:** matches part of a title, director, creator or cast name, ignoring case. Results go exact title, title starts with the keyword, title contains it, then person match. The keyword is 1-100 characters. For `total: 0`, show "No results" and a suggestion to broaden the search (GU-02.04).
