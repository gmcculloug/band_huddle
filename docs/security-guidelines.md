# Security Guidelines for Band Huddle

## 1. Authentication

### 1.1 Password Authentication (bcrypt)
- The `User` model uses `has_secure_password validations: false` from ActiveRecord. Passwords are hashed with bcrypt via `password_digest`. All password validations are handled manually by the model.
- Minimum password length is 6 characters, enforced by the conditional model validation `validates :password, length: { minimum: 6 }, if: :password_required?`. This validation only runs when a password is being set on a non-OAuth user.
- Username lookups are always case-insensitive: `User.where('LOWER(username) = ?', params[:username].downcase).first`.
- Never compare passwords directly. Always use `user.authenticate(params[:password])`, which returns `false` for OAuth-only users who have no `password_digest`.

### 1.2 JWT Authentication (Mobile API)
- JWT tokens are issued at `/api/mobile/auth/token` and used for mobile/API access via `Authorization: Bearer <token>` headers.
- Access tokens expire in 1 hour (configurable via `JWT_ACCESS_TOKEN_EXPIRY` env var, stored as `JwtService::ACCESS_TOKEN_EXPIRY`); refresh tokens expire in 30 days (configurable via `JWT_REFRESH_TOKEN_EXPIRY` env var, stored as `JwtService::REFRESH_TOKEN_EXPIRY`).
- Every token includes a unique `jti` (JWT ID) claim generated with `SecureRandom.uuid`.
- Tokens carry a `type` field (`'access'` or `'refresh'`). Always validate the type matches the expected use via `decode_access_token` or `decode_refresh_token` — never use the generic `decode_token` for authentication.
- JWT revocation is client-side only (stateless tokens). The `/api/mobile/auth/revoke` endpoint instructs clients to delete stored tokens.

### 1.3 OAuth Authentication (Google, GitHub, Apple)
- OAuth state parameters are generated with `SecureRandom.hex(16)` and stored in `session[:oauth_state]`. The callback verifies `params[:state] == session[:oauth_state]` before proceeding. Always include this CSRF check.
- New OAuth users must provide an account creation code (`BAND_HUDDLE_ACCT_CREATION_SECRET`) before their account is created. This is enforced in `OauthService.create_oauth_user_with_validation`.
- Pending OAuth data stored in `session[:pending_oauth_user]` has a 30-minute timeout enforced by checking `Time.now.to_i - pending_data[:timestamp] > 1800`.
- Only one OAuth provider per user is allowed. The code raises an error if a user with a different provider tries to link via the same email.
- The `User` model's `oauth_provider` validation allows only `'google'` and `'github'`. Apple is handled in `OauthService` but would fail the model-level `inclusion` validation if stored.
- SSL verification must be `VERIFY_PEER` in production. The `VERIFY_NONE` fallback is restricted to development only, and only as a fallback when `OpenSSL::X509::Store` setup fails.

### 1.4 Dual Authentication Support
- A user can have both password and OAuth authentication. The model enforces at least one method via the `must_have_authentication_method` validation.
- `password_user?` checks `password_digest.present?`; `oauth_user?` checks `oauth_provider.present? && oauth_uid.present?`.
- OAuth unlinking (`OauthService.unlink_oauth_from_user`) requires a password to be set first.

## 2. Session Management

- Web sessions use `session[:user_id]` and `session[:band_id]`.
- On logout, always call `session.clear` to destroy all session data.
- When Valkey is enabled (`VALKEY_ENABLED=true`), sessions are stored server-side via `Rack::Session::Redis`. Otherwise, Sinatra's built-in cookie sessions are used.
- The session cookie is named `_band_huddle_session`.
- Account deletion clears the session before destroying the user record.

## 3. Production Secret Requirements

These environment variables are mandatory in production and enforced at boot time:

| Variable | Min Length | Purpose |
|---|---|---|
| `SESSION_SECRET` | 32 chars | Session cookie signing |
| `JWT_SECRET` | 32 chars | JWT token signing |
| `BAND_HUDDLE_ACCT_CREATION_SECRET` | any | Gate for new user registration |

The app calls `exit 1` if `SESSION_SECRET` is missing or too short in production. `JwtService` raises an exception for missing/short `JWT_SECRET`. Generate secrets with `openssl rand -hex 64`.

Development environments fall back to hardcoded defaults — never use these in production.

## 4. Route Authentication Guards

### 4.1 Web Routes
- Every web route that requires login must call `require_login` at the top. This helper redirects unauthenticated users to `/login`.

### 4.2 API Routes
- JSON API routes that require authentication must call `require_api_auth`. This returns a 401 JSON response with `halt` to stop execution:
```ruby
def require_api_auth
  unless logged_in?
    content_type :json
    status 401
    halt({ error: 'Authentication required', code: 'UNAUTHORIZED' }.to_json)
  end
end
```

### 4.3 Authentication Resolution Order
- The `current_user` helper checks JWT token first (from `Authorization` header), then falls back to session. This allows both mobile API and web access through the same helpers.

## 5. Role-Based Authorization

### 5.1 Roles
- Two roles exist in `user_bands`: `'owner'` and `'member'`. Validated by `inclusion: { in: ['member', 'owner'] }`.
- Default role on creation is `'member'`.

### 5.2 Owner-Only Actions
These operations check `band.owned_by?(current_user)` and must continue to do so:
- Deleting a band
- Adding users to a band
- Removing other users from a band
- Changing membership roles
- Transferring ownership

### 5.3 Member Actions
- Any band member can edit band details and configure Google Calendar settings (checked via `@band.users.include?(current_user)`).

### 5.4 Last Owner Protection
- The system prevents removing or demoting the last owner. Always check `@band.owners.count <= 1` before changing an owner's role to member or removing them.

## 6. Band-Scoped Data Access

All data queries for band-specific resources must be scoped to the user's bands. The codebase uses several patterns:

### 6.1 `filter_by_current_band(Model)`
Use this helper for songs, gigs, and venues to restrict queries to the current band:
```ruby
@venues = filter_by_current_band(Venue).active.order(:name)
@gig = filter_by_current_band(Gig).find(params[:id])
```

### 6.2 `user_bands` for Band Lookups
Always look up bands through the user's membership, never from `Band.find`:
```ruby
@band = user_bands.find(params[:id])        # correct
@band = Band.find(params[:id])              # WRONG - allows access to any band
```

### 6.3 `find_user_gig` for Cross-Band Gig Access
When a user may access gigs across their bands (e.g., "all bands" view), use `find_user_gig(gig_id)` which restricts to the user's band IDs:
```ruby
user_band_ids = current_user.bands.pluck(:id)
Gig.joins(:band).where(bands: { id: user_band_ids }).find(gig_id)
```

### 6.4 Cross-Band Copy Operations
When copying venues or songs between bands, always verify the user has membership in both the source and target bands:
```ruby
target_band = current_user.bands.find(target_band_id)  # scoped to user
```

## 7. Input Validation Patterns

### 7.1 Model Validations
- All user-facing models use ActiveRecord validations (`presence`, `uniqueness`, `inclusion`, `format`).
- Usernames are unique (case-insensitive). Emails are validated with `URI::MailTo::EMAIL_REGEXP`.
- OAuth UIDs are unique per provider: `validates :oauth_uid, uniqueness: { scope: :oauth_provider }`.

### 7.2 Parameter Handling
- Band IDs in `select_band` are verified against the user's bands before being set in session.
- Pagination is capped: `per_page = [(params[:per_page] || 20).to_i, 50].min`.
- Song `band_ids` submitted via forms are filtered to bands the user actually belongs to:
```ruby
allowed_band_ids = current_user.bands.where(id: provided_band_ids).pluck(:id)
```

### 7.3 Error Messages
- Login failures use a generic message: `"Invalid username or password"`. Never reveal whether the username exists.
- OAuth errors are mapped to safe messages. Internal details are logged server-side only.
- Rescue blocks in routes return generic error messages to clients and log details only in development.

## 8. Account Lockout

The database schema includes lockout fields on the `users` table:
- `failed_attempts_count` (integer, default 0, not null)
- `last_failed_attempt_at` (timestamp)
- `locked_at` (timestamp)
- Indexed: `index_users_on_locked_at`, `index_users_on_username_and_locked_at`

The `login_attempts` table tracks login attempts with `ip_address`, `user_agent`, `username`, `successful`, and `attempted_at`. Note: `login_attempts` has no `user_id` foreign key; lookups are by `username`.

When implementing or extending lockout logic, use these existing columns. Check `locked_at` before authenticating and increment `failed_attempts_count` on failure.

## 9. Test-Mode Safety

- The `/test_auth` endpoint is gated with `if settings.test?`. Never add test-only authentication bypasses without this guard.
- Test mode disables Rack protection (`set :protection, false`). This is acceptable only in the test environment.

## 10. Sensitive Data Handling

- Never log full tokens or secrets. The OAuth debug logging truncates authorization codes in the callback route: `params[:code][0..15]...`, and truncates them in the service layer: `code[0..10]...`.
- Never commit `.env` files. The repository includes `env.example` as a template.
- Google service account credentials are stored in `GOOGLE_SERVICE_ACCOUNT_JSON` environment variable, not in files.
- OAuth client IDs and secrets are read from environment variables following the pattern `{PROVIDER}_CLIENT_ID` and `{PROVIDER}_CLIENT_SECRET`.
