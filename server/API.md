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
