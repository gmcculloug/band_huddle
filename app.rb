require 'dotenv/load'
require 'sinatra'
require 'sinatra/activerecord'
require 'json'
require 'erb'
require 'bcrypt'
require 'rack/method_override'
require 'connection_pool'

# Only require Redis gems when Valkey sessions are enabled
if ENV['VALKEY_ENABLED'] == 'true'
  require 'redis'
  require 'rack/session/redis'
  puts "🔗 Using Redis client for Valkey-compatible session storage"
end

# Load concerns
require_relative 'lib/concerns/archivable'

# Load models
require_relative 'lib/models/user'
require_relative 'lib/models/user_band'
require_relative 'lib/models/band'
require_relative 'lib/models/song_catalog'
require_relative 'lib/models/song'
require_relative 'lib/models/song_band'
require_relative 'lib/models/venue'
require_relative 'lib/models/gig'
require_relative 'lib/models/gig_song'
require_relative 'lib/models/blackout_date'
require_relative 'lib/models/google_calendar_event'
require_relative 'lib/models/practice'
require_relative 'lib/models/practice_availability'

# Load services
require_relative 'lib/services/google_calendar_service'
require_relative 'lib/services/error_handler'

# Load helpers
require_relative 'lib/helpers/icon_helpers'
require_relative 'lib/helpers/application_helpers'

# Load route modules
require_relative 'lib/routes/authentication'
require_relative 'lib/routes/oauth'
require_relative 'lib/routes/bands'
require_relative 'lib/routes/songs'
require_relative 'lib/routes/gigs'
require_relative 'lib/routes/venues'
require_relative 'lib/routes/calendar'
require_relative 'lib/routes/practices'
require_relative 'lib/routes/api'
require_relative 'lib/routes/mobile_api'
require_relative 'lib/routes/public_schedule'

enable :static
use Rack::MethodOverride

# Conditional session store configuration
if ENV['VALKEY_ENABLED'] == 'true'
  # Valkey session store configuration
  # Note: Connection pooling can be added later if needed using ConnectionPool

  # Session secret validation (keep existing production logic)
  if ENV['RACK_ENV'] == 'production' || ENV['APP_ENV'] == 'production'
    session_secret = ENV['SESSION_SECRET']
    if session_secret.nil? || session_secret.empty?
      puts "ERROR: SESSION_SECRET environment variable must be set in production"
      puts "Generate a strong secret with: openssl rand -hex 64"
      exit 1
    end
    if session_secret.length < 32
      puts "ERROR: SESSION_SECRET must be at least 32 characters long"
      puts "Current length: #{session_secret.length} characters"
      puts "Generate a strong secret with: openssl rand -hex 64"
      exit 1
    end
  else
    session_secret = ENV['SESSION_SECRET'] || 'development_secret_key_not_for_production_use'
  end

  use Rack::Session::Redis,
      redis_server: "redis://#{ENV['VALKEY_HOST'] || 'valkey'}:#{ENV['VALKEY_PORT'] || 6379}/#{ENV['VALKEY_DB'] || 0}",
      key: '_band_huddle_session',
      secret: session_secret

else
  # Use Sinatra's built-in cookie sessions (existing behavior)
  enable :sessions

  # Session secret configuration with production security requirements
  if ENV['RACK_ENV'] == 'production' || ENV['APP_ENV'] == 'production'
    # In production, SESSION_SECRET must be set and strong
    session_secret = ENV['SESSION_SECRET']

    if session_secret.nil? || session_secret.empty?
      puts "ERROR: SESSION_SECRET environment variable must be set in production"
      puts "Generate a strong secret with: openssl rand -hex 64"
      exit 1
    end

    if session_secret.length < 32
      puts "ERROR: SESSION_SECRET must be at least 32 characters long"
      puts "Current length: #{session_secret.length} characters"
      puts "Generate a strong secret with: openssl rand -hex 64"
      exit 1
    end

    set :session_secret, session_secret
  else
    # In development/test, allow fallback for convenience
    set :session_secret, ENV['SESSION_SECRET'] || 'development_secret_key_not_for_production_use'
  end
end

set :public_folder, File.dirname(__FILE__) + '/public'

# Include application helpers
helpers ApplicationHelpers

# Mount route modules
use Routes::Authentication
use Routes::OAuth
use Routes::Bands
use Routes::Songs
use Routes::Gigs
use Routes::Venues
use Routes::Calendar
use Routes::Practices
use Routes::Api
use Routes::MobileAPI
use Routes::PublicSchedule

# Account creation code for user registration (required)
# Set BAND_HUDDLE_ACCT_CREATION_SECRET environment variable to enable account creation

# Database configuration
configure :development do
  set :database, {
    adapter: 'postgresql',
    host: ENV['DATABASE_HOST'] || 'localhost',
    port: ENV['DATABASE_PORT'] || 5432,
    database: ENV['DATABASE_NAME'] || 'band_huddle_development',
    username: ENV['DATABASE_USERNAME'] || 'postgres',
    password: ENV['DATABASE_PASSWORD'] || ''
  }
end

configure :production do
  # Use DATABASE_URL if available (common on Heroku), otherwise use individual env vars
  if ENV['DATABASE_URL']
    set :database, ENV['DATABASE_URL']
  else
    set :database, {
      adapter: 'postgresql',
      host: ENV['DATABASE_HOST'] || 'localhost',
      port: ENV['DATABASE_PORT'] || 5432,
      database: ENV['DATABASE_NAME'] || 'band_huddle_production',
      username: ENV['DATABASE_USERNAME'] || 'postgres',
      password: ENV['DATABASE_PASSWORD'] || ''
    }
  end
end

configure :test do
  set :database, {
    adapter: 'postgresql',
    host: ENV['DATABASE_HOST'] || 'localhost',
    port: ENV['DATABASE_PORT'] || 5432,
    database: ENV['DATABASE_NAME'] || 'band_huddle_test',
    username: ENV['DATABASE_USERNAME'] || 'postgres',
    password: ENV['DATABASE_PASSWORD'] || ''
  }
  set :bind, '0.0.0.0'
  set :port, 4567
  set :protection, false
  set :dump_errors, false
  set :raise_errors, true
  set :show_exceptions, false
end

# ============================================================================
# ROUTES
# ============================================================================

# Test authentication route (only available in test mode)
post '/test_auth' do
  if settings.test?
    # Allow tests to set authentication state directly
    # Handle both direct params and nested params format
    auth_params = params[:params] || params

    @test_session = {}
    @test_session[:user_id] = auth_params[:user_id] if auth_params[:user_id]
    @test_session[:band_id] = auth_params[:band_id] if auth_params[:band_id]
    session[:user_id] = auth_params[:user_id] if auth_params[:user_id]
    session[:band_id] = auth_params[:band_id] if auth_params[:band_id]
    status 200
    body "Authentication set"
  else
    status 404
  end
end

# Health check endpoint for load balancers and monitoring
get '/health' do
  content_type :json
  { status: 'ok', timestamp: Time.now.iso8601 }.to_json
end

# Public documentation route
get '/legal' do
  @breadcrumbs = [
    { label: '', url: '/', icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px;"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"></path><polyline points="9,22 9,12 15,12 15,22"></polyline></svg>' },
    { label: 'Privacy Policy & Terms', url: nil, icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px;"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path><polyline points="14,2 14,8 20,8"></polyline><line x1="16" y1="13" x2="8" y2="13"></line><line x1="16" y1="17" x2="8" y2="17"></line><polyline points="10,9 9,9 8,9"></polyline></svg>' }
  ]
  erb :legal, layout: :layout
end

# Application root route
get '/' do
  if logged_in?
    # If user has no bands, redirect to create first band
    if user_bands.empty?
      redirect '/bands/new?first_band=true'
    else
      redirect '/gigs'
    end
  else
    redirect '/login'
  end
end

# Band selection route
post '/select_band' do
  require_login
  
  band = user_bands.find_by(id: params[:band_id])
  if band
    session[:band_id] = band.id
    # Save this as the user's preferred band
    current_user.update(last_selected_band_id: band.id)
    
    # Determine which section to redirect to based on current path
    current_path = params[:current_path] || params[:redirect_to] || '/gigs'

    # Use helper method to map current path to appropriate list view
    redirect_to = redirect_path_for_section(current_path)

    redirect redirect_to
  else
    status 404
  end
end

# Start the server
if __FILE__ == $0
  puts "🎸 Band Huddle is starting up..."
  puts ""
  puts "📡 Starting HTTP server on port 4567"

  # Get local IP address for external access
  require 'socket'
  local_ip = Socket.ip_address_list.find { |addr| addr.ipv4? && !addr.ipv4_loopback? }&.ip_address

  if local_ip
    puts "🌐 Your local IP address is: #{local_ip}"
    puts "   Internal access: http://#{local_ip}:4567"
  end
  puts ""

  set :port, 4567
  set :bind, '0.0.0.0'  # Bind to all interfaces
  Sinatra::Application.run!
end