# API Contracts Guidelines — Band Huddle

## 1. Two API Surfaces

Band Huddle exposes two distinct API surfaces. Every new endpoint must belong to exactly one.

| Surface | Path prefix | Auth mechanism | Guard helper | Primary consumer |
|---------|-------------|----------------|--------------|------------------|
| **Session API** | `/api/*` and `/api/auth/*` | Cookie session (`session[:user_id]`) | `require_login` | Web front-end (AJAX calls from ERB pages) |
| **Mobile JWT API** | `/api/mobile/*` | `Authorization: Bearer <access_token>` | `require_api_auth` | Native mobile clients |

**Rules:**

- Place session-based endpoints in `lib/routes/api.rb` (or `lib/routes/authentication.rb` for `/api/auth/*` session endpoints).
- Place JWT endpoints in `lib/routes/mobile_api.rb`.
- Prefer not mixing auth mechanisms within a single route file. Note: `mobile_api.rb` currently uses `require_login` for most routes and `require_api_auth` only for `GET /api/mobile/auth/validate`. New endpoints in `mobile_api.rb` should use `require_login` to be consistent with existing routes; reserve `require_api_auth` for routes that must reject unauthenticated callers with a JSON 401 rather than a redirect.
- `require_login` redirects unauthenticated users to `/login` (suitable for web). `require_api_auth` halts with a 401 JSON body (suitable for API clients). Choose the correct one based on the required behavior.

## 2. Authentication Headers (Mobile JWT)

Mobile clients authenticate via the `Authorization` header:

```
Authorization: Bearer <access_token>
```

- Obtain tokens via `POST /api/mobile/auth/token` with `username` and `password` params.
- Response includes `access_token`, `refresh_token`, `expires_in` (seconds), and `token_type: "Bearer"`.
- Refresh via `POST /api/mobile/auth/refresh` with `refresh_token` param.
- Access tokens expire in 1 hour (configurable via `JWT_ACCESS_TOKEN_EXPIRY`). Refresh tokens expire in 30 days (`JWT_REFRESH_TOKEN_EXPIRY`).
- The `user_from_jwt_token` helper in `ApplicationHelpers` extracts the user transparently; `current_user` works for both session and JWT flows.

## 3. Session API Authentication

Session-based auth endpoints live under `/api/auth/*`:

- `POST /api/auth/login` — sets session cookie, returns user + bands JSON.
- `GET /api/auth/session` — validates current session.
- `POST /api/auth/logout` — clears session.
- `GET /api/auth/user` — returns current user with band details.
- `POST /api/auth/switch_band` — switches active band in session.

These depend on the cookie session, not JWT. `GET /api/auth/user` and `POST /api/auth/switch_band` are guarded with `require_login`; `POST /api/auth/login`, `GET /api/auth/session`, and `POST /api/auth/logout` are unguarded by design (they handle unauthenticated callers themselves).

## 4. Response Envelope Shapes

The codebase uses two response shapes depending on the surface. Follow the existing pattern exactly.

**Session API (`/api/*`) — read (GET) endpoints:** Simple read endpoints in `api.rb` return data directly at the top level with no wrapping envelope.

```json
[
  { "id": 1, "title": "Song Title", "artist": "Artist" }
]
```

**Session API (`/api/*`) — mutation (POST/PUT/DELETE) and auth (`/api/auth/*`) endpoints:** Use a `{ "success": true/false, "data": ... }` envelope, consistent with the mobile API mutation shape.

```json
{
  "success": true,
  "data": { "id": 1, "title": "..." }
}
```

**Mobile API (`/api/mobile/*`):** Wraps data in `{ "data": ..., "meta": ... }`.

```json
{
  "data": { ... },
  "meta": {
    "total_count": 42,
    "page": 1,
    "per_page": 20,
    "total_pages": 3,
    "last_modified": "2025-01-15T12:00:00Z"
  }
}
```

**Mutation success responses** (POST/PUT/DELETE on mobile API) use:

```json
{
  "success": true,
  "data": { "id": 1, "title": "...", "created_at": "..." }
}
```

**Rule:** Never add a `meta` block to session API endpoints. Never omit the `data`/`meta` wrapper from mobile API list endpoints.

## 5. Error Response Format

All API errors (both surfaces) use a consistent shape:

```json
{ "error": "Human-readable error message" }
```

For validation failures (422), add a `details` array:

```json
{ "error": "Validation failed", "details": ["Title can't be blank"] }
```

For auth failures from `require_api_auth`:

```json
{ "error": "Authentication required", "code": "UNAUTHORIZED" }
```

**HTTP status codes used in the codebase:**

| Code | Meaning | When to use |
|------|---------|-------------|
| 200 | OK | Successful GET, PUT, POST, DELETE |
| 400 | Bad Request | Missing required params, no band selected, invalid format |
| 401 | Unauthorized | Invalid credentials or expired token/session |
| 403 | Forbidden | Access denied (e.g., wrong band) |
| 404 | Not Found | `ActiveRecord::RecordNotFound` |
| 422 | Unprocessable | Model validation failure |
| 500 | Server Error | Unexpected exceptions (generic message, no stack trace) |

**Rule:** Never expose internal error messages or stack traces in 500 responses. Use generic messages like `"Failed to fetch gigs"`.

## 6. Pagination

Pagination is used only on mobile API list endpoints (`/api/mobile/gigs`, `/api/mobile/songs`).

**Query parameters:**

- `page` — 1-indexed page number (default: `1`)
- `per_page` — items per page (default: `20`, hard cap: `50`)

**Meta block shape:**

```json
"meta": {
  "total_count": 100,
  "page": 2,
  "per_page": 20,
  "total_pages": 5,
  "last_modified": "2025-01-15T12:00:00Z"
}
```

**Rules:**

- Always cap `per_page` with `[params_value, 50].min`.
- Use `limit`/`offset` for pagination (not cursor-based).
- Include `last_modified` in meta from `maximum(:updated_at)`.
- Session API endpoints (`/api/*`) do not paginate; they return full collections.

## 7. Delta-Sync Endpoints

The mobile sync system provides two endpoints:

- `GET /api/mobile/sync/manifest` — returns `last_modified` timestamps and `counts` per resource type (gigs, songs, venues) for the current band.
- `GET /api/mobile/sync/delta?since=<ISO8601>` — returns records updated after `since` (defaults to 24 hours ago). Hard-capped at 100 gigs, 100 songs, 50 venues per response.

Delta records include an `action` field (currently always `"update"`). Both endpoints wrap responses in `{ "data": ... }`.

**Rules:**

- Always include `generated_at` (ISO 8601) in sync responses.
- Parse `since` with `Time.parse` and rescue `ArgumentError` with a 400.
- Guard both endpoints with `require_login` and check `current_band` presence.

## 8. Live Updates (Polling)

`GET /api/gigs/:id/live_updates?since=<ISO8601>` supports polling for real-time practice-state changes during gig mode. The `since` parameter defaults to 5 minutes ago. Response shape:

```json
{
  "data": {
    "gig_id": 1,
    "since": "...",
    "updates": [...],
    "generated_at": "..."
  }
}
```

## 9. Date and Time Formatting

- Dates: `strftime('%Y-%m-%d')` — always `YYYY-MM-DD`.
- Times: `strftime('%H:%M')` — always `HH:MM` (24-hour).
- Timestamps: `.iso8601` — always ISO 8601 with timezone.
- Duration strings: `"M:SS"` format (e.g., `"4:54"`).

**Rule:** Never return raw ActiveRecord datetime objects. Always format before serialization.

## 10. Band Scoping

All data access must be scoped to the current band using `filter_by_current_band(ModelClass)`. This helper handles the join logic per model type:

- `Song` — joins through `bands` (many-to-many).
- `Gig`, `Venue` — filters by `band: current_band` (belongs_to).

**Rules:**

- Never query models without band scoping in API routes.
- Always check `current_band` presence before querying; return 400 with `"No band selected"` if nil.
- For mobile create endpoints, use `current_band.gigs.build(...)` to auto-associate.

## 11. Backward Compatibility

- Session API endpoints are consumed by in-app JavaScript. Changing their shape breaks the web UI immediately.
- Mobile API endpoints are consumed by native apps that may not update promptly.
- Never remove or rename existing response fields. Add new fields alongside existing ones.
- The `display_key` and `tempo_display` fields on `GET /api/gigs/:id/mobile_gig_mode` demonstrate the pattern: add computed convenience fields rather than changing raw field names.
- When deprecating a field, keep it in responses for at least two release cycles.

## 12. Adding a New API Endpoint Checklist

1. Choose the correct surface (session vs. mobile JWT).
2. Place the route in the correct file (`api.rb` vs. `mobile_api.rb`).
3. Use the correct auth guard (`require_login` vs. `require_api_auth`).
4. Set `content_type :json` at the top of the route block.
5. Scope all queries through `filter_by_current_band`.
6. Use the correct response envelope (bare vs. `data`/`meta` wrapper).
7. Rescue `ActiveRecord::RecordNotFound` with 404 and generic errors with 500.
8. Format all dates/times consistently per Section 9.
9. Add pagination if it is a mobile list endpoint.
10. Include `updated_at` (ISO 8601) on resource objects to support delta sync.
11. Write request specs in `spec/requests/`.

## 13. Route File Organization

Each route file is a `Sinatra::Base` subclass mounted via `use` in `app.rb`:

```ruby
class Routes::MobileAPI < Sinatra::Base
  helpers ApplicationHelpers
  # routes...
end
```

Group routes by section with comment banners:

```ruby
# ============================================================================
# MOBILE SONGS API
# ============================================================================
```

Keep private helper methods at the bottom of the class. If a helper is shared across surfaces, place it in `lib/helpers/application_helpers.rb`.
