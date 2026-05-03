require 'sinatra/base'

module Routes
end

class Routes::MobileAPI < Sinatra::Base
  configure do
    set :views, File.join(File.dirname(__FILE__), '..', '..', 'views')
  end

  helpers ApplicationHelpers

  # ============================================================================
  # MOBILE JWT AUTHENTICATION API
  # ============================================================================

  # JWT-based login for mobile apps
  post '/api/mobile/auth/token' do
    content_type :json

    username = params[:username]
    password = params[:password]

    unless username.present? && password.present?
      status 400
      return { error: 'Username and password are required' }.to_json
    end

    # Find user
    user = User.where('LOWER(username) = ?', username.downcase).first

    if user && user.authenticate(password)
      # Prepare device info for JWT
      device_info = {
        device_type: params[:device_type] || 'mobile',
        device_id: params[:device_id]
      }.compact

      # Generate JWT tokens
      require_relative '../services/jwt_service'
      tokens = JwtService.generate_tokens(user, device_info)

      # Prepare user data
      user_data = {
        id: user.id,
        username: user.username,
        email: user.email,
        timezone: user.timezone,
        oauth_provider: user.oauth_provider
      }

      # Handle band selection
      selected_band = nil
      if user.last_selected_band && user.bands.include?(user.last_selected_band)
        selected_band = user.last_selected_band
      elsif user.bands.any?
        selected_band = user.bands.first
      end

      # Response data
      response_data = {
        user: user_data,
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
      }.merge(tokens)

      {
        success: true,
        data: response_data
      }.to_json
    else
      status 401
      { success: false, error: 'Invalid username or password' }.to_json
    end
  end

  # Refresh JWT access token
  post '/api/mobile/auth/refresh' do
    content_type :json

    refresh_token = params[:refresh_token]

    unless refresh_token.present?
      status 400
      return { error: 'Refresh token is required' }.to_json
    end

    require_relative '../services/jwt_service'
    result = JwtService.refresh_access_token(refresh_token)

    if result
      {
        success: true,
        data: result
      }.to_json
    else
      status 401
      { success: false, error: 'Invalid or expired refresh token' }.to_json
    end
  end

  # Revoke JWT tokens (logout)
  post '/api/mobile/auth/revoke' do
    content_type :json

    # This is primarily client-side token removal since we use stateless JWT
    # The client should remove tokens from local storage
    { success: true, message: 'Logout successful - tokens should be removed from client' }.to_json
  end

  # Validate current JWT token
  get '/api/mobile/auth/validate' do
    require_api_auth
    content_type :json

    {
      valid: true,
      user: {
        id: current_user.id,
        username: current_user.username,
        email: current_user.email,
        timezone: current_user.timezone,
        oauth_provider: current_user.oauth_provider
      },
      current_band: current_band ? {
        id: current_band.id,
        name: current_band.name
      } : nil
    }.to_json
  end

  # ============================================================================
  # MOBILE GIGS API
  # ============================================================================

  # List gigs for current band with pagination
  get '/api/mobile/gigs' do
    require_login
    content_type :json

    begin
      page = (params[:page] || 1).to_i
      per_page = [(params[:per_page] || 20).to_i, 50].min # Cap at 50 per page

      gigs_query = filter_by_current_band(Gig).includes(:venue, gig_songs: :song)

      # Filter by date range if provided
      if params[:start_date]
        gigs_query = gigs_query.where('performance_date >= ?', Date.parse(params[:start_date]))
      end

      if params[:end_date]
        gigs_query = gigs_query.where('performance_date <= ?', Date.parse(params[:end_date]))
      end

      # Order by performance date (upcoming gigs first)
      gigs_query = gigs_query.order(:performance_date, :start_time)

      # Apply pagination
      total_count = gigs_query.count
      gigs = gigs_query.limit(per_page).offset((page - 1) * per_page)

      gigs_data = gigs.map do |gig|
        {
          id: gig.id,
          name: gig.name,
          performance_date: gig.performance_date&.strftime('%Y-%m-%d'),
          start_time: gig.start_time&.strftime('%H:%M'),
          end_time: gig.end_time&.strftime('%H:%M'),
          notes: gig.notes,
          venue: gig.venue ? {
            id: gig.venue.id,
            name: gig.venue.name,
            location: gig.venue.location,
            contact_name: gig.venue.contact_name,
            phone_number: gig.venue.phone_number
          } : nil,
          song_count: gig.songs.count,
          sets_count: gig.gig_songs.maximum(:set_number) || 0,
          estimated_duration: calculate_gig_duration(gig.songs),
          created_at: gig.created_at.iso8601,
          updated_at: gig.updated_at.iso8601
        }
      end

      {
        data: gigs_data,
        meta: {
          total_count: total_count,
          page: page,
          per_page: per_page,
          total_pages: (total_count.to_f / per_page).ceil,
          last_modified: gigs.maximum(:updated_at)&.iso8601
        }
      }.to_json

    rescue Date::Error
      status 400
      { error: 'Invalid date format' }.to_json
    rescue => e
      status 500
      { error: 'Failed to fetch gigs' }.to_json
    end
  end

  # Get detailed gig data
  get '/api/mobile/gigs/:id' do
    require_login
    content_type :json

    begin
      gig = filter_by_current_band(Gig).includes(:venue, gig_songs: { song: :bands }).find(params[:id])

      # Organize songs by sets
      gig_songs_by_set = gig.gig_songs.includes(:song).order(:set_number, :position).group_by(&:set_number)

      sets_data = {}
      gig_songs_by_set.each do |set_number, gig_songs|
        sets_data[set_number] = {
          number: set_number,
          song_count: gig_songs.count,
          estimated_duration: calculate_gig_duration(gig_songs.map(&:song)),
          songs: gig_songs.map.with_index do |gig_song, index|
            song = gig_song.song
            {
              id: song.id,
              gig_song_id: gig_song.id,
              position: gig_song.position,
              title: song.title,
              artist: song.artist,
              key: song.key,
              original_key: song.original_key,
              duration: song.duration,
              tempo: song.tempo,
              notes: song.notes,
              lyrics: song.lyrics,
              url: song.url,
              year: song.year,
              album: song.album,
              genre: song.genre,
              has_transition: gig_song.has_transition,
              transition_type: gig_song.transition_type,
              transition_timing: gig_song.transition_timing,
              transition_notes: gig_song.transition_notes,
              updated_at: song.updated_at.iso8601
            }
          end
        }
      end

      gig_data = {
        id: gig.id,
        name: gig.name,
        notes: gig.notes,
        performance_date: gig.performance_date&.strftime('%Y-%m-%d'),
        start_time: gig.start_time&.strftime('%H:%M'),
        end_time: gig.end_time&.strftime('%H:%M'),
        venue: gig.venue ? {
          id: gig.venue.id,
          name: gig.venue.name,
          location: gig.venue.location,
          contact_name: gig.venue.contact_name,
          phone_number: gig.venue.phone_number,
          website: gig.venue.website,
          notes: gig.venue.notes
        } : nil,
        sets: sets_data,
        total_songs: gig.songs.count,
        estimated_duration: calculate_gig_duration(gig.songs),
        created_at: gig.created_at.iso8601,
        updated_at: gig.updated_at.iso8601
      }

      {
        data: gig_data,
        meta: {
          last_modified: gig.updated_at.iso8601
        }
      }.to_json

    rescue ActiveRecord::RecordNotFound
      status 404
      { error: 'Gig not found' }.to_json
    rescue => e
      status 500
      { error: 'Failed to fetch gig data' }.to_json
    end
  end

  # Create new gig
  post '/api/mobile/gigs' do
    require_login
    content_type :json

    unless current_band
      status 400
      return { error: 'No band selected' }.to_json
    end

    begin
      gig = current_band.gigs.build(
        name: params[:name],
        performance_date: params[:performance_date] ? Date.parse(params[:performance_date]) : nil,
        start_time: params[:start_time],
        end_time: params[:end_time],
        notes: params[:notes],
        venue_id: params[:venue_id]
      )

      if gig.save
        {
          success: true,
          data: {
            id: gig.id,
            name: gig.name,
            performance_date: gig.performance_date&.strftime('%Y-%m-%d'),
            start_time: gig.start_time&.strftime('%H:%M'),
            end_time: gig.end_time&.strftime('%H:%M'),
            notes: gig.notes,
            created_at: gig.created_at.iso8601
          }
        }.to_json
      else
        status 422
        { error: 'Validation failed', details: gig.errors.full_messages }.to_json
      end

    rescue Date::Error
      status 400
      { error: 'Invalid date format' }.to_json
    rescue => e
      status 500
      { error: 'Failed to create gig' }.to_json
    end
  end

  # Update gig
  put '/api/mobile/gigs/:id' do
    require_login
    content_type :json

    begin
      gig = filter_by_current_band(Gig).find(params[:id])

      update_params = {}
      update_params[:name] = params[:name] if params[:name]
      update_params[:performance_date] = Date.parse(params[:performance_date]) if params[:performance_date]
      update_params[:start_time] = params[:start_time] if params[:start_time]
      update_params[:end_time] = params[:end_time] if params[:end_time]
      update_params[:notes] = params[:notes] if params.key?(:notes)
      update_params[:venue_id] = params[:venue_id] if params.key?(:venue_id)

      if gig.update(update_params)
        {
          success: true,
          data: {
            id: gig.id,
            name: gig.name,
            performance_date: gig.performance_date&.strftime('%Y-%m-%d'),
            start_time: gig.start_time&.strftime('%H:%M'),
            end_time: gig.end_time&.strftime('%H:%M'),
            notes: gig.notes,
            updated_at: gig.updated_at.iso8601
          }
        }.to_json
      else
        status 422
        { error: 'Validation failed', details: gig.errors.full_messages }.to_json
      end

    rescue ActiveRecord::RecordNotFound
      status 404
      { error: 'Gig not found' }.to_json
    rescue Date::Error
      status 400
      { error: 'Invalid date format' }.to_json
    rescue => e
      status 500
      { error: 'Failed to update gig' }.to_json
    end
  end

  # Delete gig
  delete '/api/mobile/gigs/:id' do
    require_login
    content_type :json

    begin
      gig = filter_by_current_band(Gig).find(params[:id])
      gig.destroy

      { success: true, message: 'Gig deleted successfully' }.to_json

    rescue ActiveRecord::RecordNotFound
      status 404
      { error: 'Gig not found' }.to_json
    rescue => e
      status 500
      { error: 'Failed to delete gig' }.to_json
    end
  end

  # ============================================================================
  # MOBILE SONGS API
  # ============================================================================

  # List songs for current band with pagination and search
  get '/api/mobile/songs' do
    require_login
    content_type :json

    begin
      page = (params[:page] || 1).to_i
      per_page = [(params[:per_page] || 20).to_i, 50].min

      songs_query = filter_by_current_band(Song)

      # Search functionality
      if params[:search] && !params[:search].empty?
        search_term = "%#{params[:search]}%"
        songs_query = songs_query.where(
          'LOWER(title) LIKE LOWER(?) OR LOWER(artist) LIKE LOWER(?)',
          search_term, search_term
        )
      end

      # Filter by key
      if params[:key] && !params[:key].empty?
        songs_query = songs_query.where(key: params[:key])
      end

      # Filter by genre
      if params[:genre] && !params[:genre].empty?
        songs_query = songs_query.where(genre: params[:genre])
      end

      # Exclude archived songs unless specifically requested
      unless params[:include_archived] == 'true'
        songs_query = songs_query.where(archived: false)
      end

      # Order by title
      songs_query = songs_query.order(:title)

      # Apply pagination
      total_count = songs_query.count
      songs = songs_query.limit(per_page).offset((page - 1) * per_page)

      songs_data = songs.map do |song|
        # Get practice state for current band
        songs_band = song.songs_bands.find { |sb| sb.band_id == current_band&.id }

        {
          id: song.id,
          title: song.title,
          artist: song.artist,
          key: song.key,
          original_key: song.original_key,
          tempo: song.tempo,
          duration: song.duration,
          genre: song.genre,
          year: song.year,
          album: song.album,
          url: song.url,
          notes: song.notes,
          practice_state: songs_band&.practice_state || false,
          practice_state_updated_at: songs_band&.practice_state_updated_at&.iso8601,
          created_at: song.created_at.iso8601,
          updated_at: song.updated_at.iso8601
        }
      end

      {
        data: songs_data,
        meta: {
          total_count: total_count,
          page: page,
          per_page: per_page,
          total_pages: (total_count.to_f / per_page).ceil,
          last_modified: songs.maximum(:updated_at)&.iso8601
        }
      }.to_json

    rescue => e
      status 500
      { error: 'Failed to fetch songs' }.to_json
    end
  end

  # Get detailed song data
  get '/api/mobile/songs/:id' do
    require_login
    content_type :json

    begin
      song = filter_by_current_band(Song).find(params[:id])

      # Get practice state for current band
      songs_band = song.songs_bands.find { |sb| sb.band_id == current_band&.id }

      song_data = {
        id: song.id,
        title: song.title,
        artist: song.artist,
        key: song.key,
        original_key: song.original_key,
        tempo: song.tempo,
        duration: song.duration,
        genre: song.genre,
        year: song.year,
        album: song.album,
        url: song.url,
        notes: song.notes,
        lyrics: song.lyrics,
        practice_state: songs_band&.practice_state || false,
        practice_state_updated_at: songs_band&.practice_state_updated_at&.iso8601,
        archived: song.archived,
        created_at: song.created_at.iso8601,
        updated_at: song.updated_at.iso8601
      }

      {
        data: song_data,
        meta: {
          last_modified: song.updated_at.iso8601
        }
      }.to_json

    rescue ActiveRecord::RecordNotFound
      status 404
      { error: 'Song not found' }.to_json
    rescue => e
      status 500
      { error: 'Failed to fetch song data' }.to_json
    end
  end

  # Create new song
  post '/api/mobile/songs' do
    require_login
    content_type :json

    unless current_band
      status 400
      return { error: 'No band selected' }.to_json
    end

    begin
      song = Song.new(
        title: params[:title],
        artist: params[:artist],
        key: params[:key],
        original_key: params[:original_key],
        tempo: params[:tempo]&.to_i,
        duration: params[:duration],
        genre: params[:genre],
        year: params[:year]&.to_i,
        album: params[:album],
        url: params[:url],
        notes: params[:notes],
        lyrics: params[:lyrics]
      )

      if song.save
        # Associate with current band
        song.bands << current_band

        {
          success: true,
          data: {
            id: song.id,
            title: song.title,
            artist: song.artist,
            key: song.key,
            created_at: song.created_at.iso8601
          }
        }.to_json
      else
        status 422
        { error: 'Validation failed', details: song.errors.full_messages }.to_json
      end

    rescue => e
      status 500
      { error: 'Failed to create song' }.to_json
    end
  end

  # Update song
  put '/api/mobile/songs/:id' do
    require_login
    content_type :json

    begin
      song = filter_by_current_band(Song).find(params[:id])

      update_params = {}
      update_params[:title] = params[:title] if params[:title]
      update_params[:artist] = params[:artist] if params[:artist]
      update_params[:key] = params[:key] if params[:key]
      update_params[:original_key] = params[:original_key] if params.key?(:original_key)
      update_params[:tempo] = params[:tempo]&.to_i if params[:tempo]
      update_params[:duration] = params[:duration] if params.key?(:duration)
      update_params[:genre] = params[:genre] if params.key?(:genre)
      update_params[:year] = params[:year]&.to_i if params[:year]
      update_params[:album] = params[:album] if params.key?(:album)
      update_params[:url] = params[:url] if params.key?(:url)
      update_params[:notes] = params[:notes] if params.key?(:notes)
      update_params[:lyrics] = params[:lyrics] if params.key?(:lyrics)

      if song.update(update_params)
        {
          success: true,
          data: {
            id: song.id,
            title: song.title,
            artist: song.artist,
            key: song.key,
            updated_at: song.updated_at.iso8601
          }
        }.to_json
      else
        status 422
        { error: 'Validation failed', details: song.errors.full_messages }.to_json
      end

    rescue ActiveRecord::RecordNotFound
      status 404
      { error: 'Song not found' }.to_json
    rescue => e
      status 500
      { error: 'Failed to update song' }.to_json
    end
  end

  # ============================================================================
  # MOBILE VENUES API
  # ============================================================================

  # List venues for current band
  get '/api/mobile/venues' do
    require_login
    content_type :json

    begin
      venues = filter_by_current_band(Venue).where(archived: false).order(:name)

      venues_data = venues.map do |venue|
        {
          id: venue.id,
          name: venue.name,
          location: venue.location,
          contact_name: venue.contact_name,
          phone_number: venue.phone_number,
          website: venue.website,
          map_url: venue.map_url,
          notes: venue.notes,
          created_at: venue.created_at.iso8601,
          updated_at: venue.updated_at.iso8601
        }
      end

      {
        data: venues_data,
        meta: {
          total_count: venues.count,
          last_modified: venues.maximum(:updated_at)&.iso8601
        }
      }.to_json

    rescue => e
      status 500
      { error: 'Failed to fetch venues' }.to_json
    end
  end

  # Get detailed venue data
  get '/api/mobile/venues/:id' do
    require_login
    content_type :json

    begin
      venue = filter_by_current_band(Venue).find(params[:id])

      venue_data = {
        id: venue.id,
        name: venue.name,
        location: venue.location,
        contact_name: venue.contact_name,
        phone_number: venue.phone_number,
        website: venue.website,
        map_url: venue.map_url,
        notes: venue.notes,
        created_at: venue.created_at.iso8601,
        updated_at: venue.updated_at.iso8601
      }

      {
        data: venue_data,
        meta: {
          last_modified: venue.updated_at.iso8601
        }
      }.to_json

    rescue ActiveRecord::RecordNotFound
      status 404
      { error: 'Venue not found' }.to_json
    rescue => e
      status 500
      { error: 'Failed to fetch venue data' }.to_json
    end
  end

  # ============================================================================
  # MOBILE SYNC API
  # ============================================================================

  # Get data modification timestamps for sync
  get '/api/mobile/sync/manifest' do
    require_login
    content_type :json

    unless current_band
      status 400
      return { error: 'No band selected' }.to_json
    end

    begin
      manifest = {
        band_id: current_band.id,
        last_modified: {
          gigs: filter_by_current_band(Gig).maximum(:updated_at)&.iso8601,
          songs: filter_by_current_band(Song).maximum(:updated_at)&.iso8601,
          venues: filter_by_current_band(Venue).maximum(:updated_at)&.iso8601,
          band: current_band.updated_at.iso8601
        },
        counts: {
          gigs: filter_by_current_band(Gig).count,
          songs: filter_by_current_band(Song).count,
          venues: filter_by_current_band(Venue).count
        },
        generated_at: Time.current.iso8601
      }

      { data: manifest }.to_json

    rescue => e
      status 500
      { error: 'Failed to generate sync manifest' }.to_json
    end
  end

  # Get changes since timestamp for delta sync
  get '/api/mobile/sync/delta' do
    require_login
    content_type :json

    unless current_band
      status 400
      return { error: 'No band selected' }.to_json
    end

    begin
      since = params[:since] ? Time.parse(params[:since]) : 24.hours.ago

      # Get updated gigs
      updated_gigs = filter_by_current_band(Gig).where('updated_at > ?', since)
                                                 .includes(:venue, gig_songs: :song)
                                                 .limit(100)

      # Get updated songs
      updated_songs = filter_by_current_band(Song).where('updated_at > ?', since).limit(100)

      # Get updated venues
      updated_venues = filter_by_current_band(Venue).where('updated_at > ?', since).limit(50)

      delta_data = {
        since: since.iso8601,
        generated_at: Time.current.iso8601,
        changes: {
          gigs: updated_gigs.map { |gig|
            {
              id: gig.id,
              name: gig.name,
              performance_date: gig.performance_date&.strftime('%Y-%m-%d'),
              updated_at: gig.updated_at.iso8601,
              # Include minimal data for sync
              action: 'update'
            }
          },
          songs: updated_songs.map { |song|
            {
              id: song.id,
              title: song.title,
              artist: song.artist,
              updated_at: song.updated_at.iso8601,
              action: 'update'
            }
          },
          venues: updated_venues.map { |venue|
            {
              id: venue.id,
              name: venue.name,
              updated_at: venue.updated_at.iso8601,
              action: 'update'
            }
          }
        }
      }

      { data: delta_data }.to_json

    rescue ArgumentError
      status 400
      { error: 'Invalid timestamp format' }.to_json
    rescue => e
      status 500
      { error: 'Failed to generate delta sync' }.to_json
    end
  end

  # Helper method from existing API routes
  def calculate_gig_duration(songs)
    total_minutes = songs.sum do |song|
      if song.duration.present? && song.duration.match?(/^\d+:\d+$/)
        parts = song.duration.split(':').map(&:to_i)
        parts[0] + parts[1]/60.0
      else
        0
      end
    end

    if total_minutes > 0
      hours = (total_minutes / 60).to_i
      minutes = (total_minutes % 60).round

      if hours > 0
        "#{hours}h #{minutes}m"
      else
        "#{minutes}m"
      end
    else
      'N/A'
    end
  end
end