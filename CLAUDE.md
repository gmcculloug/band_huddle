# CLAUDE.md

@AGENTS.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Development Commands

### Database Management
- **Setup database**: `rake db:setup` (runs migrations + seeds)
- **Create PostgreSQL database**: `createdb band_huddle_development` and `createdb band_huddle_test`
- **Create migration**: `rake db:create_migration NAME=migration_name`
- **Run migrations**: `rake db:migrate`
- **Check migration status**: `rake db:status`
- **Rollback last migration**: `rake db:rollback`
- **Reset database**: `rake db:reset` (drops all tables, re-runs migrations)
- **Seed database**: `rake db:seed`

### Testing
- **Run all tests**: `rake spec` or `rspec`
- **Run specific test file**: `rspec spec/models/band_spec.rb`
- **Run tests with coverage**: `rake test:coverage`
- **Run tests with HTML output**: `rake test:html`

### Application
- **Start development server**: `ruby app.rb` (runs on http://localhost:4567)
- **Install dependencies**: `bundle install`

### Docker Commands
- **Start with Docker Compose**: `docker-compose up -d` (includes PostgreSQL)
- **Stop Docker services**: `docker-compose down`
- **View logs**: `docker-compose logs -f band-huddle`
- **Run migrations in Docker**: `docker-compose exec band-huddle bundle exec rake db:migrate`
- **Access PostgreSQL in Docker**: `docker-compose exec postgres psql -U band-huddle -d band-huddle_production`

## Architecture Overview

### Application Structure
- **Single-file Sinatra app**: All models, routes, and configuration in `app.rb`
- **ERB templates**: Located in `views/` directory
- **PostgreSQL database**: Uses ActiveRecord ORM with custom migration system
- **Test suite**: RSpec with FactoryBot, Capybara for integration tests

### Core Models and Relationships
- **Band**: Has many songs (many-to-many), has many set lists
- **Song**: Belongs to many bands, appears in set lists through join table
- **SetList**: Belongs to band and venue, has many songs through SetListSong
- **Venue**: Has many set lists
- **SetListSong**: Join table with position ordering for songs in set lists

### Database Configuration
- Development: `band-huddle_development` PostgreSQL database
- Test: `band-huddle_test` PostgreSQL database
- Production: Uses `DATABASE_URL` environment variable or individual PostgreSQL connection env vars
- Environment variables: `DATABASE_HOST`, `DATABASE_PORT`, `DATABASE_NAME`, `DATABASE_USERNAME`, `DATABASE_PASSWORD`

### Security Configuration
**CRITICAL**: The application requires proper security configuration for production deployment.

#### Session Security
- **SESSION_SECRET**: **REQUIRED** in production environments
- Must be at least 32 characters long for security
- Generate with: `openssl rand -hex 64`
- Application will fail to start in production if not set or too short
- Development/test environments have fallback values for convenience

#### Environment Variables
- `SESSION_SECRET`: Strong session encryption key (production requirement)
- `BAND_HUDDLE_ACCT_CREATION_SECRET`: Controls user registration access

### Custom Migration System
This project implements a custom migration system (not Rails migrations):
- Migrations in `db/migrate/` with timestamp_name.rb format
- Custom rake tasks handle migration state tracking
- Always use `rake db:create_migration` to generate new migrations
- Migration classes must inherit from `ActiveRecord::Migration[7.0]`

### Testing Setup
- Tests clear all data before each spec
- FactoryBot provides test data factories
- Capybara configured for integration testing
- Database cleaner ensures test isolation

### Key Features
- Band management with song libraries
- Set list creation and organization
- Venue tracking with contact information
- Mobile-responsive design
- Print-friendly set list views
- Performance scheduling

## Development Guidelines

### Database Changes
- Always create migrations for schema changes: `rake db:create_migration NAME=descriptive_name`
- Never modify database directly
- Test migrations on copy of production data before applying

### Testing
- All models have comprehensive specs in `spec/models/`
- Request specs cover all routes in `spec/requests/`
- Use factories for test data creation
- Clean database state between tests

### Timezone Handling
**CRITICAL ARCHITECTURAL DECISION**: This application implements proper timezone handling for all time-based data.

**Core Principle**: Always store times in UTC in the database and display in the user's timezone.

#### Implementation Rules:
1. **Database Storage**: All timestamp columns must store times in UTC
   - Use `timestamp` or `datetime` column types (never `time` for user-facing times)
   - Convert user input to UTC before saving to database
   - Example: `parsed_time.utc` when storing

2. **User Display**: Always convert stored UTC times to user's timezone for display
   - Use `timezone_aware_start_time(user_timezone)` methods in models
   - Pass user timezone to formatting methods: `formatted_time_range(current_user.user_timezone)`
   - Handle invalid timezones gracefully with UTC fallback

3. **User Timezone Storage**:
   - Users table has `timezone` column (defaults to 'UTC')
   - Validate timezone against `ActiveSupport::TimeZone.all.map(&:name)`
   - Use `user.user_timezone` helper method

4. **Model Methods**: Create timezone-aware methods for time display
   ```ruby
   def timezone_aware_start_time(user_timezone = nil)
     user_tz = user_timezone || 'UTC'
     start_time.in_time_zone('UTC').in_time_zone(user_tz)
   end
   ```

5. **Route Processing**: Parse user input in their timezone, store as UTC
   ```ruby
   parsed_time = Time.parse(params[:time]).in_time_zone(user_timezone)
   model.time_field = parsed_time.utc
   ```

6. **View Updates**: Always pass user timezone to time display methods
   ```erb
   <%= practice.formatted_time_range(current_user.user_timezone) %>
   ```

#### Why This Matters:
- Ensures consistent time storage across all users regardless of location
- Prevents timezone-related bugs and data corruption
- Enables proper scheduling for distributed teams
- Maintains data integrity when users change timezones

#### Examples:
- Practice scheduling times are stored in UTC, displayed in user's local time
- All datetime comparisons work correctly regardless of user timezone
- Users see times in their familiar local format

**Remember**: When adding any time-related features, follow this pattern without exception.

### Adding New Features
1. Create migration if database changes needed
2. Update models with validations and associations
3. Add routes and views
4. Write comprehensive tests
5. Ensure mobile responsiveness
6. **If time-related**: Follow timezone handling rules above