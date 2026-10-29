require 'sinatra/base'
require 'securerandom'

module Routes
end

class Routes::OAuth < Sinatra::Base
  configure do
    set :views, File.join(File.dirname(__FILE__), '..', '..', 'views')
  end

  helpers ApplicationHelpers

  # Load services
  require_relative '../services/oauth_service'
  require_relative '../helpers/oauth_debug_log'

  # ============================================================================
  # OAUTH ACCOUNT CREATION CODE VERIFICATION (must come before :provider routes)
  # ============================================================================

  # Display account creation code form for new OAuth users
  get '/auth/verify_account_creation_code' do
    # Check if there's pending OAuth user data
    unless session[:pending_oauth_user]
      OauthDebugLog.log "[OAUTH DEBUG] No pending OAuth user data found, redirecting to login"
      redirect "/login?error=#{URI.encode_www_form_component('Session expired. Please try signing in again.')}"
    end

    # Check session timeout (30 minutes)
    pending_data = session[:pending_oauth_user]

    # Check session timeout (30 minutes = 1800 seconds)
    if Time.now.to_i - pending_data[:timestamp] > 1800
      OauthDebugLog.log "[OAUTH DEBUG] Pending OAuth session expired"
      session.delete(:pending_oauth_user)
      redirect "/login?error=#{URI.encode_www_form_component('Session expired. Please try signing in again.')}"
    end

    @provider = pending_data[:provider]
    @email = pending_data[:user_info]['email']
    @name = pending_data[:user_info]['name']

    @breadcrumbs = [
      { label: 'Account Creation', url: nil, icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"></path><circle cx="9" cy="7" r="4"></circle><path d="M22 21v-2a4 4 0 0 0-3-3.87"></path><path d="M16 3.13a4 4 0 0 1 0 7.75"></path></svg>' }
    ]

    erb :oauth_account_creation_code
  end

  # Process account creation code for new OAuth users
  post '/auth/verify_account_creation_code' do
    # Check if there's pending OAuth user data
    unless session[:pending_oauth_user]
      OauthDebugLog.log "[OAUTH DEBUG] No pending OAuth user data found, redirecting to login"
      redirect "/login?error=#{URI.encode_www_form_component('Session expired. Please try signing in again.')}"
    end

    pending_data = session[:pending_oauth_user]

    # Check session timeout (30 minutes = 1800 seconds)
    if Time.now.to_i - pending_data[:timestamp] > 1800
      OauthDebugLog.log "[OAUTH DEBUG] Pending OAuth session expired"
      session.delete(:pending_oauth_user)
      redirect "/login?error=#{URI.encode_www_form_component('Session expired. Please try signing in again.')}"
    end

    provider = pending_data[:provider]
    user_info = pending_data[:user_info]
    account_creation_code = params[:account_creation_code]

    @provider = provider
    @email = user_info['email']
    @name = user_info['name']

    @breadcrumbs = [
      { label: 'Account Creation', url: nil, icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"></path><circle cx="9" cy="7" r="4"></circle><path d="M22 21v-2a4 4 0 0 0-3-3.87"></path><path d="M16 3.13a4 4 0 0 1 0 7.75"></path></svg>' }
    ]

    begin
      OauthDebugLog.log "[OAUTH DEBUG] Attempting to create OAuth user with validation"

      # Create user with validation
      user = OauthService.create_oauth_user_with_validation(provider, user_info, account_creation_code)

      OauthDebugLog.log "[OAUTH DEBUG] User created successfully: #{user.username} (ID: #{user.id})"

      # Clear pending OAuth data
      session.delete(:pending_oauth_user)

      # Log in the user
      session[:user_id] = user.id

      # Handle band selection (same as normal OAuth flow)
      if user.last_selected_band && user.bands.include?(user.last_selected_band)
        session[:band_id] = user.last_selected_band.id
      elsif user.bands.any?
        session[:band_id] = user.bands.first.id
      end

      OauthDebugLog.log "[OAUTH DEBUG] New OAuth user logged in successfully, redirecting to /gigs"
      redirect '/gigs'

    rescue => e
      OauthDebugLog.log "[OAUTH DEBUG] Error creating OAuth user: #{e.message}"

      error_message = case e.message
      when /Invalid account creation code/
        "Invalid account creation code. Please check your code and try again."
      when /Account creation code not configured/
        "Account creation is not configured. Please contact administrator."
      else
        "Failed to create account. Please try again."
      end

      @errors = [error_message]
      erb :oauth_account_creation_code
    end
  end

  # ============================================================================
  # OAUTH LINK CONFIRMATION (must come before :provider routes)
  # ============================================================================

  # Display password confirmation for linking OAuth to an existing account
  get '/auth/link_account' do
    pending_data = session[:pending_oauth_link]

    unless pending_data
      OauthDebugLog.log "[OAUTH DEBUG] No pending OAuth link data found, redirecting to login"
      redirect "/login?error=#{URI.encode_www_form_component('Session expired. Please try signing in again.')}"
    end

    # Check session timeout (30 minutes = 1800 seconds)
    if Time.now.to_i - pending_data[:timestamp] > 1800
      OauthDebugLog.log "[OAUTH DEBUG] Pending OAuth link session expired"
      session.delete(:pending_oauth_link)
      redirect "/login?error=#{URI.encode_www_form_component('Session expired. Please try signing in again.')}"
    end

    @provider = pending_data[:provider]
    @email = pending_data[:user_info]['email']
    @name = pending_data[:user_info]['name']

    @breadcrumbs = [
      { label: 'Link Account', url: nil, icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"></path><circle cx="9" cy="7" r="4"></circle><path d="M22 21v-2a4 4 0 0 0-3-3.87"></path><path d="M16 3.13a4 4 0 0 1 0 7.75"></path></svg>' }
    ]

    erb :oauth_link_confirmation
  end

  # Confirm linking with the account password
  post '/auth/link_account' do
    pending_data = session[:pending_oauth_link]

    unless pending_data
      OauthDebugLog.log "[OAUTH DEBUG] No pending OAuth link data found, redirecting to login"
      redirect "/login?error=#{URI.encode_www_form_component('Session expired. Please try signing in again.')}"
    end

    # Check session timeout (30 minutes = 1800 seconds)
    if Time.now.to_i - pending_data[:timestamp] > 1800
      OauthDebugLog.log "[OAUTH DEBUG] Pending OAuth link session expired"
      session.delete(:pending_oauth_link)
      redirect "/login?error=#{URI.encode_www_form_component('Session expired. Please try signing in again.')}"
    end

    # Limit password attempts so the confirmation page cannot be used to
    # brute-force the account password
    if pending_data[:attempts].to_i >= 5
      OauthDebugLog.log "[OAUTH DEBUG] Too many link confirmation attempts"
      session.delete(:pending_oauth_link)
      redirect "/login?error=#{URI.encode_www_form_component('Too many incorrect attempts. Please try signing in again.')}"
    end

    user = User.find_by(id: pending_data[:user_id])

    if user.nil?
      OauthDebugLog.log "[OAUTH DEBUG] Link target account no longer exists"
      session.delete(:pending_oauth_link)
      redirect "/login?error=#{URI.encode_www_form_component('Account no longer exists.')}"
    end

    if user.oauth_provider.present?
      OauthDebugLog.log "[OAUTH DEBUG] Link target already has an OAuth provider"
      session.delete(:pending_oauth_link)
      error_msg = "This account is already linked to #{user.oauth_provider}. Only one OAuth provider per user is allowed."
      redirect "/login?error=#{URI.encode_www_form_component(error_msg)}"
    end

    provider = pending_data[:provider]
    user_info = pending_data[:user_info]

    @provider = provider
    @email = user_info['email']
    @name = user_info['name']

    @breadcrumbs = [
      { label: 'Link Account', url: nil, icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"></path><circle cx="9" cy="7" r="4"></circle><path d="M22 21v-2a4 4 0 0 0-3-3.87"></path><path d="M16 3.13a4 4 0 0 1 0 7.75"></path></svg>' }
    ]

    if user.authenticate(params[:password])
      OauthDebugLog.log "[OAUTH DEBUG] Link confirmed, attaching OAuth identity"
      OauthService.link_oauth_to_user(user, provider, user_info)

      # Clear pending link data
      session.delete(:pending_oauth_link)

      # Log in the user
      session[:user_id] = user.id

      # Handle band selection (same as normal OAuth flow)
      if user.last_selected_band && user.bands.include?(user.last_selected_band)
        session[:band_id] = user.last_selected_band.id
      elsif user.bands.any?
        session[:band_id] = user.bands.first.id
      end

      OauthDebugLog.log "[OAUTH DEBUG] OAuth identity linked and user logged in, redirecting to /gigs"
      redirect '/gigs'
    else
      OauthDebugLog.log "[OAUTH DEBUG] Incorrect password during link confirmation"
      session[:pending_oauth_link] = pending_data.merge(attempts: pending_data[:attempts].to_i + 1)
      @errors = ['Incorrect password. Please try again.']
      erb :oauth_link_confirmation
    end
  end

  # ============================================================================
  # OAUTH AUTHORIZATION ROUTES
  # ============================================================================

  # Initiate OAuth authorization
  get '/auth/:provider' do
    provider = params[:provider]

    # Validate provider exists and is configured
    unless OauthService::PROVIDERS.key?(provider.to_s)
      redirect "/login?error=#{URI.encode_www_form_component('Unsupported OAuth provider')}"
    end

    # Check if provider is properly configured
    unless OauthService.provider_configured?(provider)
      redirect "/login?error=#{URI.encode_www_form_component('OAuth provider not configured')}"
    end

    # Generate state parameter for security
    state = SecureRandom.hex(16)
    session[:oauth_state] = state

    # Build redirect URI
    redirect_uri = "#{request.base_url}/auth/#{provider}/callback"

    # Generate authorization URL
    auth_url = OauthService.authorization_url(provider, redirect_uri, state)

    if auth_url
      redirect auth_url
    else
      redirect "/login?error=#{URI.encode_www_form_component('OAuth configuration error')}"
    end
  end

  # Handle OAuth callback
  get '/auth/:provider/callback' do
    OauthDebugLog.log "\n[OAUTH DEBUG] ===== OAUTH CALLBACK STARTED ====="
    OauthDebugLog.log "[OAUTH DEBUG] Provider: #{params[:provider]}"
    OauthDebugLog.log "[OAUTH DEBUG] Error: #{params[:error]}"

    provider = params[:provider]
    code = params[:code]
    state = params[:state]
    error = params[:error]

    # Handle OAuth errors
    if error
      OauthDebugLog.log "[OAUTH DEBUG] OAuth provider returned error: #{error}"
      error_msg = case error
      when 'access_denied'
        'OAuth access was denied'
      else
        "OAuth error: #{error}"
      end
      OauthDebugLog.log "[OAUTH DEBUG] Redirecting to login with error: #{error_msg}"
      redirect "/login?error=#{URI.encode_www_form_component(error_msg)}"
    end

    # Verify state parameter to prevent CSRF attacks
    unless state == session[:oauth_state]
      OauthDebugLog.log "[OAUTH DEBUG] State mismatch! Expected: #{session[:oauth_state]}, Got: #{state}"
      session.delete(:oauth_state)
      redirect "/login?error=#{URI.encode_www_form_component('Invalid OAuth state')}"
    end

    OauthDebugLog.log "[OAUTH DEBUG] State verification passed"

    # Clear state from session
    session.delete(:oauth_state)

    # Validate required parameters
    unless code.present?
      OauthDebugLog.log "[OAUTH DEBUG] Missing authorization code"
      redirect "/login?error=#{URI.encode_www_form_component('Missing OAuth authorization code')}"
    end

    begin
      OauthDebugLog.log "[OAUTH DEBUG] Starting OAuth token exchange process"

      # Exchange authorization code for access token
      redirect_uri = "#{request.base_url}/auth/#{provider}/callback"
      OauthDebugLog.log "[OAUTH DEBUG] Redirect URI: #{redirect_uri}"

      token_data = OauthService.exchange_code_for_token(provider, code, redirect_uri)
      OauthDebugLog.log "[OAUTH DEBUG] Token exchange completed. Token data present: #{!token_data.nil?}"

      unless token_data && token_data['access_token']
        OauthDebugLog.log "[OAUTH DEBUG] ERROR: No access token received"
        redirect "/login?error=#{URI.encode_www_form_component('Failed to obtain OAuth access token')}"
      end

      OauthDebugLog.log "[OAUTH DEBUG] Access token obtained successfully"

      # Fetch user information. Apple returns user info inside the token
      # exchange response (decoded from the ID token), so it gets the whole
      # token_data hash; other providers get the access token string.
      OauthDebugLog.log "[OAUTH DEBUG] Fetching user information"
      user_info_source = provider.to_s == 'apple' ? token_data : token_data['access_token']
      user_info = OauthService.fetch_user_info(provider, user_info_source)
      OauthDebugLog.log "[OAUTH DEBUG] User info fetch completed. User info present: #{!user_info.nil?}"

      unless user_info
        OauthDebugLog.log "[OAUTH DEBUG] ERROR: Failed to fetch user information"
        redirect "/login?error=#{URI.encode_www_form_component('Failed to fetch user information')}"
      end

      OauthDebugLog.log "[OAUTH DEBUG] User information fetched successfully"

      # Check if this OAuth identity is already linked to an account
      OauthDebugLog.log "[OAUTH DEBUG] Checking if user exists"
      user = OauthService.find_existing_oauth_user(provider, user_info)

      if user
        # Existing linked user - continue normal flow
        OauthDebugLog.log "[OAUTH DEBUG] Existing linked user found: #{user.username} (ID: #{user.id})"
      else
        # A provider-verified email may match an existing local account.
        # Never link silently: an account with a local password must confirm
        # that password before the OAuth identity is attached.
        link_candidate = OauthService.find_link_candidate_by_email(provider, user_info)

        if link_candidate
          OauthDebugLog.log "[OAUTH DEBUG] Verified email matches password account - requiring link confirmation"
          session[:pending_oauth_link] = {
            provider: provider,
            user_id: link_candidate.id,
            user_info: user_info,
            timestamp: Time.now.to_i
          }

          OauthDebugLog.log "[OAUTH DEBUG] Redirecting to OAuth link confirmation"
          redirect '/auth/link_account'
        elsif user_info['email'].present? && OauthService.find_user_by_email(user_info['email'])
          # Email collision the provider has not verified - refuse rather
          # than create a second account claiming the same address
          OauthDebugLog.log "[OAUTH DEBUG] Unverified email matches existing account - refusing"
          error_msg = "An account with this email already exists. Sign in with your password, or verify this email address with #{provider.capitalize} and try again."
          redirect "/login?error=#{URI.encode_www_form_component(error_msg)}"
        else
          # New user - requires account creation code validation
          OauthDebugLog.log "[OAUTH DEBUG] New user detected - requires account creation code"

          # Store OAuth data in session for later user creation
          session[:pending_oauth_user] = {
            provider: provider,
            user_info: user_info,
            token_data: token_data,
            timestamp: Time.now.to_i
          }

          OauthDebugLog.log "[OAUTH DEBUG] OAuth data stored in session, redirecting to account creation code verification"
          redirect '/auth/verify_account_creation_code'
        end
      end

      OauthDebugLog.log "[OAUTH DEBUG] User account resolved: #{user.username} (ID: #{user.id})"

      # Log in the user
      OauthDebugLog.log "[OAUTH DEBUG] Setting session user_id to: #{user.id}"
      session[:user_id] = user.id

      # Handle band selection
      OauthDebugLog.log "[OAUTH DEBUG] Handling band selection"
      OauthDebugLog.log "[OAUTH DEBUG] User's last selected band: #{user.last_selected_band&.name}"
      OauthDebugLog.log "[OAUTH DEBUG] User's bands: #{user.bands.pluck(:name)}"

      if user.last_selected_band && user.bands.include?(user.last_selected_band)
        OauthDebugLog.log "[OAUTH DEBUG] Setting session band_id to last selected: #{user.last_selected_band.id}"
        session[:band_id] = user.last_selected_band.id
      elsif user.bands.any?
        OauthDebugLog.log "[OAUTH DEBUG] Setting session band_id to first band: #{user.bands.first.id}"
        session[:band_id] = user.bands.first.id
      else
        OauthDebugLog.log "[OAUTH DEBUG] User has no bands, not setting band_id"
      end

      OauthDebugLog.log "[OAUTH DEBUG] Final session state - user_id: #{session[:user_id]}, band_id: #{session[:band_id]}"

      # Redirect to main app
      OauthDebugLog.log "[OAUTH DEBUG] Redirecting to /gigs"
      OauthDebugLog.log "[OAUTH DEBUG] ===== OAUTH CALLBACK COMPLETED SUCCESSFULLY ====="
      redirect '/gigs'

    rescue => e
      OauthDebugLog.log "[OAUTH DEBUG] ===== OAUTH CALLBACK ERROR ====="
      OauthDebugLog.log "[OAUTH DEBUG] Exception: #{e.class.name}: #{e.message}"
      OauthDebugLog.log "[OAUTH DEBUG] Backtrace:"
      OauthDebugLog.log e.backtrace.first(10).map { |line| "[OAUTH DEBUG]   #{line}" }.join("\n")

      error_msg = case e.message
      when /already has .* OAuth account/
        e.message
      else
        'OAuth authentication failed'
      end

      # Log error for debugging
      puts "OAuth callback error: #{e.message}" if settings.development?

      OauthDebugLog.log "[OAUTH DEBUG] Redirecting to login with error: #{error_msg}"
      redirect "/login?error=#{URI.encode_www_form_component(error_msg)}"
    end
  end

  # Disconnect OAuth provider
  post '/auth/:provider/disconnect' do
    require_login
    provider = params[:provider]

    # Verify user has this OAuth provider
    unless current_user.has_oauth_provider?(provider)
      status 404
      return { error: 'OAuth provider not found' }.to_json
    end

    begin
      # Unlink OAuth from user
      OauthService.unlink_oauth_from_user(current_user)

      if request.accept.include?('application/json')
        content_type :json
        { success: true, message: 'OAuth provider disconnected successfully' }.to_json
      else
        redirect '/profile?success=OAuth+provider+disconnected+successfully'
      end

    rescue => e
      error_message = e.message

      if request.accept.include?('application/json')
        content_type :json
        status 400
        { error: error_message }.to_json
      else
        redirect "/profile?error=#{URI.encode_www_form_component(error_message)}"
      end
    end
  end


  # ============================================================================
  # OAUTH PROFILE MANAGEMENT
  # ============================================================================

  # Get OAuth connection status (API endpoint)
  get '/api/auth/oauth/status' do
    require_api_auth
    content_type :json

    {
      data: {
        has_oauth: current_user.oauth_user?,
        oauth_provider: current_user.oauth_provider,
        oauth_username: current_user.oauth_username,
        can_unlink: current_user.can_unlink_oauth?,
        supported_providers: OauthService::PROVIDERS.keys
      }
    }.to_json
  end

  # Link OAuth provider to existing account
  post '/api/auth/oauth/link/:provider' do
    require_api_auth
    content_type :json
    provider = params[:provider]

    # Check if user already has OAuth provider
    if current_user.oauth_user?
      status 400
      return {
        error: 'User already has OAuth provider linked',
        current_provider: current_user.oauth_provider
      }.to_json
    end

    # Validate provider
    unless OauthService::PROVIDERS.key?(provider.to_s)
      status 400
      return { error: 'Unsupported OAuth provider' }.to_json
    end

    # Generate state and return authorization URL
    state = SecureRandom.hex(16)
    session[:oauth_link_state] = state
    session[:oauth_link_mode] = true

    redirect_uri = "#{request.base_url}/auth/#{provider}/callback"
    auth_url = OauthService.authorization_url(provider, redirect_uri, state)

    if auth_url
      { data: { authorization_url: auth_url } }.to_json
    else
      status 500
      { error: 'Failed to generate authorization URL' }.to_json
    end
  end
end
