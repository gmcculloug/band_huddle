require 'sinatra/base'
require 'net/http'
require 'uri'
require 'json'

module Routes
end

class Routes::Api < Sinatra::Base
  configure do
    set :views, File.join(File.dirname(__FILE__), '..', '..', 'views')
  end
  
  helpers ApplicationHelpers
  
  # ============================================================================
  # API ROUTES
  # ============================================================================

  get '/api/songs' do
    require_login
    content_type :json
    
    if current_band
      songs = filter_by_current_band(Song).order(:title)
    else
      songs = []
    end
    songs.map { |song| { id: song.id, title: song.title, artist: song.artist } }.to_json
  end

  get '/api/lookup_song' do
    require_login
    content_type :json
    
    title = params[:title]
    artist = params[:artist] || ''
    
    if title.blank?
      return { error: 'Title is required' }.to_json
    end
    
    begin
      # First try the mock database for demo purposes
      mock_data = get_mock_song_data(title, artist)
      if mock_data[:found]
        return {
          success: true,
          data: mock_data
        }.to_json
      end
      
      # If not in mock data, try songbpm.com
      # Construct search query for songbpm.com
      query = "#{title} #{artist}".strip
      search_url = "https://songbpm.com/#{URI.encode_www_form_component(title.downcase.gsub(/\s+/, '-'))}"
      
      # Set up HTTP request with proper headers
      uri = URI(search_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      
      request = Net::HTTP::Get.new(uri)
      request['User-Agent'] = 'Mozilla/5.0 (compatible; BandHuddle/1.0)'
      
      response = http.request(request)
      
      if response.code == '200'
        # Parse the HTML response to extract song data
        html = response.body
        song_data = parse_songbpm_response(html, title, artist)
        
        if song_data[:found]
          {
            success: true,
            data: song_data
          }.to_json
        else
          {
            success: false,
            error: 'Song not found on songbpm.com'
          }.to_json
        end
      else
        {
          success: false,
          error: 'Failed to fetch data from songbpm.com'
        }.to_json
      end
    rescue => e
      {
        success: false,
        error: "Lookup failed: #{e.message}"
      }.to_json
    end
  end

  private

  def get_mock_song_data(title, artist)
    # Mock database of popular songs for demonstration
    # In a real implementation, this could be a local database or multiple API sources
    mock_songs = {
      'billie jean' => {
        artist: 'Michael Jackson',
        key: 'F#/Gb',
        tempo: 117,
        duration: '4:54'
      },
      'bohemian rhapsody' => {
        artist: 'Queen',
        key: 'A#/Bb',
        tempo: 72,
        duration: '5:55'
      },
      'hotel california' => {
        artist: 'Eagles',
        key: 'B',
        tempo: 75,
        duration: '6:30'
      },
      'stairway to heaven' => {
        artist: 'Led Zeppelin',
        key: 'A',
        tempo: 82,
        duration: '8:02'
      },
      'sweet child o mine' => {
        artist: 'Guns N\' Roses',
        key: 'D',
        tempo: 125,
        duration: '5:03'
      },
      'wonderwall' => {
        artist: 'Oasis',
        key: 'F#/Gb',
        tempo: 87,
        duration: '4:18'
      },
      'hey jude' => {
        artist: 'The Beatles',
        key: 'F',
        tempo: 75,
        duration: '7:11'
      },
      'imagine' => {
        artist: 'John Lennon',
        key: 'C',
        tempo: 76,
        duration: '3:03'
      },
      'smells like teen spirit' => {
        artist: 'Nirvana',
        key: 'F',
        tempo: 117,
        duration: '5:01'
      },
      'purple rain' => {
        artist: 'Prince',
        key: 'A#/Bb',
        tempo: 110,
        duration: '8:41'
      }
    }
    
    # Normalize title for lookup
    normalized_title = title.downcase.strip
    
    # Look for exact match or partial match
    song_data = mock_songs[normalized_title]
    
    if song_data
      # If artist is provided and doesn't match, don't use this data
      if artist.present? && !artist.downcase.include?(song_data[:artist].downcase.split.first.downcase)
        return { found: false }
      end
      
      {
        found: true,
        artist: song_data[:artist],
        key: song_data[:key],
        tempo: song_data[:tempo],
        duration: song_data[:duration]
      }
    else
      { found: false }
    end
  end

  def parse_songbpm_response(html, title, artist)
    # Simple HTML parsing to extract song information
    # This looks for common patterns in songbpm.com HTML structure
    
    begin
      # Look for BPM information
      bpm_match = html.match(/(\d+)\s*BPM/i)
      tempo = bpm_match ? bpm_match[1].to_i : nil
      
      # Look for key information
      key_match = html.match(/Key[:\s]*([A-G][#♯♭b]?\s*(?:major|minor|maj|min)?)/i)
      key = key_match ? normalize_key(key_match[1].strip) : nil
      
      # Look for duration information
      duration_match = html.match(/(\d{1,2}):(\d{2})/i)
      duration = duration_match ? "#{duration_match[1]}:#{duration_match[2]}" : nil
      
      # Extract artist name from the page if not provided
      if artist.blank?
        artist_match = html.match(/<h2[^>]*>([^<]+)<\/h2>/i) || 
                       html.match(/by\s+([^<\n]+)/i) ||
                       html.match(/artist[:\s]*([^<\n]+)/i)
        artist = artist_match ? artist_match[1].strip : nil
      end
      
      # Check if we found any useful data
      found = tempo || key || duration || artist
      
      {
        found: !!found,
        artist: artist,
        key: key,
        tempo: tempo,
        duration: duration
      }
    rescue => e
      {
        found: false,
        error: "Parsing error: #{e.message}"
      }
    end
  end

  def normalize_key(key_string)
    # Normalize key format to match our application's format
    key_string = key_string.gsub(/♯/, '#').gsub(/♭/, 'b')

    # Remove major/minor designations since our app only stores the root key
    key_string = key_string.gsub(/\s*(major|maj|minor|min|m)\s*/i, '').strip

    # Map common variations to our dropdown format
    key_mappings = {
      'Db' => 'C#/Db',
      'C#' => 'C#/Db',
      'Eb' => 'D#/Eb',
      'D#' => 'D#/Eb',
      'Gb' => 'F#/Gb',
      'F#' => 'F#/Gb',
      'Ab' => 'G#/Ab',
      'G#' => 'G#/Ab',
      'Bb' => 'A#/Bb',
      'A#' => 'A#/Bb'
    }

    key_mappings[key_string] || key_string
  end

  # ============================================================================
  # GIG MODE API ROUTES
  # ============================================================================

  # Get complete gig data for offline caching
  get '/api/gigs/:id/gig_mode' do
    require_login
    content_type :json
    headers['X-Band-Huddle-Offline-Capable'] = 'true'

    begin
      @gig = filter_by_current_band(Gig).includes(:venue, gig_songs: :song).find(params[:id])

      # Build comprehensive gig data
      gig_data = {
        id: @gig.id,
        name: @gig.name,
        notes: @gig.notes,
        performance_date: @gig.performance_date&.strftime('%Y-%m-%d'),
        start_time: @gig.start_time&.strftime('%H:%M'),
        end_time: @gig.end_time&.strftime('%H:%M'),
        venue: @gig.venue ? {
          id: @gig.venue.id,
          name: @gig.venue.name,
          location: @gig.venue.location,
          contact_name: @gig.venue.contact_name,
          phone_number: @gig.venue.phone_number
        } : nil,
        sets: {},
        total_songs: @gig.songs.count,
        estimated_duration: calculate_gig_duration(@gig.songs),
        cached_at: Time.current.iso8601
      }

      # Organize songs by sets with complete data
      gig_songs_by_set = @gig.gig_songs.includes(:song).order(:set_number, :position).group_by(&:set_number)

      gig_songs_by_set.each do |set_number, gig_songs|
        gig_data[:sets][set_number] = {
          number: set_number,
          song_count: gig_songs.count,
          estimated_duration: calculate_gig_duration(gig_songs.map(&:song)),
          songs: gig_songs.map.with_index do |gig_song, index|
            song = gig_song.song
            {
              id: song.id,
              position: index + 1,
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
              transition_data: gig_song.transition_data
            }
          end
        }
      end

      gig_data.to_json

    rescue ActiveRecord::RecordNotFound
      status 404
      { error: 'Gig not found' }.to_json
    rescue => e
      status 500
      { error: 'Failed to fetch gig data' }.to_json
    end
  end

  # Get cache manifest for service worker
  get '/api/gigs/:id/cache_manifest' do
    require_login
    content_type :json

    begin
      @gig = filter_by_current_band(Gig).find(params[:id])

      cache_manifest = {
        gig_id: @gig.id,
        version: Time.current.to_i,
        urls_to_cache: [
          "/gigs/#{@gig.id}/gig_mode",
          "/api/gigs/#{@gig.id}/gig_mode",
          "/gig-mode.css",
          "/gig-mode.js"
        ],
        last_modified: @gig.updated_at.iso8601
      }

      cache_manifest.to_json

    rescue ActiveRecord::RecordNotFound
      status 404
      { error: 'Gig not found' }.to_json
    rescue => e
      status 500
      { error: 'Failed to generate cache manifest' }.to_json
    end
  end

  # Check if gig data has been updated (for cache invalidation)
  get '/api/gigs/:id/last_modified' do
    require_login
    content_type :json

    begin
      @gig = filter_by_current_band(Gig).includes(gig_songs: :song).find(params[:id])

      # Find the most recent modification across gig and its songs
      last_modified = [@gig.updated_at]
      last_modified += @gig.songs.map(&:updated_at)

      {
        gig_id: @gig.id,
        last_modified: last_modified.max.iso8601,
        song_count: @gig.songs.count
      }.to_json

    rescue ActiveRecord::RecordNotFound
      status 404
      { error: 'Gig not found' }.to_json
    rescue => e
      status 500
      { error: 'Failed to check modification date' }.to_json
    end
  end

  # ============================================================================
  # ENHANCED MOBILE GIG MODE API
  # ============================================================================

  # Enhanced gig mode data with practice states and mobile optimizations
  get '/api/gigs/:id/mobile_gig_mode' do
    require_login
    content_type :json

    begin
      @gig = filter_by_current_band(Gig).includes(:venue, gig_songs: { song: :songs_bands }).find(params[:id])

      # Build comprehensive gig data optimized for mobile
      gig_data = {
        id: @gig.id,
        name: @gig.name,
        notes: @gig.notes,
        performance_date: @gig.performance_date&.strftime('%Y-%m-%d'),
        start_time: @gig.start_time&.strftime('%H:%M'),
        end_time: @gig.end_time&.strftime('%H:%M'),
        venue: @gig.venue ? {
          id: @gig.venue.id,
          name: @gig.venue.name,
          location: @gig.venue.location,
          contact_name: @gig.venue.contact_name,
          phone_number: @gig.venue.phone_number,
          website: @gig.venue.website,
          notes: @gig.venue.notes
        } : nil,
        sets: {},
        total_songs: @gig.songs.count,
        estimated_duration: calculate_gig_duration(@gig.songs),
        band: {
          id: current_band.id,
          name: current_band.name,
          member_count: current_band.users.count
        },
        cached_at: Time.current.iso8601,
        last_modified: [@gig.updated_at, @gig.songs.maximum(:updated_at)].compact.max.iso8601
      }

      # Organize songs by sets with complete data including practice states
      gig_songs_by_set = @gig.gig_songs.includes(song: :songs_bands).order(:set_number, :position).group_by(&:set_number)

      gig_songs_by_set.each do |set_number, gig_songs|
        gig_data[:sets][set_number] = {
          number: set_number,
          song_count: gig_songs.count,
          estimated_duration: calculate_gig_duration(gig_songs.map(&:song)),
          songs: gig_songs.map.with_index do |gig_song, index|
            song = gig_song.song

            # Get practice state for current band
            songs_band = song.songs_bands.find { |sb| sb.band_id == current_band.id }

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
              # Enhanced mobile features
              practice_state: songs_band&.practice_state || false,
              practice_state_updated_at: songs_band&.practice_state_updated_at&.iso8601,
              has_transition: gig_song.has_transition,
              transition_type: gig_song.transition_type,
              transition_timing: gig_song.transition_timing,
              transition_notes: gig_song.transition_notes,
              # Mobile display optimizations
              display_key: song.key || song.original_key,
              tempo_display: song.tempo ? "#{song.tempo} BPM" : nil,
              duration_seconds: parse_duration_to_seconds(song.duration),
              updated_at: song.updated_at.iso8601
            }
          end
        }
      end

      gig_data.to_json

    rescue ActiveRecord::RecordNotFound
      status 404
      { error: 'Gig not found' }.to_json
    rescue => e
      status 500
      { error: 'Failed to fetch enhanced gig data' }.to_json
    end
  end

  # Update practice state for a song in the current band
  post '/api/gigs/:gig_id/songs/:song_id/practice_state' do
    require_login
    content_type :json

    begin
      gig = filter_by_current_band(Gig).find(params[:gig_id])
      song = filter_by_current_band(Song).find(params[:song_id])

      # Verify the song is in this gig
      unless gig.songs.include?(song)
        status 400
        return { error: 'Song is not in this gig' }.to_json
      end

      practice_state = params[:practice_state] == true || params[:practice_state] == 'true'

      # Find or create the songs_bands relationship
      songs_band = song.songs_bands.find_by(band_id: current_band.id)
      if songs_band
        songs_band.update!(
          practice_state: practice_state,
          practice_state_updated_at: Time.current
        )
      else
        # This shouldn't happen if the song is properly associated with the band
        status 400
        return { error: 'Song is not associated with current band' }.to_json
      end

      {
        success: true,
        data: {
          song_id: song.id,
          practice_state: practice_state,
          practice_state_updated_at: songs_band.practice_state_updated_at.iso8601
        }
      }.to_json

    rescue ActiveRecord::RecordNotFound
      status 404
      { error: 'Gig or song not found' }.to_json
    rescue => e
      status 500
      { error: 'Failed to update practice state' }.to_json
    end
  end

  # Get real-time updates for band members during gig mode
  get '/api/gigs/:id/live_updates' do
    require_login
    content_type :json

    begin
      gig = filter_by_current_band(Gig).includes(:songs).find(params[:id])
      since = params[:since] ? Time.parse(params[:since]) : 5.minutes.ago

      # Get recently updated practice states
      updated_songs = gig.songs.joins(:songs_bands)
                               .where(songs_bands: { band_id: current_band.id })
                               .where('songs_bands.practice_state_updated_at > ?', since)

      updates = updated_songs.map do |song|
        songs_band = song.songs_bands.find { |sb| sb.band_id == current_band.id }
        {
          song_id: song.id,
          title: song.title,
          practice_state: songs_band.practice_state,
          practice_state_updated_at: songs_band.practice_state_updated_at.iso8601
        }
      end

      {
        data: {
          gig_id: gig.id,
          since: since.iso8601,
          updates: updates,
          generated_at: Time.current.iso8601
        }
      }.to_json

    rescue ActiveRecord::RecordNotFound
      status 404
      { error: 'Gig not found' }.to_json
    rescue ArgumentError
      status 400
      { error: 'Invalid timestamp format' }.to_json
    rescue => e
      status 500
      { error: 'Failed to fetch live updates' }.to_json
    end
  end

  # Get current set position and navigation info for gig mode
  get '/api/gigs/:id/navigation' do
    require_login
    content_type :json

    begin
      gig = filter_by_current_band(Gig).includes(gig_songs: :song).find(params[:id])

      # Organize sets for navigation
      sets_data = {}
      gig_songs_by_set = gig.gig_songs.order(:set_number, :position).group_by(&:set_number)

      total_songs = 0
      gig_songs_by_set.each do |set_number, gig_songs|
        sets_data[set_number] = {
          number: set_number,
          song_count: gig_songs.count,
          start_position: total_songs + 1,
          end_position: total_songs + gig_songs.count,
          songs: gig_songs.map { |gs|
            total_songs += 1
            {
              id: gs.song.id,
              gig_song_id: gs.id,
              position: gs.position,
              overall_position: total_songs,
              title: gs.song.title,
              artist: gs.song.artist,
              key: gs.song.key,
              duration: gs.song.duration,
              has_transition: gs.has_transition,
              transition_type: gs.transition_type
            }
          }
        }
        total_songs -= gig_songs.count # Reset for correct counting
        total_songs += gig_songs.count
      end

      navigation_data = {
        gig_id: gig.id,
        total_sets: sets_data.keys.count,
        total_songs: total_songs,
        sets: sets_data,
        generated_at: Time.current.iso8601
      }

      { data: navigation_data }.to_json

    rescue ActiveRecord::RecordNotFound
      status 404
      { error: 'Gig not found' }.to_json
    rescue => e
      status 500
      { error: 'Failed to fetch navigation data' }.to_json
    end
  end

  private

  def parse_duration_to_seconds(duration)
    return nil unless duration&.match?(/^\d+:\d+$/)

    parts = duration.split(':').map(&:to_i)
    (parts[0] * 60) + parts[1]
  end

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
