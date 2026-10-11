require 'sinatra/activerecord/rake'
require 'rake'

# Load the application
require_relative 'app'

# RSpec tasks
begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec)
  RSpec::Core::RakeTask.new(:test) do |t|
    t.pattern = 'spec/**/*_spec.rb'
  end
rescue LoadError
  puts "RSpec not available. Install with: bundle install"
end

# sinatra-activerecord (via active_record/railties/databases.rake) defines its
# own db:create_migration and db:rollback tasks. Rake does not replace a task
# when it is redeclared — it appends a second action, so both versions would
# run (creating duplicate migration files and rolling back two migrations per
# invocation). Clear the gem-defined tasks so only the versions below run.
# db:migrate is intentionally NOT redeclared here: ActiveRecord's built-in
# migrator (loaded via the require above) runs migrations and auto-dumps
# db/schema.rb, which keeps the schema dump in sync after every migrate.
%w[create_migration rollback].each do |task_name|
  Rake::Task["db:#{task_name}"].clear if Rake::Task.task_defined?("db:#{task_name}")
end

namespace :db do
  desc "Create a new migration"
  task :create_migration => :environment do
    name = ENV['NAME']
    if name.nil?
      puts "Usage: rake db:create_migration NAME=name_of_migration"
      puts "Example: rake db:create_migration NAME=add_user_preferences"
      exit 1
    end
    
    timestamp = Time.now.strftime("%Y%m%d%H%M%S")
    filename = "#{timestamp}_#{name}.rb"
    filepath = File.join("db", "migrate", filename)
    
    # Create migrations directory if it doesn't exist
    FileUtils.mkdir_p(File.dirname(filepath))
    
    # Create migration file
    File.open(filepath, 'w') do |f|
      f.write <<~MIGRATION
        class #{name.camelize} < ActiveRecord::Migration[7.0]
          def change
            # Add your migration code here
          end
        end
      MIGRATION
    end
    
    puts "Created migration: #{filepath}"
  end

  desc "Rollback the last migration"
  task :rollback => :environment do
    # Get the last applied migration
    last_version = ActiveRecord::Base.connection.select_value("SELECT version FROM schema_migrations ORDER BY version DESC LIMIT 1")
    
    if last_version.nil?
      puts "No migrations to rollback."
      return
    end
    
    # Find the migration file
    migration_file = Dir.glob(File.join("db", "migrate", "#{last_version}_*.rb")).first
    
    if migration_file.nil?
      puts "Migration file not found for version #{last_version}"
      return
    end
    
    migration_name = File.basename(migration_file, '.rb').split('_', 2).last.camelize
    
    puts "Rolling back migration #{last_version}: #{migration_name}"
    
    # Load and run the migration down.
    # Use migrate(:down) rather than down: Migration#down is a no-op for
    # migrations that only define `change`; migrate(:down) runs the recorded
    # inverse via revert.
    load migration_file
    migration_class = Object.const_get(migration_name)
    migration = migration_class.new
    migration.migrate(:down)
    
    # Remove the migration record
    ActiveRecord::Base.connection.execute("DELETE FROM schema_migrations WHERE version = '#{last_version}'")
    
    puts "Rollback completed!"
  end

  desc "Show migration status"
  task :status => :environment do
    # Create schema_migrations table if it doesn't exist
    unless ActiveRecord::Base.connection.table_exists?('schema_migrations')
      ActiveRecord::Base.connection.create_table :schema_migrations do |t|
        t.string :version, null: false
      end
      ActiveRecord::Base.connection.add_index :schema_migrations, :version, unique: true
    end
    
    migration_files = Dir.glob(File.join("db", "migrate", "*.rb")).sort
    applied_versions = ActiveRecord::Base.connection.select_values("SELECT version FROM schema_migrations")
    
    puts "Database: #{ActiveRecord::Base.connection_db_config.configuration_hash[:database]}"
    puts "Status   Migration ID    Migration Name"
    puts "--------------------------------------------------"
    
    migration_files.each do |file|
      version = File.basename(file).split('_').first
      migration_name = File.basename(file, '.rb').split('_', 2).last.camelize
      status = applied_versions.include?(version) ? "up" : "down"
      puts "#{status.ljust(7)} #{version.ljust(14)} #{migration_name}"
    end
  end

  desc "Reset database tables (drop tables, migrate)"
  task :reset_tables => :environment do
    puts "Dropping all tables..."
    
    # Drop all foreign keys first
    ActiveRecord::Base.connection.execute(<<~SQL)
      DO $$ DECLARE
        r RECORD;
      BEGIN
        FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = current_schema()) LOOP
          EXECUTE 'DROP TABLE IF EXISTS ' || quote_ident(r.tablename) || ' CASCADE';
        END LOOP;
      END $$;
    SQL
    
    puts "Running migrations..."
    Rake::Task['db:migrate'].invoke
    
    puts "Database reset completed!"
  end

  desc "Setup database (migrate + seed)"
  task :setup => :environment do
    puts "Running migrations..."
    Rake::Task['db:migrate'].invoke

    puts "Seeding database..."
    Rake::Task['db:seed'].invoke

    puts "Database setup completed!"
  end

  desc "Seed only songs from the song catalog"
  task :seed_songs => :environment do
    puts "Seeding song catalog..."

    # Load only the song catalog data from seeds.rb
    load File.join(File.dirname(__FILE__), 'db', 'seed_songs.rb')

    puts "Song catalog seeding completed!"
  end
end

# Test tasks
namespace :test do
  desc "Run all tests"
  task :all => [:spec]
  
  desc "Run tests with coverage"
  task :coverage => :environment do
    ENV['COVERAGE'] = 'true'
    Rake::Task[:spec].invoke
  end
  
  desc "Run tests and generate HTML report"
  task :html => :environment do
    ENV['RSPEC_FORMAT'] = 'html'
    Rake::Task[:spec].invoke
  end
end

# Default task
task :default => [:test]

# Helper method for camelizing strings
class String
  def camelize
    self.split('_').map(&:capitalize).join
  end
end 