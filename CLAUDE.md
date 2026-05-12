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

### Adding New Features
1. Create migration if database changes needed
2. Update models with validations and associations
3. Add routes and views
4. Write comprehensive tests
5. Ensure mobile responsiveness
6. **If time-related**: Follow timezone handling rules above