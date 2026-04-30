require 'sinatra/base'

module Routes
end

class Routes::Authentication < Sinatra::Base
  configure do
    set :views, File.join(File.dirname(__FILE__), '..', '..', 'views')
  end
  
  helpers ApplicationHelpers
  
  # ============================================================================
  # AUTHENTICATION ROUTES
  # ============================================================================
  
  get '/login' do
    erb :login, layout: :layout
  end

  post '/login' do
    user = User.where('LOWER(username) = ?', params[:username].downcase).first

    if user && user.authenticate(params[:password])
      session[:user_id] = user.id

      # Restore the last selected band if it exists and user still has access to it
      if user.last_selected_band && user.bands.include?(user.last_selected_band)
        session[:band_id] = user.last_selected_band.id
      elsif user.bands.any?
        # If no saved band or user no longer has access, select the first band
        session[:band_id] = user.bands.first.id
      end

      redirect '/gigs'
    else
      @error = "Invalid username or password"
      erb :login, layout: :layout
    end
  end

  get '/signup' do
    erb :signup, layout: :layout
  end

  post '/signup' do
    # Validate account creation code
    login_secret = ENV['BAND_HUDDLE_ACCT_CREATION_SECRET']
    if login_secret.nil? || login_secret.empty?
      @errors = ["Account creation code not configured. Please contact administrator."]
      return erb :signup, layout: :layout
    end

    if params[:login_secret] != login_secret
      @errors = ["Invalid account creation code. Please check your code and try again."]
      return erb :signup, layout: :layout
    end

    user = User.new(username: params[:username], password: params[:password], email: params[:email].presence)

    if user.save
      session[:user_id] = user.id
      redirect '/gigs'
    else
      @errors = user.errors.full_messages
      erb :signup, layout: :layout
    end
  end

  get '/logout' do
    # Save the current band selection before clearing session
    if logged_in? && current_band
      current_user.update(last_selected_band_id: current_band.id)
    end
    
    session.clear
    redirect '/login'
  end

  # ============================================================================
  # MOBILE API AUTHENTICATION ROUTES
  # ============================================================================

  # Mobile login with extended session and JSON response
  post '/api/auth/login' do
    content_type :json

    puts "params: #{params}"
    user = User.where('LOWER(username) = ?', params[:username].downcase).first

    if user && user.authenticate(params[:password])
      session[:user_id] = user.id

      # Restore the last selected band if it exists and user still has access to it
      if user.last_selected_band && user.bands.include?(user.last_selected_band)
        session[:band_id] = user.last_selected_band.id
        selected_band = user.last_selected_band
      elsif user.bands.any?
        # If no saved band or user no longer has access, select the first band
        session[:band_id] = user.bands.first.id
        selected_band = user.bands.first
      else
        selected_band = nil
      end

      # Return user data with bands for mobile app
      {
        success: true,
        data: {
          user: {
            id: user.id,
            username: user.username,
            display_name: user.display_name_or_fallback,
            email: user.email,
            timezone: user.timezone
          },
          bands: user.bands.map { |band|
            {
              id: band.id,
              name: band.name,
              role: user.user_bands.find_by(band: band)&.role || 'member'
            }
          },
          current_band: selected_band ? {
            id: selected_band.id,
            name: selected_band.name
          } : nil
        }
      }.to_json
    else
      status 401
      { success: false, error: "Invalid username or password" }.to_json
    end
  end

  # Validate current session for mobile
  get '/api/auth/session' do
    content_type :json

    if logged_in?
      {
        valid: true,
        user: {
          id: current_user.id,
          username: current_user.username,
          display_name: current_user.display_name_or_fallback,
          email: current_user.email,
          timezone: current_user.timezone
        },
        current_band: current_band ? {
          id: current_band.id,
          name: current_band.name
        } : nil
      }.to_json
    else
      status 401
      { valid: false, error: "Session expired or invalid" }.to_json
    end
  end

  # Mobile logout
  post '/api/auth/logout' do
    content_type :json

    if logged_in?
      # Save the current band selection before clearing session
      if current_band
        current_user.update(last_selected_band_id: current_band.id)
      end

      session.clear
      { success: true, message: "Logged out successfully" }.to_json
    else
      status 401
      { success: false, error: "Not logged in" }.to_json
    end
  end

  # Get current user with bands info for mobile
  get '/api/auth/user' do
    require_login
    content_type :json

    {
      data: {
        user: {
          id: current_user.id,
          username: current_user.username,
          display_name: current_user.display_name_or_fallback,
          email: current_user.email,
          timezone: current_user.timezone,
          created_at: current_user.created_at.iso8601
        },
        bands: current_user.bands.map { |band|
          user_band = current_user.user_bands.find_by(band: band)
          {
            id: band.id,
            name: band.name,
            role: user_band&.role || 'member',
            notes: band.notes,
            google_calendar_enabled: band.google_calendar_enabled,
            created_at: band.created_at.iso8601
          }
        },
        current_band: current_band ? {
          id: current_band.id,
          name: current_band.name
        } : nil
      }
    }.to_json
  end

  # Switch active band for mobile
  post '/api/auth/switch_band' do
    require_login
    content_type :json

    band_id = params[:band_id]&.to_i

    unless band_id
      status 400
      return { success: false, error: "Band ID is required" }.to_json
    end

    # Verify user has access to this band
    band = current_user.bands.find_by(id: band_id)

    if band
      session[:band_id] = band.id
      current_user.update(last_selected_band_id: band.id)

      {
        success: true,
        data: {
          current_band: {
            id: band.id,
            name: band.name
          }
        }
      }.to_json
    else
      status 403
      { success: false, error: "Access denied to this band" }.to_json
    end
  end

  # ============================================================================
  # USER PROFILE AND ACCOUNT ROUTES
  # ============================================================================

  get '/profile' do
    require_login
    @breadcrumbs = [
      { label: '', url: '/', icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px;"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"></path><polyline points="9,22 9,12 15,12 15,22"></polyline></svg>' },
      { label: 'Profile', url: nil, icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px;"><circle cx="12" cy="12" r="3"></circle><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"></path></svg>' }
    ]
    erb :profile
  end

  put '/profile' do
    require_login

    @breadcrumbs = [
      { label: '', url: '/', icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px;"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"></path><polyline points="9,22 9,12 15,12 15,22"></polyline></svg>' },
      { label: 'Profile', url: nil, icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px;"><circle cx="12" cy="12" r="3"></circle><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"></path></svg>' }
    ]

    user = current_user

    # Update user attributes
    if user.update(params[:user])
      @success = "Profile updated successfully!"
      erb :profile
    else
      @errors = user.errors.full_messages
      erb :profile
    end
  end

  post '/profile/change_password' do
    require_login

    @breadcrumbs = [
      { label: '', url: '/', icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px;"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"></path><polyline points="9,22 9,12 15,12 15,22"></polyline></svg>' },
      { label: 'Profile', url: nil, icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px;"><circle cx="12" cy="12" r="3"></circle><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"></path></svg>' }
    ]

    user = current_user

    # Verify current password
    unless user.authenticate(params[:current_password])
      @errors = ["Current password is incorrect"]
      return erb :profile
    end

    # Update password
    if params[:new_password] == params[:confirm_password]
      if user.update(password: params[:new_password])
        @success = "Password changed successfully!"
      else
        @errors = user.errors.full_messages
      end
    else
      @errors = ["New passwords don't match"]
    end

    erb :profile
  end

  post '/profile/public_profile_settings' do
    require_login

    begin
      enabled = params[:public_profile_enabled] == '1'

      # Handle slug update - check if slug field was submitted and has content
      if params[:slug] && !params[:slug].strip.empty?
        desired_slug = params[:slug].strip.downcase
        # Ensure uniqueness
        unique_slug = current_user.ensure_slug_uniqueness(desired_slug)

        # Validate the slug isn't empty after parameterization
        if unique_slug.blank?
          @error = "Invalid slug: must contain at least one letter or number"
          return erb :profile
        end

        current_user.update!(public_profile_enabled: enabled, slug: unique_slug)
      else
        current_user.update!(public_profile_enabled: enabled)
      end

      redirect '/profile?success=Public+profile+settings+updated+successfully'
    rescue ActiveRecord::RecordInvalid => e
      @error = "Failed to update settings: #{e.record.errors.full_messages.join(', ')}"
      erb :profile
    rescue => e
      @error = "Failed to update settings: #{e.message}"
      erb :profile
    end
  end

  # API endpoint to check slug availability
  get '/api/check_slug_availability' do
    require_login
    content_type :json

    slug = params[:slug]

    if slug.nil? || slug.strip.empty?
      return { available: false, message: 'Slug cannot be empty' }.to_json
    end

    # Parameterize the slug the same way we do when saving
    parameterized_slug = slug.strip.parameterize

    if parameterized_slug.empty?
      return { available: false, message: 'Slug must contain at least one letter or number' }.to_json
    end

    # Check if slug is taken by another user
    existing_user = User.where(slug: parameterized_slug).where.not(id: current_user.id).first

    if existing_user
      { available: false, message: 'This URL is already taken' }.to_json
    else
      { available: true, message: 'This URL is available', slug: parameterized_slug }.to_json
    end
  end

  get '/account/delete' do
    require_login
    @breadcrumbs = [
      { label: '', url: '/', icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px;"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"></path><polyline points="9,22 9,12 15,12 15,22"></polyline></svg>' },
      { label: 'Profile', url: '/profile', icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px;"><circle cx="12" cy="12" r="3"></circle><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"></path></svg>' },
      { label: 'Delete Account', url: nil, icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px;"><path d="M3 6h18"></path><path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6"></path><path d="M8 6V4c0-1 1-2 2-2h4c0 1 1 2 2H8z"></path><line x1="10" y1="11" x2="10" y2="17"></line><line x1="14" y1="11" x2="14" y2="17"></line></svg>' }
    ]
    erb :delete_account
  end

  post '/account/delete' do
    require_login

    @breadcrumbs = [
      { label: '', url: '/', icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px;"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"></path><polyline points="9,22 9,12 15,12 15,22"></polyline></svg>' },
      { label: 'Profile', url: '/profile', icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px;"><circle cx="12" cy="12" r="3"></circle><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"></path></svg>' },
      { label: 'Delete Account', url: nil, icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px;"><path d="M3 6h18"></path><path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6"></path><path d="M8 6V4c0-1 1-2 2-2h4c0 1 1 2 2H8z"></path><line x1="10" y1="11" x2="10" y2="17"></line><line x1="14" y1="11" x2="14" y2="17"></line></svg>' }
    ]

    # Verify password for security (only for password-based users)
    # OAuth users don't have passwords, so skip this check for them
    if current_user.password_user?
      unless current_user.authenticate(params[:password])
        @errors = ["Incorrect password. Please try again."]
        return erb :delete_account
      end
    end
    
    user = current_user
    
    begin
      # Clear last selected band reference first
      user.update(last_selected_band_id: nil)
      
      # Handle bands owned by this user (using role-based system)
      owned_user_bands = user.user_bands.where(role: 'owner')
      owned_user_bands.each do |user_band|
        band = user_band.band
        # If band has other members, make the first member an owner if needed
        other_members = band.users.where.not(id: user.id)
        if other_members.any?
          # Check if there are other owners
          other_owners = band.owners.where.not(id: user.id)
          if other_owners.empty?
            # No other owners, make first member an owner
            first_member = other_members.first
            member_user_band = UserBand.find_by(band: band, user: first_member)
            if member_user_band
              member_user_band.update!(role: 'owner')
              # Update owner_id for backward compatibility
              band.update_column(:owner_id, first_member.id)
            end
          end
        else
          # If no other members, delete the band
          # First clear all user associations
          band.users.clear
          band.destroy
        end
      end
      
      # Remove user from all bands
      user.user_bands.destroy_all
      
      # Clear session before deleting user
      session.clear
      
      # Delete the user
      user.destroy
      
      redirect '/login?account_deleted=true'
    rescue => e
      # If something goes wrong, restore the session
      session[:user_id] = user.id
      @errors = ["Failed to delete account. Please try again or contact support."]
      @breadcrumbs = [
        { label: '', url: '/', icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px;"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"></path><polyline points="9,22 9,12 15,12 15,22"></polyline></svg>' },
        { label: 'Profile', url: '/profile', icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px;"><circle cx="12" cy="12" r="3"></circle><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"></path></svg>' },
        { label: 'Delete Account', url: nil, icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px;"><path d="M3 6h18"></path><path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6"></path><path d="M8 6V4c0-1 1-2 2-2h4c0 1 1 2 2H8z"></path><line x1="10" y1="11" x2="10" y2="17"></line><line x1="14" y1="11" x2="14" y2="17"></line></svg>' }
      ]
      erb :delete_account
    end
  end
end