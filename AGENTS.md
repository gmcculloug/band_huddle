# AGENTS.md — Band Huddle

Guidance for AI agents working in this repository. Read this before making changes.

## Docs Index

Detailed, repo-specific rules live in these guideline files:

- [docs/security-guidelines.md](docs/security-guidelines.md) — Auth (bcrypt/JWT/OAuth), session management, role-based access, account lockout, band-scoped data access
- [docs/error-handling-guidelines.md](docs/error-handling-guidelines.md) — ErrorHandler service, HTML vs JSON error paths, rescue patterns, status codes
- [docs/api-contracts-guidelines.md](docs/api-contracts-guidelines.md) — Two API surfaces (session vs mobile JWT), response shapes, pagination, delta-sync endpoints
- [docs/database-guidelines.md](docs/database-guidelines.md) — Custom migration system, schema conventions, soft-delete pattern, band-scoped queries
- [docs/testing-guidelines.md](docs/testing-guidelines.md) — RSpec setup, FactoryBot conventions, database teardown order, TimeHelpers/Timecop
- [docs/integration-guidelines.md](docs/integration-guidelines.md) — Google Calendar service pattern, sync state tracking, external credential management

## Architecture Context

**This is a Sinatra app, not Rails.** This distinction affects almost everything:

- No `rails generate`, no `rails console`, no `rails routes` — use `ruby app.rb` to start the server
- Migrations are created with `rake db:create_migration NAME=foo` and run with `rake db:migrate` (custom runner in `Rakefile`, not Rails)
- There is no `rails_helper` in specs — require `spec_helper` instead
- Models inherit from `ActiveRecord::Base` directly; they are defined in `app.rb` (small models) or `lib/models/` (larger ones)
- Routes are split across `lib/routes/` files and mounted in `app.rb` via `use`
- Helpers live in `lib/helpers/application_helpers.rb` and are included via `helpers ApplicationHelpers`

**Single entry point**: `app.rb` is the main file. It contains configuration, model definitions, and `use` declarations for route files. When adding a new model or service, `require` it in `app.rb`.

**No background jobs**: There is no Sidekiq, Resque, or ActiveJob. All work is synchronous within the request cycle.

**Session store**: Cookie-based by default; switches to Redis/Valkey when `VALKEY_ENABLED=true`.

## Key Coding Conventions

### Band-Scoped Data Access

Every query for user-facing data must be scoped to the current band. This is the most important security invariant in the codebase.

```ruby
# CORRECT — use the helper
@gig = filter_by_current_band(Gig).find(params[:id])
@venues = filter_by_current_band(Venue).active.order(:name)

# CORRECT — look up bands through membership
@band = user_bands.find(params[:id])

# WRONG — never query without scoping
@gig = Gig.find(params[:id])      # leaks data across bands
@band = Band.find(params[:id])    # allows access to any band
```

`filter_by_current_band` handles the join differently per model: `Gig`/`Venue` use `where(band: current_band)`; `Song` uses `joins(:bands).where(bands: { id: current_band.id })`.

### Dual API Surfaces

There are two distinct API surfaces that must never be mixed:

| Surface | Files | Auth guard | Response shape |
|---|---|---|---|
| Session API | `lib/routes/api.rb`, `lib/routes/authentication.rb` | `require_login` | Bare array/object for GETs; `{ success:, data: }` for mutations |
| Mobile JWT API | `lib/routes/mobile_api.rb` | `require_login` (most routes) | `{ data:, meta: }` wrapper always |

New endpoints go in the correct file. Do not add mobile-style `data`/`meta` wrappers to session API responses.

### UTC Timezone Storage

All timestamps are stored in UTC. Convert to user timezone only at display time using `current_user.user_timezone`. Never store local time in the database.

```ruby
# Storing — convert to UTC
self.start_time = Time.parse(params[:time]).in_time_zone(user_timezone).utc

# Displaying — convert from UTC
start_time.in_time_zone('UTC').in_time_zone(user_timezone)
```

### Soft-Delete (Archivable)

`Song`, `Venue`, and `SongCatalog` are never hard-deleted. Use `include Archivable` and the `.active` scope. Always filter with `.active` when listing records for display.

### Error Handling Split

HTML routes: set `@errors` (array) or `@error` (string) and re-render the template.  
JSON API routes: set `status` and return a JSON hash. Wrap in `begin/rescue` blocks — specific exceptions first, then `rescue => e` for 500.

## Things Agents Commonly Get Wrong

### Database / Migrations
- **Do not use `rails generate migration`** — this is not a Rails app. Use `rake db:create_migration NAME=foo`.
- **Do not modify `db/schema.rb` directly** — it is auto-generated. Only migrations change the schema.
- **Inherit from `ActiveRecord::Migration[7.0]`** — that is what the `db:create_migration` template generates.
- **Always add foreign key indexes** — the convention is every FK column gets its own index.

### Authentication / Authorization
- **Never use `Band.find`** for user-facing lookups — always go through `user_bands.find` or `current_user.bands.find`.
- **Never add a new route without an auth guard** — every new route needs either `require_login` (HTML/session routes) or `require_login`/`require_api_auth` (API routes).
- **Check ownership before destructive operations** — use `band.owned_by?(current_user)`, not just `band.users.include?(current_user)`.

### Testing
- **No `DatabaseCleaner`** — the project uses manual `delete_all` in `before(:each)` blocks with a specific teardown order. Add new models to `spec_helper.rb` in the right position (before their FK dependencies).
- **Use `login_as(user, band)`** for request specs — not cookies, not direct session writes.
- **Do not redefine `login_as`** in new spec files — use the global helper from `spec_helper.rb`.
- **Use `freeze_time_for_testing`** for any test that depends on `Date.current`, `Time.now`, or relative dates.

### API Responses
- **Set `content_type :json`** before returning JSON from any API route.
- **Never return raw ActiveRecord objects** — format all dates with `strftime` or `.iso8601` before serializing.
- **Always check `current_band` presence** before querying band-scoped data in API routes; return 400 with `"No band selected"` if nil.

### Integrations
- **Never call external APIs from models or routes directly** — use a service class in `lib/services/`.
- **Store credentials in environment variables**, never in files or committed code. Document new env vars in `env.example`.

## Environment Variables

Required in production (app will refuse to start without them):

| Variable | Purpose |
|---|---|
| `SESSION_SECRET` | Session cookie signing (min 32 chars) |
| `JWT_SECRET` | JWT token signing (min 32 chars) |
| `DATABASE_URL` | PostgreSQL connection (or use individual `DATABASE_*` vars) |
| `BAND_HUDDLE_ACCT_CREATION_SECRET` | Gates new user registration |

Optional:
| Variable | Purpose |
|---|---|
| `VALKEY_ENABLED` | Set `true` to use Redis/Valkey for session storage |
| `GOOGLE_SERVICE_ACCOUNT_JSON` | JSON blob for Google Calendar service account |
| `JWT_ACCESS_TOKEN_EXPIRY` | Access token TTL in seconds (default: 3600) |
| `JWT_REFRESH_TOKEN_EXPIRY` | Refresh token TTL in seconds (default: 2592000) |

Generate secrets: `openssl rand -hex 64`
