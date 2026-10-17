require 'net/http'
require 'json'
require 'uri'
require 'securerandom'
require 'openssl'
require 'jwt' # For Apple OAuth JWT authentication

class OauthService
  # OAuth provider configurations
  PROVIDERS = {
    'google' => {
      auth_url: 'https://accounts.google.com/o/oauth2/v2/auth',
      token_url: 'https://oauth2.googleapis.com/token',
      user_info_url: 'https://www.googleapis.com/oauth2/v2/userinfo',
      scope: 'openid email profile'
    },
    'github' => {
      auth_url: 'https://github.com/login/oauth/authorize',
      token_url: 'https://github.com/login/oauth/access_token',
      user_info_url: 'https://api.github.com/user',
      scope: 'user:email'
    },
    'apple' => {
      auth_url: 'https://appleid.apple.com/auth/authorize',
      token_url: 'https://appleid.apple.com/auth/token',
      user_info_url: nil, # Apple returns user info with token exchange
      scope: 'name email'
    }
  }.freeze

  class << self
    # Generate OAuth authorization URL
    def authorization_url(provider, redirect_uri, state = nil)
      config = PROVIDERS[provider.to_s]
      return nil unless config

      client_id = self.client_id(provider)
      return nil unless client_id

      params = {
        client_id: client_id,
        redirect_uri: redirect_uri,
        response_type: 'code',
        scope: config[:scope]
      }

      # Apple-specific parameters
      if provider.to_s == 'apple'
        params[:response_mode] = 'form_post'
      end

      params[:state] = state if state && !state.empty?

      "#{config[:auth_url]}?#{URI.encode_www_form(params)}"
    end

    # Exchange authorization code for access token
    def exchange_code_for_token(provider, code, redirect_uri)
      puts "[OAUTH DEBUG] Starting token exchange for #{provider}"
      puts "[OAUTH DEBUG] Redirect URI: #{redirect_uri}"

      config = PROVIDERS[provider.to_s]
      unless config
        puts "[OAUTH DEBUG] ERROR: No config found for provider #{provider}"
        return nil
      end

      client_id = self.client_id(provider)
      puts "[OAUTH DEBUG] Client ID: #{client_id ? "#{client_id[0..10]}..." : 'MISSING'}"

      # Handle Apple's JWT-based authentication
      if provider.to_s == 'apple'
        client_secret = generate_apple_client_secret(client_id)
        puts "[OAUTH DEBUG] Apple client secret: #{client_secret ? 'GENERATED' : 'FAILED TO GENERATE'}"
        return nil unless client_secret
      else
        client_secret = self.client_secret(provider)
        puts "[OAUTH DEBUG] Client secret: #{client_secret ? 'PRESENT' : 'MISSING'}"
        return nil unless client_secret
      end

      return nil unless client_id

      uri = URI(config[:token_url])
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      # Configure SSL settings for development
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http.ca_file = nil
      http.ca_path = nil

      # In development, we might need to be more lenient with SSL verification
      # but we should try to verify certificates when possible
      begin
        # Try to set up proper certificate verification
        http.cert_store = OpenSSL::X509::Store.new
        http.cert_store.set_default_paths
      rescue => ssl_setup_error
        puts "[OAUTH DEBUG] SSL setup warning: #{ssl_setup_error.message}"
        # Fallback to less strict verification in development only
        if ENV['RACK_ENV'] == 'development' || ENV['RAILS_ENV'] == 'development'
          puts "[OAUTH DEBUG] Using less strict SSL verification for development"
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
      end

      request = Net::HTTP::Post.new(uri)
      request['Accept'] = 'application/json'
      request['Content-Type'] = 'application/x-www-form-urlencoded'

      request_params = {
        client_id: client_id,
        client_secret: client_secret,
        code: code,
        redirect_uri: redirect_uri,
        grant_type: 'authorization_code'
      }

      request.body = URI.encode_www_form(request_params)
      puts "[OAUTH DEBUG] Making token request to: #{config[:token_url]}"

      response = http.request(request)
      puts "[OAUTH DEBUG] Token response status: #{response.code}"

      if response.is_a?(Net::HTTPSuccess)
        puts "[OAUTH DEBUG] Token exchange successful"
        token_data = JSON.parse(response.body)

        # For Apple, extract user info from id_token if available
        if provider.to_s == 'apple' && token_data['id_token']
          puts "[OAUTH DEBUG] Extracting user info from Apple ID token"
          token_data['user_info'] = decode_apple_id_token(token_data['id_token'])
        end

        token_data
      else
        puts "[OAUTH DEBUG] ERROR: Token exchange failed - #{response.code}"
        Rails.logger.error("OAuth token exchange failed for #{provider}: #{response.code}") if defined?(Rails)
        nil
      end
    rescue JSON::ParserError => e
      puts "[OAUTH DEBUG] ERROR: JSON parsing failed - #{e.message}"
      Rails.logger.error("OAuth token parsing error for #{provider}: #{e.message}") if defined?(Rails)
      nil
    rescue => e
      puts "[OAUTH DEBUG] ERROR: Token exchange exception - #{e.message}"
      puts "[OAUTH DEBUG] ERROR: #{e.backtrace.first(3).join("\n")}"
      Rails.logger.error("OAuth token exchange error for #{provider}: #{e.message}") if defined?(Rails)
      nil
    end

    # Fetch user information from OAuth provider
    def fetch_user_info(provider, access_token_or_data)
      puts "[OAUTH DEBUG] Starting user info fetch for #{provider}"

      config = PROVIDERS[provider.to_s]
      unless config
        puts "[OAUTH DEBUG] ERROR: No config found for provider #{provider}"
        return nil
      end

      # Apple returns user info with token exchange, not separate endpoint
      if provider.to_s == 'apple'
        puts "[OAUTH DEBUG] Processing Apple user info from token data"
        # For Apple, access_token_or_data is actually the token response with user_info
        user_info = access_token_or_data.is_a?(Hash) ? access_token_or_data['user_info'] : nil
        puts "[OAUTH DEBUG] Apple user info: #{user_info ? 'PRESENT' : 'MISSING'}"
        if user_info
          normalized = normalize_user_info(provider, user_info)
          puts "[OAUTH DEBUG] Normalized Apple user info: #{normalized.inspect}"
          return normalized
        end
        return nil
      end

      # For other providers, fetch from user info endpoint
      unless config[:user_info_url]
        puts "[OAUTH DEBUG] ERROR: No user info URL configured for #{provider}"
        return nil
      end

      puts "[OAUTH DEBUG] Fetching user info from: #{config[:user_info_url]}"

      uri = URI(config[:user_info_url])
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      # Configure SSL settings for development (same as token exchange)
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http.ca_file = nil
      http.ca_path = nil

      begin
        # Try to set up proper certificate verification
        http.cert_store = OpenSSL::X509::Store.new
        http.cert_store.set_default_paths
      rescue => ssl_setup_error
        puts "[OAUTH DEBUG] SSL setup warning for user info: #{ssl_setup_error.message}"
        # Fallback to less strict verification in development only
        if ENV['RACK_ENV'] == 'development' || ENV['RAILS_ENV'] == 'development'
          puts "[OAUTH DEBUG] Using less strict SSL verification for user info in development"
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
      end

      request = Net::HTTP::Get.new(uri)
      request['Authorization'] = "Bearer #{access_token_or_data}"
      request['Accept'] = 'application/json'

      # GitHub requires User-Agent header
      if provider.to_s == 'github'
        request['User-Agent'] = 'BandHuddle-OAuth-Client'
        puts "[OAUTH DEBUG] Added User-Agent header for GitHub"
      end

      response = http.request(request)
      puts "[OAUTH DEBUG] User info response status: #{response.code}"

      if response.is_a?(Net::HTTPSuccess)
        puts "[OAUTH DEBUG] User info fetch successful"
        user_info = JSON.parse(response.body)
        puts "[OAUTH DEBUG] Raw user info keys: #{user_info.keys}"
        puts "[OAUTH DEBUG] User email: #{user_info['email']}"
        puts "[OAUTH DEBUG] User ID: #{user_info['id']}"
        puts "[OAUTH DEBUG] User name: #{user_info['name']}"

        # Normalize user info structure across providers
        normalized = normalize_user_info(provider, user_info)
        puts "[OAUTH DEBUG] Normalized user info: #{normalized.inspect}"
        puts "[OAUTH DEBUG] Name that will be used for username: #{normalized['name']}"
        normalized
      else
        puts "[OAUTH DEBUG] ERROR: User info fetch failed - #{response.code}: #{response.body}"
        Rails.logger.error("OAuth user info fetch failed for #{provider}: #{response.code} #{response.body}") if defined?(Rails)
        nil
      end
    rescue JSON::ParserError => e
      puts "[OAUTH DEBUG] ERROR: User info JSON parsing failed - #{e.message}"
      Rails.logger.error("OAuth user info parsing error for #{provider}: #{e.message}") if defined?(Rails)
      nil
    rescue => e
      puts "[OAUTH DEBUG] ERROR: User info fetch exception - #{e.message}"
      puts "[OAUTH DEBUG] ERROR: #{e.backtrace.first(3).join("\n")}"
      Rails.logger.error("OAuth user info fetch error for #{provider}: #{e.message}") if defined?(Rails)
      nil
    end

    # Find existing OAuth user
    def find_existing_oauth_user(provider, user_info)
      puts "[OAUTH DEBUG] Looking for existing OAuth user for #{provider}"

      provider = provider.to_s
      oauth_uid = user_info['id']
      email = user_info['email']

      puts "[OAUTH DEBUG] OAuth UID: #{oauth_uid}"
      puts "[OAUTH DEBUG] Email: #{email}"

      # Check if user already exists with this OAuth provider
      puts "[OAUTH DEBUG] Looking for existing user with oauth_provider='#{provider}' and oauth_uid='#{oauth_uid}'"
      existing_user = User.find_by(oauth_provider: provider, oauth_uid: oauth_uid)

      if existing_user
        puts "[OAUTH DEBUG] Found existing OAuth user: #{existing_user.username} (ID: #{existing_user.id})"
        return existing_user
      end

      # Check if user exists by email (for account linking)
      if email && !email.empty?
        puts "[OAUTH DEBUG] Looking for existing user with email '#{email}'"
        user_by_email = User.find_by(email: email)

        if user_by_email
          # Check if user already has an OAuth provider (single provider restriction)
          if user_by_email.oauth_provider && user_by_email.oauth_provider != provider
            error_msg = "User already has #{user_by_email.oauth_provider} OAuth account. Only one OAuth provider per user is allowed."
            puts "[OAUTH DEBUG] ERROR: #{error_msg}"
            raise error_msg
          end

          puts "[OAUTH DEBUG] Found user by email for linking: #{user_by_email.username} (ID: #{user_by_email.id})"
          # Link OAuth to existing user and return
          return link_oauth_to_user(user_by_email, provider, user_info)
        end
      end

      puts "[OAUTH DEBUG] No existing user found"
      nil
    rescue => e
      puts "[OAUTH DEBUG] ERROR in find_existing_oauth_user: #{e.message}"
      puts "[OAUTH DEBUG] ERROR: #{e.backtrace.first(5).join("\n")}"
      raise e
    end

    # Create OAuth user with account creation code validation
    def create_oauth_user_with_validation(provider, user_info, account_creation_code)
      puts "[OAUTH DEBUG] Creating OAuth user with validation for #{provider}"
      puts "[OAUTH DEBUG] Validating account creation code"

      # Validate account creation code
      unless validate_account_creation_code(account_creation_code)
        error_msg = "Invalid account creation code. Please check your code and try again."
        puts "[OAUTH DEBUG] ERROR: #{error_msg}"
        raise error_msg
      end

      puts "[OAUTH DEBUG] Account creation code validated successfully"
      create_user_with_oauth(provider, user_info)
    rescue => e
      puts "[OAUTH DEBUG] ERROR in create_oauth_user_with_validation: #{e.message}"
      puts "[OAUTH DEBUG] ERROR: #{e.backtrace.first(5).join("\n")}"
      raise e
    end

    # Validate account creation code
    def validate_account_creation_code(code)
      login_secret = ENV['BAND_HUDDLE_ACCT_CREATION_SECRET']

      # Check if secret is configured
      if login_secret.nil? || login_secret.empty?
        puts "[OAUTH DEBUG] ERROR: Account creation code not configured"
        raise "Account creation code not configured. Please contact administrator."
      end

      # Compare submitted code with environment secret
      result = code == login_secret
      puts "[OAUTH DEBUG] Account creation code validation result: #{result ? 'VALID' : 'INVALID'}"
      result
    end

    # Find or create user from OAuth provider data (backward compatibility)
    def find_or_create_user(provider, user_info)
      puts "[OAUTH DEBUG] Starting find_or_create_user for #{provider} (backward compatibility mode)"
      puts "[OAUTH DEBUG] User info received: #{user_info.inspect}"

      # Try to find existing user first
      existing_user = find_existing_oauth_user(provider, user_info)
      return existing_user if existing_user

      # If no existing user, create new one (without code validation for backward compatibility)
      puts "[OAUTH DEBUG] Creating new user with OAuth (no code validation)"
      create_user_with_oauth(provider, user_info)
    rescue => e
      puts "[OAUTH DEBUG] ERROR in find_or_create_user: #{e.message}"
      puts "[OAUTH DEBUG] ERROR: #{e.backtrace.first(5).join("\n")}"
      raise e
    end

    # Unlink OAuth provider from user
    def unlink_oauth_from_user(user)
      # Ensure user has password authentication available
      if user.password_digest.nil?
        raise "Cannot unlink OAuth - user has no password set. Please set a password first."
      end

      user.update!(
        oauth_provider: nil,
        oauth_uid: nil,
        oauth_email: nil,
        oauth_username: nil
      )

      user
    end

    # Check if provider is properly configured
    def provider_configured?(provider)
      case provider.to_s
      when 'google'
        !!(client_id(provider) && client_secret(provider))
      when 'github'
        !!(client_id(provider) && client_secret(provider))
      when 'apple'
        !!(client_id(provider) && ENV['APPLE_KEY_ID'] && ENV['APPLE_TEAM_ID'] && ENV['APPLE_PRIVATE_KEY'])
      else
        false
      end
    end

    # Get list of configured providers
    def configured_providers
      PROVIDERS.keys.select { |provider| provider_configured?(provider) }
    end

    private

    # Normalize user info from different providers to consistent format
    def normalize_user_info(provider, raw_info)
      return nil unless raw_info

      case provider.to_s
      when 'google'
        {
          'id' => raw_info['id'],
          'email' => raw_info['email'],
          'name' => raw_info['name'],
          'username' => raw_info['email']&.split('@')&.first,
          'picture' => raw_info['picture'],
          'provider' => 'google',
          'raw_info' => raw_info
        }
      when 'github'
        {
          'id' => raw_info['id'].to_s,
          'email' => raw_info['email'],
          'name' => raw_info['name'] || raw_info['login'],
          'username' => raw_info['login'],
          'picture' => raw_info['avatar_url'],
          'provider' => 'github',
          'raw_info' => raw_info
        }
      when 'apple'
        # Apple user info comes from ID token
        email = raw_info['email']
        name = raw_info['name'] ? "#{raw_info['name']['firstName']} #{raw_info['name']['lastName']}".strip : nil
        name = email&.split('@')&.first if name.nil? || name.empty?

        {
          'id' => raw_info['sub'],
          'email' => email,
          'name' => name,
          'username' => email&.split('@')&.first,
          'picture' => nil, # Apple doesn't provide profile pictures
          'provider' => 'apple',
          'raw_info' => raw_info
        }
      else
        raw_info
      end
    end

    # Link OAuth to existing user
    def link_oauth_to_user(user, provider, user_info)
      puts "[OAUTH DEBUG] Linking OAuth to existing user #{user.username} (ID: #{user.id})"
      puts "[OAUTH DEBUG] Updating with provider: #{provider}, uid: #{user_info['id']}, email: #{user_info['email']}, username: #{user_info['username']}"

      user.update!(
        oauth_provider: provider,
        oauth_uid: user_info['id'],
        oauth_email: user_info['email'],
        oauth_username: user_info['username']
      )

      puts "[OAUTH DEBUG] OAuth successfully linked to user #{user.username}"
      user
    rescue => e
      puts "[OAUTH DEBUG] ERROR linking OAuth to user: #{e.message}"
      puts "[OAUTH DEBUG] ERROR: #{e.backtrace.first(3).join("\n")}"
      raise e
    end

    # Create new user with OAuth
    def create_user_with_oauth(provider, user_info)
      puts "[OAUTH DEBUG] Creating new user with OAuth"

      # Use the name from the provider as the base for username
      # Priority: name > username > email local part > fallback
      base_username = user_info['name'] || user_info['username'] || user_info['email']&.split('@')&.first || 'user'
      puts "[OAUTH DEBUG] Using provider name for username base: #{base_username}"

      username = generate_unique_username(base_username)
      puts "[OAUTH DEBUG] Generated unique username: #{username}"

      user_params = {
        username: username,
        email: user_info['email'],
        password_digest: nil, # OAuth-only user
        oauth_provider: provider,
        oauth_uid: user_info['id'],
        oauth_email: user_info['email'],
        oauth_username: user_info['username']
      }

      user = User.create!(user_params)
      puts "[OAUTH DEBUG] New user created successfully: #{user.username} (ID: #{user.id})"
      user
    rescue => e
      puts "[OAUTH DEBUG] ERROR creating user: #{e.message}"
      puts "[OAUTH DEBUG] ERROR: #{e.backtrace.first(3).join("\n")}"

      # Log validation errors if it's a validation failure
      if e.respond_to?(:record) && e.record&.errors&.any?
        puts "[OAUTH DEBUG] Validation errors: #{e.record.errors.full_messages.join(', ')}"
      end

      raise e
    end

    # Generate unique username
    def generate_unique_username(base_username)
      # Clean up username (only alphanumeric and underscore)
      clean_base = base_username.to_s.gsub(/[^a-zA-Z0-9_]/, '_').downcase

      # Ensure it's not empty
      clean_base = 'user' if clean_base.empty?

      # Find unique username
      username = clean_base
      counter = 1

      while User.exists?(username: username)
        username = "#{clean_base}_#{counter}"
        counter += 1
      end

      username
    end

    # Get client ID for provider
    def client_id(provider)
      ENV["#{provider.to_s.upcase}_CLIENT_ID"]
    end

    # Get client secret for provider
    def client_secret(provider)
      ENV["#{provider.to_s.upcase}_CLIENT_SECRET"]
    end

    # Generate Apple JWT client secret
    def generate_apple_client_secret(client_id)
      # Get Apple-specific environment variables
      key_id = ENV['APPLE_KEY_ID']
      team_id = ENV['APPLE_TEAM_ID']
      private_key_content = ENV['APPLE_PRIVATE_KEY']

      return nil unless key_id && team_id && private_key_content

      # Create private key object
      private_key = OpenSSL::PKey::EC.new(private_key_content)

      # JWT headers
      headers = {
        'kid' => key_id,
        'alg' => 'ES256'
      }

      # JWT payload
      payload = {
        'iss' => team_id,
        'iat' => Time.now.to_i,
        'exp' => Time.now.to_i + 3600, # Expires in 1 hour
        'aud' => 'https://appleid.apple.com',
        'sub' => client_id
      }

      # Generate JWT
      JWT.encode(payload, private_key, 'ES256', headers)
    rescue => e
      Rails.logger.error("Apple JWT generation error: #{e.message}") if defined?(Rails)
      nil
    end

    # Decode Apple ID token to extract user information
    def decode_apple_id_token(id_token)
      # For security in production, this should validate the token signature
      # For now, we'll decode without verification (Apple's token should be trusted)
      decoded_token = JWT.decode(id_token, nil, false)[0]

      # Extract user information from the token
      user_info = {
        'sub' => decoded_token['sub'],
        'email' => decoded_token['email'],
        'email_verified' => decoded_token['email_verified']
      }

      # Name information might be present
      if decoded_token['name']
        user_info['name'] = decoded_token['name']
      end

      user_info
    rescue JWT::DecodeError => e
      Rails.logger.error("Apple ID token decode error: #{e.message}") if defined?(Rails)
      nil
    rescue => e
      Rails.logger.error("Apple ID token processing error: #{e.message}") if defined?(Rails)
      nil
    end
  end
end
