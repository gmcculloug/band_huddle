require 'sinatra/base'

module Routes
end

class Routes::Bands < Sinatra::Base
  configure do
    set :views, File.join(File.dirname(__FILE__), '..', '..', 'views')
  end
  
  helpers ApplicationHelpers
  
  # ============================================================================
  # BAND ROUTES
  # ============================================================================

  get '/bands' do
    require_login
    @bands = user_bands.order(:name)
    erb :bands
  end

  get '/bands/new' do
    require_login
    erb :new_band
  end

  post '/bands' do
    require_login
    
    band = Band.new(params[:band])
    band.owner = current_user
    
    if band.save
      # Associate the current user with the new band as owner
      UserBand.create!(band: band, user: current_user, role: 'owner')
      
      # Set this as the current band if it's the user's first band
      if current_user.bands.count == 1
        session[:band_id] = band.id
        # Save this as the user's preferred band
        current_user.update(last_selected_band_id: band.id)
        redirect '/gigs'
      else
        redirect '/bands'
      end
    else
      # Use error handling service to set up @errors consistently
      ErrorHandler.setup_form_errors(band, self)
      erb :new_band
    end
  end

  get '/bands/:id' do
    require_login
    @band = user_bands.includes(:user_bands, :owners).find(params[:id])
    @user_bands_by_user_id = @band.user_bands.index_by(&:user_id)
    @breadcrumbs = [
      { label: '', url: '/', icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px;"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"></path><polyline points="9,22 9,12 15,12 15,22"></polyline></svg>' },
      { label: 'Profile', url: '/profile', icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px;"><circle cx="12" cy="12" r="3"></circle><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"></path></svg>' },
      { label: @band.name, url: nil, icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px;"><path d="M9 18V5l12-2v13"></path><circle cx="6" cy="18" r="3"></circle><circle cx="18" cy="16" r="3"></circle></svg>' }
    ]
    erb :show_band
  end

  get '/bands/:id/edit' do
    require_login
    @band = user_bands.includes(:user_bands, :owners).find(params[:id])
    @user_bands_by_user_id = @band.user_bands.index_by(&:user_id)

    # Any band member can edit the band
    unless @band.users.include?(current_user)
      @errors = ["You must be a member of this band to edit it"]
      return erb :show_band
    end

    @breadcrumbs = [
      { label: '', url: '/', icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px;"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"></path><polyline points="9,22 9,12 15,12 15,22"></polyline></svg>' },
      { label: 'Profile', url: '/profile', icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px;"><circle cx="12" cy="12" r="3"></circle><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"></path></svg>' },
      { label: @band.name, url: "/bands/#{@band.id}", icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px;"><path d="M9 18V5l12-2v13"></path><circle cx="6" cy="18" r="3"></circle><circle cx="18" cy="16" r="3"></circle></svg>' },
      { label: 'Edit', url: nil, icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px;"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"></path><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"></path></svg>' }
    ]
    erb :edit_band
  end

  put '/bands/:id' do
    require_login
    @band = user_bands.includes(:user_bands, :owners).find(params[:id])
    @user_bands_by_user_id = @band.user_bands.index_by(&:user_id)
    
    # Any band member can edit the band
    unless @band.users.include?(current_user)
      @errors = ["You must be a member of this band to edit it"]
      return erb :show_band
    end
    
    if @band.update(params[:band])
      redirect "/bands/#{@band.id}"
    else
      # Use error handling service to set up @errors consistently
      ErrorHandler.setup_form_errors(@band, self)
      @breadcrumbs = [
        { label: '', url: '/', icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px;"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"></path><polyline points="9,22 9,12 15,12 15,22"></polyline></svg>' },
        { label: 'Profile', url: '/profile', icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px;"><circle cx="12" cy="12" r="3"></circle><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"></path></svg>' },
        { label: @band.name, url: "/bands/#{@band.id}", icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px;"><path d="M9 18V5l12-2v13"></path><circle cx="6" cy="18" r="3"></circle><circle cx="18" cy="16" r="3"></circle></svg>' },
        { label: 'Edit', url: nil, icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px;"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"></path><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"></path></svg>' }
      ]
      erb :edit_band
    end
  end

  delete '/bands/:id' do
    require_login
    band = user_bands.find(params[:id])
    
    # Only the owner can delete the band
    unless band.owned_by?(current_user)
      @errors = ["Only the band owner can delete this band"]
      return erb :show_band
    end
    
    # If this was the current band, clear the session
    if current_band&.id == band.id
      session[:band_id] = nil
    end
    
    # Remove all user associations with the band
    band.users.clear
    
    # Delete the band
    band.destroy

    redirect '/bands'
  end

  # ============================================================================
  # BAND USER MANAGEMENT ROUTES
  # ============================================================================

  post '/bands/:id/add_user' do
    require_login
    @band = user_bands.includes(:user_bands, :owners).find(params[:id])
    @user_bands_by_user_id = @band.user_bands.index_by(&:user_id)
    
    # Only owners can add users
    unless @band.owned_by?(current_user)
      @user_error = "Only band owners can add new members"
      return erb :edit_band
    end
    
    username = params[:username]&.strip
    
    if username.blank?
      @user_error = "Username cannot be empty"
      return erb :edit_band
    end
    
    # Find user by username (case insensitive)
    user = User.where('LOWER(username) = ?', username.downcase).first
    
    if user.nil?
      @user_error = "User '#{username}' not found"
      return erb :edit_band
    end
    
    if @band.users.include?(user)
      @user_error = "User '#{username}' is already a member of this band"
      return erb :edit_band
    end
    
    # Add user to band with 'member' role by default
    UserBand.create!(band: @band, user: user, role: 'member')
    @band.user_bands.reload
    @user_bands_by_user_id = @band.user_bands.index_by(&:user_id)
    @user_success = "Successfully added '#{username}' to the band"
    
    erb :edit_band
  end

  post '/bands/:id/remove_user' do
    require_login
    @band = user_bands.includes(:user_bands, :owners).find(params[:id])
    @user_bands_by_user_id = @band.user_bands.index_by(&:user_id)
    user_to_remove = User.find(params[:user_id])
    
    # Users can always remove themselves, but only owners can remove other members
    if user_to_remove != current_user && !@band.owned_by?(current_user)
      @user_error = "Only band owners can remove other members"
      return erb :edit_band
    end
    
    # Prevent removing owners (unless it's yourself)
    if user_to_remove != current_user && @band.owner_of?(user_to_remove)
      @user_error = "Cannot remove an owner. Change their role to member first or have them transfer ownership."
      return erb :edit_band
    end
    
    # Prevent removing the last user from the band
    if @band.users.count <= 1
      @user_error = "Cannot remove the last member from the band"
      return erb :edit_band
    end
    
    # Prevent removing the last owner
    if @band.owner_of?(user_to_remove) && @band.owners.count <= 1
      @user_error = "Cannot remove the last owner from the band. Add another owner first."
      return erb :edit_band
    end
    
    user_band = UserBand.find_by(band: @band, user: user_to_remove)
    if user_band
      user_band.destroy
      @band.user_bands.reload
      @user_bands_by_user_id = @band.user_bands.index_by(&:user_id)
      
      if user_to_remove == current_user
        # User is removing themselves - redirect to profile to see updated bands list
        redirect '/profile'
      else
        # Owner removing another user - stay on edit page with success message
        @user_success = "Successfully removed '#{user_to_remove.username}' from the band"
        erb :edit_band
      end
    else
      @user_error = "User is not a member of this band"
      erb :edit_band
    end
  end

  post '/bands/:id/change_membership' do
    require_login
    @band = user_bands.includes(:user_bands, :owners).find(params[:id])
    @user_bands_by_user_id = @band.user_bands.index_by(&:user_id)
    user = User.find(params[:user_id])
    new_role = params[:role]
    
    # Only owners can change membership
    unless @band.owned_by?(current_user)
      @user_error = "Only band owners can change membership roles"
      return erb :edit_band
    end
    
    # Validate role
    unless ['member', 'owner'].include?(new_role)
      @user_error = "Invalid role. Must be 'member' or 'owner'"
      return erb :edit_band
    end
    
    # User must be a member of the band
    user_band = UserBand.find_by(band: @band, user: user)
    unless user_band
      @user_error = "User is not a member of this band"
      return erb :edit_band
    end
    
    # Prevent removing the last owner
    if user_band.owner? && new_role == 'member' && @band.owners.count <= 1
      @user_error = "Cannot remove the last owner from the band. Add another owner first."
      return erb :edit_band
    end
    
    # Update role
    user_band.update!(role: new_role)
    @band.user_bands.reload
    @user_bands_by_user_id = @band.user_bands.index_by(&:user_id)
    
    # Keep owner_id updated for backward compatibility (set to first owner)
    if @band.owners.any?
      @band.update_column(:owner_id, @band.owners.first.id)
    end
    
    role_text = new_role == 'owner' ? 'owner' : 'member'
    @user_success = "Successfully changed '#{user.username}' to #{role_text}"
    
    erb :edit_band
  end

  post '/bands/:id/transfer_ownership' do
    require_login
    @band = user_bands.includes(:user_bands, :owners).find(params[:id])
    @user_bands_by_user_id = @band.user_bands.index_by(&:user_id)
    new_owner = User.find(params[:new_owner_id])
    
    # Only owners can transfer ownership (make someone else an owner)
    unless @band.owned_by?(current_user)
      @user_error = "Only band owners can transfer ownership"
      return erb :edit_band
    end
    
    # New owner must be a member of the band
    user_band = UserBand.find_by(band: @band, user: new_owner)
    unless user_band
      @user_error = "The new owner must be a member of this band"
      return erb :edit_band
    end
    
    # If they're already an owner, nothing to do
    if user_band.owner?
      @user_error = "#{new_owner.username} is already an owner of this band"
      return erb :edit_band
    end
    
    # Make them an owner
    user_band.update!(role: 'owner')
    @band.user_bands.reload
    @user_bands_by_user_id = @band.user_bands.index_by(&:user_id)
    
    # Keep owner_id updated for backward compatibility (set to first owner)
    if @band.owners.any?
      @band.update_column(:owner_id, @band.owners.first.id)
    end
    
    @user_success = "Successfully made '#{new_owner.username}' an owner"
    
    erb :edit_band
  end

  # ============================================================================
  # COPY SONGS TO BAND ROUTES
  # ============================================================================

  get '/bands/:band_id/copy_songs' do
    require_login
    @band = user_bands.find(params[:band_id])

    # Set breadcrumbs
    set_breadcrumbs(
      breadcrumb_for_section('songs'),
      breadcrumb_for_section('song_catalogs'),
      { label: "Copy Songs to #{@band.name}", icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px; margin-right: 6px;"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path></svg>', url: nil }
    )

    @search = params[:search]
    @song_catalogs = SongCatalog.active.order('LOWER(title)')

    # Apply search filter
    if @search.present?
      @song_catalogs = @song_catalogs.search(@search)
    end

    # Exclude songs already copied to this band based on song_catalog_id
    existing_song_catalog_ids = @band.songs.where.not(song_catalog_id: nil).pluck(:song_catalog_id)
    @song_catalogs = @song_catalogs.where.not(id: existing_song_catalog_ids)

    erb :copy_songs_to_band
  end

  post '/bands/:band_id/copy_songs' do
    require_login
    @band = user_bands.find(params[:band_id])
    song_catalog_ids = params[:song_catalog_ids] || []

    copied_count = 0
    song_catalog_ids.each do |song_catalog_id|
      song_catalog = SongCatalog.find(song_catalog_id)
      song = Song.create_from_song_catalog(song_catalog, [@band.id])

      if song.save
        copied_count += 1
      end
    end

    # If copying from a specific song catalog page, redirect back to that song
    if params[:from_song_catalog]
      redirect "/song_catalog/#{params[:from_song_catalog]}?copied=#{copied_count}"
    else
      # Otherwise redirect to the band page (bulk copy)
      redirect "/bands/#{@band.id}?copied=#{copied_count}"
    end
  end

  # ============================================================================
  # GOOGLE CALENDAR INTEGRATION ROUTES
  # ============================================================================

  post '/bands/:id/google_calendar_settings' do
    require_login
    @band = user_bands.includes(:user_bands, :owners).find(params[:id])
    @user_bands_by_user_id = @band.user_bands.index_by(&:user_id)

    # Any band member can configure Google Calendar settings
    unless @band.users.include?(current_user)
      @google_calendar_error = "You must be a member of this band to configure Google Calendar settings"
      return erb :edit_band
    end
    
    # Update Google Calendar settings
    google_calendar_enabled = params[:google_calendar_enabled] == '1'
    google_calendar_id = params[:google_calendar_id]&.strip
    
    if google_calendar_enabled && google_calendar_id.blank?
      @google_calendar_error = "Calendar ID is required when Google Calendar sync is enabled"
      return erb :edit_band
    end
    
    @band.update!(
      google_calendar_enabled: google_calendar_enabled,
      google_calendar_id: google_calendar_id
    )
    
    @google_calendar_success = "Google Calendar settings updated successfully"
    erb :edit_band
  end

  post '/bands/:id/test_google_calendar' do
    require_login
    @band = user_bands.find(params[:id])
    
    unless @band.users.include?(current_user)
      content_type :json
      return { success: false, error: "You must be a member of this band" }.to_json
    end
    
    calendar_id = params[:google_calendar_id]&.strip
    
    if calendar_id.blank?
      content_type :json
      return { success: false, error: "Calendar ID is required" }.to_json
    end
    
    # Temporarily update the band's calendar ID for testing
    original_calendar_id = @band.google_calendar_id
    @band.update!(google_calendar_id: calendar_id, google_calendar_enabled: true)
    
    begin
      result = @band.test_google_calendar_connection
      
      # Restore original calendar ID if test failed
      if !result[:success]
        @band.update!(google_calendar_id: original_calendar_id)
      end
      
      content_type :json
      result.to_json
    rescue => e
      # Restore original calendar ID on error
      @band.update!(google_calendar_id: original_calendar_id)
      
      content_type :json
      { success: false, error: e.message }.to_json
    end
  end

  post '/bands/:id/sync_google_calendar' do
    require_login
    @band = user_bands.find(params[:id])
    
    unless @band.users.include?(current_user)
      content_type :json
      return { success: false, error: "You must be a member of this band" }.to_json
    end
    
    unless @band.google_calendar_enabled?
      content_type :json
      return { success: false, error: "Google Calendar sync is not enabled for this band" }.to_json
    end
    
    begin
      result = @band.sync_all_gigs_to_google_calendar

      content_type :json
      result.to_json
    rescue => e
      content_type :json
      { success: false, error: e.message, synced_count: 0, total_count: 0 }.to_json
    end
  end

  # ============================================================================
  # PUBLIC SCHEDULE SETTINGS ROUTES
  # ============================================================================

  post '/bands/:id/public_schedule_settings' do
    require_login
    @band = user_bands.includes(:user_bands, :owners).find(params[:id])
    @user_bands_by_user_id = @band.user_bands.index_by(&:user_id)

    # Any band member can configure public schedule settings
    unless @band.users.include?(current_user)
      @public_schedule_error = "You must be a member of this band to configure public schedule settings"
      return erb :edit_band
    end

    public_schedule_enabled = params[:public_schedule_enabled] == '1'

    @band.update!(public_schedule_enabled: public_schedule_enabled)

    @public_schedule_success = "Public schedule settings updated successfully"
    erb :edit_band
  end
end