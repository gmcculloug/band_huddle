# Testing Guidelines for Band Huddle

## Running Tests

```bash
# Run all specs
bundle exec rspec

# Run via Rake
bundle exec rake spec
# or
bundle exec rake test

# Run with coverage
bundle exec rake test:coverage
```

## Spec Organization

| Directory | Purpose | RSpec `type` |
|---|---|---|
| `spec/models/` | ActiveRecord validations, associations, scopes | `:model` |
| `spec/requests/` | Sinatra route behavior (GET/POST/PUT/DELETE) | `:request` |
| `spec/services/` | Service objects (e.g., `GoogleCalendarService`) | (none) |
| `spec/helpers/` | Helper module methods | `:helper` (optional; not all helper specs use it) |

All spec files must `require 'spec_helper'` (or `require_relative '../spec_helper'` from subdirectories). There is no `rails_helper`; this is a Sinatra app.

## RSpec Configuration

- `Rack::Test::Methods`, `Capybara::DSL`, and `FactoryBot::Syntax::Methods` are globally included via `spec_helper.rb`. Do not re-include them in individual specs.
- The `app` method returns `Sinatra::Application`. Do not override it.
- Capybara uses `:rack_test` as the default driver and `:selenium_chrome_headless` for JavaScript tests.

## Authentication in Request Specs

Use the `login_as` helper defined in `spec_helper.rb`:

```ruby
login_as(user, band)   # Sets session with both user and band context
login_as(user)         # Sets session with user only (no band selected)
```

This helper calls `POST /test_auth`, a route that only exists in the test environment. It sets the session state directly, bypassing OAuth/password authentication.

**Important:** Some spec files (e.g., `blackout_dates_spec.rb`, `venues_spec.rb`, `calendar_spec.rb`) redefine `login_as` locally. When writing new specs, rely on the global `login_as` from `spec_helper.rb` and do NOT redefine it unless there is a specific need.

For specs that need to test without the helper (e.g., testing authentication itself), call `/test_auth` directly or use the real login flow:

```ruby
post '/login', username: 'testuser', password: 'pass'
```

## FactoryBot Usage

All factories are defined in a single file: `spec/factories.rb`.

### Key Conventions

1. **Use `create` for integration/request specs** and `build` for model validation specs that do not need persistence.
2. **The `:band` factory automatically creates an owner `UserBand` record** in its `after(:create)` callback. You do not need to manually create `UserBand` for the band owner.
3. **To add a non-owner member to a band**, explicitly create the join record:
   ```ruby
   create(:user_band, user: user, band: band, role: 'member')
   # or
   band.users << user
   ```
4. **Use sequences** for unique fields (`sequence(:name)`, `sequence(:username)`). Do not hardcode values that must be unique unless the test specifically checks uniqueness.
5. **Use `Faker`** for realistic but non-critical data (emails, addresses, paragraphs). Use explicit values for data the test asserts on.
6. **Use traits** on `:user_band` for role variants:
   ```ruby
   create(:user_band, :owner, user: user, band: band)
   create(:user_band, :member, user: user, band: band)
   ```
7. **Songs are associated to bands via a many-to-many join table** (`songs_bands`). Pass `bands: [band]` when creating:
   ```ruby
   create(:song, bands: [band])
   ```

## Database Teardown

The project uses manual `delete_all` in a `before(:each)` block instead of `database_cleaner`. Records are deleted in a specific order to respect foreign key constraints:

1. `GoogleCalendarEvent`
2. `PracticeAvailability`, `Practice`
3. `GigSong`, `Gig`
4. `UserBand`
5. `BlackoutDate`
6. `songs_bands` (raw SQL: `DELETE FROM songs_bands`)
7. `Song`, `Venue`
8. `User.update_all(last_selected_band_id: nil)` — clears FK before deleting bands
9. `Band`, `User`
10. `SongCatalog`

Each block is wrapped in `rescue ActiveRecord::StatementInvalid` to handle tables that may not exist. When adding new models with foreign keys, add their teardown to `spec_helper.rb` in the correct position.

## TimeHelpers and Timecop

The `TimeHelpers` module in `spec_helper.rb` provides a `freeze_time_for_testing` class method. Include and call it in describe blocks that need deterministic dates:

```ruby
RSpec.describe 'Blackout Dates API', type: :request do
  include TimeHelpers
  freeze_time_for_testing

  it 'uses frozen dates' do
    # frozen_date => Date.new(2024, 6, 15) (Saturday)
    # frozen_time => Time.new(2024, 6, 15, 12, 0, 0)
    # Also available: tomorrow, yesterday, next_week, last_week,
    #                 next_month, last_month, last_christmas, next_christmas
    post '/blackout_dates', date: tomorrow.to_s
  end
end
```

- `Timecop.return` is called in a global `after(:each)` hook, so you never need to clean up manually.
- Use `freeze_time_for_testing` any time your test depends on `Date.current`, `Time.now`, or relative date calculations.
- Set factory `timezone` to `"UTC"` (already the default in the `:user` factory) for predictable behavior.

## Request Spec Patterns

### Asserting Responses

Use `Rack::Test` methods (`get`, `post`, `put`, `delete`) and `last_response`:

```ruby
get '/gigs'
expect(last_response).to be_ok                          # 200
expect(last_response.body).to include('Gig Name')

post '/gigs', name: 'New Gig', band_id: band.id, performance_date: '2024-12-25'
expect(last_response).to be_redirect                    # 3xx
follow_redirect!
expect(last_response.body).to include('New Gig')

expect(last_response.location).to end_with('/gigs')     # redirect target
```

### JSON API Responses

```ruby
post "/gigs/#{gig.id}/reorder", song_order: [s3.id, s1.id, s2.id]
expect(last_response).to be_ok
expect(last_response.content_type).to include('application/json')
response_data = JSON.parse(last_response.body)
expect(response_data['success']).to be true
```

### Testing Record Not Found

The app raises `ActiveRecord::RecordNotFound` for missing or unauthorized resources:

```ruby
expect { get '/gigs/999' }.to raise_error(ActiveRecord::RecordNotFound)
```

### Testing Record Count Changes

```ruby
expect { post '/gigs', gig_params }.to change(Gig, :count).by(1)
expect { delete "/gigs/#{gig.id}" }.to change(Gig, :count).by(-1)
expect { post '/gigs', invalid_params }.not_to change(Gig, :count)
```

### Testing Ordering in HTML

Assert element order by comparing string index positions:

```ruby
body = last_response.body
expect(body.index('A Band')).to be < body.index('B Band')
```

## Model Spec Patterns

- Test validations with `build` (not `create`) for invalid records.
- Test associations by creating related records and checking the collection.
- Test destruction by cleaning up dependent records first (foreign key constraints prevent cascade in this app).

```ruby
it 'is invalid without a name' do
  band = build(:band, name: nil)
  expect(band).not_to be_valid
  expect(band.errors[:name]).to include("can't be blank")
end
```

## Service Spec Patterns

Use `instance_double` and `allow/expect` for external API dependencies:

```ruby
let(:mock_service) { instance_double(Google::Apis::CalendarV3::CalendarService) }
before do
  allow(Google::Apis::CalendarV3::CalendarService).to receive(:new).and_return(mock_service)
end
```

Test private methods via `send`:

```ruby
result = service.send(:find_existing_event, gig)
```

## Helper Spec Patterns

For helpers that are modules, include them in the test context:

```ruby
before { self.extend(ApplicationHelpers) }
```

Or instantiate a class that includes the module:

```ruby
let(:test_class) { Class.new { include IconHelpers } }
let(:helper) { test_class.new }
```

## Shared Contexts

Use `shared_context` for reusable setup (see `practices_spec.rb`):

```ruby
shared_context 'logged in user' do
  before do
    band.users << user
    login_as(user, band)
  end
end

# Usage:
context 'when logged in' do
  include_context 'logged in user'
  it 'returns success' do
    get '/practices'
    expect(last_response).to be_ok
  end
end
```

## Cross-Band Access Testing

When testing multi-band authorization, verify:
1. User can access resources from any band they belong to (not just the "current" band).
2. User cannot access resources from bands they are not a member of (expect `RecordNotFound`).
3. Related queries (songs, venues) use the resource's band context, not the session's current band.

## ENV Variables in Tests

Set and clean up environment variables with `before`/`after` blocks:

```ruby
before { ENV['BAND_HUDDLE_ACCT_CREATION_SECRET'] = 'open' }
after  { ENV.delete('BAND_HUDDLE_ACCT_CREATION_SECRET') }
```
