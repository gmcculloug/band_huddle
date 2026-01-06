ENV['RACK_ENV'] = 'test'

require 'rspec'
require 'rack/test'
require 'capybara/rspec'
require 'factory_bot'
require 'faker'
require 'timecop'
require_relative '../app'

# Load factories
require_relative 'factories'

# Time helpers for consistent date testing
module TimeHelpers
  # Freeze time to a consistent date for reliable testing
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def freeze_time_for_testing
      let(:frozen_date) { Date.new(2024, 6, 15) } # Saturday, June 15th, 2024
      let(:frozen_time) { Time.new(2024, 6, 15, 12, 0, 0) } # Noon on the frozen date
      let(:tomorrow) { frozen_date + 1.day }
      let(:yesterday) { frozen_date - 1.day }
      let(:next_week) { frozen_date + 7.days }
      let(:last_week) { frozen_date - 7.days }
      let(:next_month) { frozen_date + 1.month }
      let(:last_month) { frozen_date - 1.month }
      let(:last_christmas) { Date.new(frozen_date.year - 1, 12, 25) }
      let(:next_christmas) { Date.new(frozen_date.year, 12, 25) }

      before do
        Timecop.freeze(frozen_time)
      end
    end
  end
end


RSpec.configure do |config|
  config.include Rack::Test::Methods
  config.include Capybara::DSL
  config.include FactoryBot::Syntax::Methods

  def app
    Sinatra::Application
  end

  def login_as(user, band = nil)
    # For testing, we'll use the test auth route
    # This bypasses the normal authentication flow
    if band
      # Ensure user is a member of the band
      user.bands << band unless user.bands.include?(band)
    end
    
    # Use the test auth route to set the session
    post '/test_auth', user_id: user.id, band_id: band&.id
  end

  config.before(:each) do
    # Clear in proper order to respect foreign key constraints
    # Only clear tables that exist
    begin
      GoogleCalendarEvent.delete_all
    rescue ActiveRecord::StatementInvalid
      # Table doesn't exist in test DB, skip
    end

    begin
      PracticeAvailability.delete_all
      Practice.delete_all
    rescue ActiveRecord::StatementInvalid
      # Practice tables don't exist in test DB, skip
    end
    begin
      GigSong.delete_all
      Gig.delete_all
    rescue ActiveRecord::StatementInvalid
      # Gig tables don't exist in test DB, skip
    end
    begin
      UserBand.delete_all
    rescue ActiveRecord::StatementInvalid
      # UserBand table doesn't exist in test DB, skip
    end
    # Clear blackout dates before users
    begin
      BlackoutDate.delete_all
    rescue ActiveRecord::StatementInvalid
      # BlackoutDate table doesn't exist in test DB, skip
    end
    # Clear many-to-many relationships first
    begin
      ActiveRecord::Base.connection.execute("DELETE FROM songs_bands")
    rescue ActiveRecord::StatementInvalid
      # songs_bands table doesn't exist in test DB, skip
    end
    begin
      Song.delete_all
      Venue.delete_all
    rescue ActiveRecord::StatementInvalid
      # Song/Venue tables don't exist in test DB, skip
    end
    # Clear user's last_selected_band_id reference before deleting bands
    begin
      User.update_all(last_selected_band_id: nil)
      Band.delete_all
      User.delete_all
    rescue ActiveRecord::StatementInvalid
      # User/Band tables don't exist in test DB, skip
    end
    begin
      SongCatalog.delete_all
    rescue ActiveRecord::StatementInvalid
      # SongCatalog table doesn't exist in test DB, skip
    end
  end

  config.after(:each) do
    # Reset time after each test to prevent test contamination
    Timecop.return
  end
end

Capybara.app = Sinatra::Application
Capybara.default_driver = :rack_test
Capybara.javascript_driver = :selenium_chrome_headless

class String
  def camelize
    self.split('_').map(&:capitalize).join
  end
end 