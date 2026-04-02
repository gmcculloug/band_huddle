# Database Guidelines - Band Huddle

## Database Stack

- **Database**: PostgreSQL
- **ORM**: ActiveRecord (via `sinatra-activerecord` gem, not Rails)
- **Framework**: Sinatra (not Rails — this distinction affects migration tooling)

## Custom Migration System

This project uses a **custom migration runner** defined in `Rakefile`, not the standard Rails migration commands. Key differences:

- Create migrations: `rake db:create_migration NAME=add_foo_to_bars`
- Run migrations: `rake db:migrate` (custom implementation that manually loads and runs each file)
- Rollback: `rake db:rollback` (rolls back only the last migration)
- Status: `rake db:status`
- Reset: `rake db:reset_tables` (drops all tables via raw SQL, then migrates)

### Migration File Conventions

- Filename format: `YYYYMMDDHHMMSS_description.rb`
- Class name is the CamelCased version of the description (uses a custom `String#camelize`)
- Inherit from `ActiveRecord::Migration[7.0]` (the version the `db:create_migration` template generates; existing migrations in the codebase use `[7.0]`, `[8.0]`, or `[8.1]`)
- Use `def change` for reversible migrations; use `def up` / `def down` when `change` is insufficient
- Prefer guarding idempotency for indexes: `add_index :table, :col unless index_exists?(:table, :col)`

### Migration Template

```ruby
class AddFooToBars < ActiveRecord::Migration[7.0]
  def change
    add_column :bars, :foo, :string
    add_index :bars, :foo
  end
end
```

## Schema Conventions

### Primary Keys

- Standard tables use the default `bigint` auto-incrementing `id` column
- Join tables that act as pure many-to-many links use `id: false` (no surrogate key). Example: `songs_bands`
- Join tables that carry their own data or need an `id` (e.g., `user_bands`, `gig_songs`) keep the default `id`

### Foreign Keys

- Always declare foreign keys at the database level using `t.references ... foreign_key: true` or `add_foreign_key`
- For non-standard column names, specify the column explicitly: `add_foreign_key :practices, :users, column: :created_by_user_id` (see `practices.created_by_user_id`)
- All foreign keys visible in `db/schema.rb` at the bottom as `add_foreign_key` statements

### Timestamps

- Every table includes `created_at` and `updated_at` via `t.timestamps`
- Store all datetime/timestamp values in **UTC**. Convert to user timezone only at display time
- Prefer `Time.current` (not `Time.now`) for consistency with ActiveRecord timezone handling. Exception: `Time.now.to_i` is used for Unix timestamp arithmetic in OAuth token expiry checks, where timezone is irrelevant

### Null Constraints

- Required fields use `null: false` at the database level, in addition to model-level `validates :field, presence: true`
- Boolean columns always specify `null: false` with an explicit `default` value to avoid three-state logic

### Column Defaults

- Boolean columns: always provide `default: false` (or `default: true`) with `null: false`
- Status/state string columns: provide a default (e.g., `default: 'active'`, `default: 'member'`)

## Soft-Delete (Archivable) Pattern

Records are never hard-deleted for archivable entities. Instead, use the `Archivable` concern.

### Schema Requirements

Archivable tables require two columns:

```ruby
add_column :things, :archived, :boolean, default: false, null: false
add_column :things, :archived_at, :timestamp
add_index :things, :archived
add_index :things, :archived_at
```

### Model Integration

```ruby
class Thing < ActiveRecord::Base
  include Archivable
end
```

This provides:
- Scopes: `.active`, `.archived`
- Instance methods: `archive!`, `unarchive!`, `archived?`, `active?`
- `archive!` sets `archived: true` and `archived_at: Time.current`
- `unarchive!` sets `archived: false` and `archived_at: nil`

### Currently Archivable Models

- `Song`
- `SongCatalog`
- `Venue`

### Query Rules

- **Always** use `.active` scope when listing records for display (e.g., `Song.active.order(...)`)
- Provide a separate route/view for archived records (e.g., `GET /songs/archived`)
- Archive/unarchive via POST routes: `POST /things/:id/archive`, `POST /things/:id/unarchive`

## Join Tables

### `songs_bands` (no surrogate key)

The model class for this table is `SongBand` (in `lib/models/song_band.rb`):

```ruby
self.table_name = 'songs_bands'
self.primary_key = nil
```

- Uses composite uniqueness: `index [:song_id, :band_id], unique: true`
- Carries extra data: `practice_state` (boolean), `practice_state_updated_at` (timestamp)
- Updates use `update_all` on the WHERE clause since there is no `id`: `self.class.where(song_id: ..., band_id: ...).update_all(...)`

### `user_bands` (has surrogate key)

- Has `id` column (standard primary key)
- Carries `role` column (`'member'` or `'owner'`)
- Uniqueness enforced: `index [:user_id, :band_id], unique: true`

### `gig_songs` (has surrogate key)

- Has `id`, carries `position`, `set_number`, transition data
- Composite index on `[:gig_id, :set_number, :position]`

## Band-Scoped Queries

Most data in the application is scoped to a band. The `current_band` helper (from session) determines which band's data to show.

### Scoping Pattern by Model Type

**Direct band association** (has `band_id` column): use `.where(band: current_band)`
```ruby
# Gig, Venue, Practice
filter_by_current_band(Gig)  # => Gig.where(band: current_band)
```

**Indirect band association** (through join table): use `.joins(:bands).where(bands: { id: current_band.id })`
```ruby
# Song (through songs_bands)
filter_by_current_band(Song)  # => Song.joins(:bands).where(bands: { id: current_band.id })
```

### Security Rule

Always scope record lookups through the current band or user's bands to prevent unauthorized access:

```ruby
# CORRECT - scoped to current band
song = current_band.songs.find(params[:id])

# CORRECT - scoped to user's bands
user_band_ids = current_user.bands.pluck(:id)
Gig.joins(:band).where(bands: { id: user_band_ids }).find(gig_id)

# WRONG - unscoped lookup
song = Song.find(params[:id])
```

### Global Models (not band-scoped)

- `SongCatalog` — shared across all bands, any logged-in user can view/search
- `User` — not band-scoped
- `BlackoutDate` — scoped to user, not band

## Indexing Conventions

- Every foreign key column gets an individual index
- Composite indexes for common query patterns (e.g., `[:band_id, :performance_date]` on `gigs`)
- Unique indexes enforce business rules at the DB level (e.g., `[:user_id, :band_id]` on `user_bands`)
- Boolean filter columns get indexes (e.g., `archived`, `practice_state`, `google_calendar_enabled`)
- Text search columns used in WHERE clauses get indexes (e.g., `title`, `artist`, `name`)

## Timezone Handling

- All timestamps stored in **UTC** in the database
- Users have a `timezone` column (default: `'UTC'`) storing IANA timezone names (e.g., `'America/New_York'`)
- Convert to user timezone for display using `in_time_zone`:
  ```ruby
  utc_time = start_time.in_time_zone('UTC')
  utc_time.in_time_zone(user_timezone)
  ```
- Convert user input to UTC before saving:
  ```ruby
  parsed_time = Time.parse(time_str).in_time_zone(user_tz)
  self.start_time = parsed_time.utc
  ```
- Prefer `Time.current` and `Date.current` (not `Time.now` / `Date.today`) for timezone-aware comparisons. Exception: `Time.now.to_i` is acceptable for Unix epoch arithmetic (e.g., OAuth token expiry)

## Model Scope Conventions

- Name scopes descriptively: `scope :active`, `scope :upcoming`, `scope :for_band`, `scope :for_date_range`
- Use lambda syntax: `scope :by_band, ->(band) { ... }`
- Case-insensitive text search uses `LOWER()`: `where('LOWER(title) LIKE ?', "%#{query.downcase}%")`
- Date range queries use Ruby range syntax: `where(performance_date: start_date..end_date)`

## Model Associations

- Use `dependent: :destroy` on has_many associations where child records should be cleaned up
- Use `optional: true` on belongs_to when the foreign key is nullable
- Use `class_name` and `foreign_key` for non-conventional names:
  ```ruby
  belongs_to :created_by_user, class_name: 'User'
  belongs_to :last_selected_band, class_name: 'Band', optional: true
  has_many :created_practices, class_name: 'Practice', foreign_key: 'created_by_user_id'
  ```
- Scoped associations use inline lambdas:
  ```ruby
  has_many :owner_user_bands, -> { where(role: 'owner') }, class_name: 'UserBand'
  has_many :owners, through: :owner_user_bands, source: :user
  ```

## Validation Conventions

- Presence validations on required fields match `null: false` in the schema
- Uniqueness validations with `scope:` match composite unique indexes
- Inclusion validations for status/role fields: `inclusion: { in: %w[active finalized cancelled] }`
- Numeric validations where appropriate: `numericality: { greater_than: 0 }`
- Email format: `format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true`
