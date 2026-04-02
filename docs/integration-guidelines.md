# Integration Guidelines

Rules and conventions for building and maintaining external service integrations in band_huddle.

## 1. Service Class Structure

Place integration service classes in `lib/services/` and name them `<provider>_<resource>_service.rb`.

- Accept the parent domain model (e.g., `band`) in the constructor.
- Initialize the external API client and authorize in `#initialize`.
- Keep all API interaction inside the service class; models and routes must never call external APIs directly.

```ruby
class GoogleCalendarService
  def initialize(band)
    @band = band
    @service = Google::Apis::CalendarV3::CalendarService.new
    @service.authorization = authorize
  end
end
```

## 2. Credential Management

- Store external service credentials as a single JSON blob in an environment variable (e.g., `GOOGLE_SERVICE_ACCOUNT_JSON`).
- Parse credentials from `ENV` inside a private `authorize` method using `StringIO.new(ENV['...'] || '{}')`.
- Never read credential files from disk; always use env vars so the same code works in dev, CI, and production.
- Document the required env var in `env.example` with a placeholder JSON structure.
- Use Google service account credentials via `Google::Auth::ServiceAccountCredentials.make_creds` with the appropriate scope constant.

## 3. Feature Gating

Every public method in an integration service must guard on two conditions before doing work:

1. The feature is enabled on the parent model (`@band.google_calendar_enabled?`).
2. The required configuration is present (`@band.google_calendar_id.present?`).

Return `false` or an error hash immediately when either check fails. The parent model must also validate that configuration fields are present when the feature flag is on:

```ruby
validates :google_calendar_id, presence: true, if: :google_calendar_enabled?
```

## 4. Sync State Tracking Table

Create a join table to track the mapping between local records and remote resource IDs.

Required columns:
- `band_id` (foreign key, not null)
- `gig_id` (foreign key, not null) — or the equivalent local resource
- `google_event_id` (string, not null) — the remote resource ID
- `last_synced_at` (datetime)

Required indexes:
- Unique composite index on `[band_id, google_event_id]` to prevent duplicates.
- Individual indexes on `band_id`, `gig_id`, `google_event_id`, and `last_synced_at`.

The model must validate presence and uniqueness:

```ruby
validates :google_event_id, presence: true, uniqueness: { scope: :band_id }
```

Add useful scopes: `recently_synced`, `needs_sync`, `for_band`, `for_gig`.

## 5. Bidirectional Sync Pattern (Create / Update / Delete)

### 5a. Create or Update (sync)

1. Look up the tracking record to find an existing remote resource.
2. If found, fetch the remote resource to confirm it still exists; if the fetch fails, destroy the stale tracking record and treat as a new create.
3. If no tracking record exists, call the external create API and persist a new tracking record with `last_synced_at: Time.current`.
4. If a tracking record exists and the remote resource is live, call the external update API and update `last_synced_at`.

### 5b. Delete

1. Look up the tracking record.
2. If found, call the external delete API, then `destroy_all` matching tracking records.
3. If no tracking record exists, return success (idempotent).

### 5c. Bulk Sync

Iterate over all local records with `find_each`. Accumulate `synced_count`, `total_count`, and `errors`. Return a result hash:

```ruby
{ success: synced_count == total_count, synced_count:, total_count:, errors: }
```

## 6. Model Delegation

The parent model (e.g., `Band`) must provide convenience methods that delegate to the service, memoizing the service instance:

```ruby
def google_calendar_service
  @google_calendar_service ||= GoogleCalendarService.new(self)
end

def sync_gig_to_google_calendar(gig)
  return false unless google_calendar_enabled?
  google_calendar_service.sync_gig_to_calendar(gig)
end
```

Routes call these model methods, never the service directly.

## 7. Route Integration Points

Trigger sync operations at the relevant CRUD boundaries in route files:

- **POST (create)**: After a successful `save`, call `current_band.sync_gig_to_google_calendar(gig)`.
- **PUT/PATCH (update)**: After a successful `update`, call `@gig.band.sync_gig_to_google_calendar(@gig)`.
- **DELETE**: Before `destroy`, call `gig.band.remove_gig_from_google_calendar(gig)`.

Always guard with `if band.google_calendar_enabled?` at the call site as well.

Provide dedicated routes for integration management:

| Route | Purpose |
|-------|---------|
| `POST /bands/:id/google_calendar_settings` | Save enable flag and calendar ID |
| `POST /bands/:id/test_google_calendar` | Test connection, return JSON |
| `POST /bands/:id/sync_google_calendar` | Bulk-sync all gigs, return JSON |

All three routes set `content_type :json`. Response shapes differ by route:

- The **test** route returns `{ success: true, calendar_name: ... }` on success and `{ success: false, error: ... }` on failure.
- The **sync** route returns the full bulk-sync result hash: `{ success:, synced_count:, total_count:, errors: }`.
- Both routes return `{ success: false, error: ... }` for precondition failures (not enabled, not a member, etc.).

## 8. Error Handling

- Wrap every external API call in a `begin/rescue => e` block.
- On failure, return `false` (single-record ops) or append to an errors array (bulk ops). Never raise to the caller.
- In `find_existing_event`-style lookups, rescue fetch failures silently, destroy the stale tracking record, and return `nil`.
- For user-facing route errors, rescue at the route level and return a JSON error hash: `{ success: false, error: e.message }`.
- Use `ErrorHandler.log_and_respond` for logging with context when appropriate.

## 9. Testing Integrations

### 9a. Mock the External Client in `before` Blocks

Mock the API client class to return an `instance_double`, and stub the authorization setter and credential creation:

```ruby
let(:mock_calendar_service) { instance_double(Google::Apis::CalendarV3::CalendarService) }

before do
  allow(Google::Apis::CalendarV3::CalendarService).to receive(:new).and_return(mock_calendar_service)
  allow(mock_calendar_service).to receive(:authorization=)
  allow(Google::Auth::ServiceAccountCredentials).to receive(:make_creds).and_return(double('credentials'))
end
```

### 9b. Test the Full Matrix

For each public method, test these contexts:
- Feature disabled (returns `false` / error hash).
- Configuration missing (returns `false` / error hash).
- Happy path — new resource (create).
- Happy path — existing resource (update).
- API error (returns `false`, does not raise).
- Stale tracking record (remote deleted, local record cleaned up).

### 9c. Factory

Define a factory for the tracking model with sensible defaults:

```ruby
factory :google_calendar_event do
  sequence(:google_event_id) { |n| "google_event_#{n}" }
  last_synced_at { Time.current }
  association :band
  association :gig
end
```

### 9d. Database Cleanup

Add the tracking model to the `spec_helper.rb` cleanup order, before the parent models, respecting foreign keys:

```ruby
GoogleCalendarEvent.delete_all  # before Band.delete_all and Gig.delete_all
```

## 10. Adding a New Integration

Follow this checklist when adding a new external service (e.g., Spotify, Slack):

1. Add the client gem to `Gemfile` (e.g., `gem 'google-apis-calendar_v3'`).
2. Add the credential env var to `env.example` with a placeholder.
3. Create a migration for the tracking table with the columns from Section 4.
4. Create the tracking model in `lib/models/` with validations and scopes.
5. Create the service class in `lib/services/` following the constructor and method patterns in Sections 1–5.
6. Add enable flag and config columns to the parent model's table (e.g., `enabled` boolean, config string).
7. Add delegation methods to the parent model (Section 6).
8. Wire sync calls into the relevant CRUD routes (Section 7).
9. Add management routes for settings, testing, and bulk sync.
10. Require the new model and service in `app.rb` alongside the existing requires.
11. Write specs covering the full test matrix (Section 9b).
12. Add a setup guide in `docs/` or a top-level markdown file (see `GOOGLE_CALENDAR_SETUP.md`).

## 11. Gem Conventions

- Use official Google API gems (`google-apis-calendar_v3`, `googleauth`) rather than hand-rolling HTTP calls.
- Use `google-apis-*` gems for Google services and `omniauth-*` gems for OAuth providers.
- Pin gems to minor versions in `Gemfile` only when necessary; otherwise let Bundler resolve.

## 12. Event Payload Construction

When building payloads for external APIs:

- Construct the payload in a private `build_*` method (e.g., `build_event_from_gig`).
- Handle nil and edge-case values defensively (nil times default to midnight, end times before start times roll to next day).
- Include all relevant associated data (venue location, notes) in the payload.
- Use `Time.parse` with rescue fallbacks for user-supplied time strings; log warnings on parse failures.
