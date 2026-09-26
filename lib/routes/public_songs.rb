require 'sinatra/base'
require 'uri'

module Routes
end

class Routes::PublicSongs < Sinatra::Base
  configure do
    set :views, File.join(File.dirname(__FILE__), '..', '..', 'views')
  end

  helpers ApplicationHelpers

  # ============================================================================
  # PUBLIC SONGS ROUTES
  # No authentication required - these are public endpoints
  # ============================================================================

  # GET /band/:slug/songs - Public HTML songs view
  get '/band/:slug/songs' do
    band = Band.find_by(slug: params[:slug])

    if band.nil? || !band.public_songs_enabled?
      return erb :public_songs_not_found, layout: :public_layout
    end

    @band = band
    @view_by = %w[artist votes].include?(params[:by]) ? params[:by] : 'title'
    @songs = songs_for_band_view(band, @view_by)
    @voted_song_ids = voted_song_ids_for(device_id, band, @songs)

    erb :public_songs, layout: :public_layout
  end

  # GET /band/:slug/songs/vote_counts - Public vote counts for lightweight page polling
  get '/band/:slug/songs/vote_counts' do
    content_type :json
    band = Band.find_by(slug: params[:slug])

    unless band&.public_songs_enabled?
      status 404
      return { error: 'Songs not found' }.to_json
    end

    songs = Song.active.ready_for_band(band)
      .select("songs.id, #{SongBand::VOTES_COUNT_SQL} AS votes_count, songs_bands.total_votes_count AS total_votes_count")
      .to_a
    voted_song_ids = voted_song_ids_for(device_id, band, songs)

    votes = songs.map do |song|
      {
        id: song.id,
        votes_count: song.votes_count,
        total_votes_count: song.total_votes_count,
        voted: voted_song_ids.include?(song.id)
      }
    end

    { votes: votes }.to_json
  end

  # POST /band/:slug/songs/:id/upvote - Public up-vote, visible immediately, resets daily
  post '/band/:slug/songs/:id/upvote' do
    band = Band.find_by(slug: params[:slug])

    if band.nil? || !band.public_songs_enabled?
      return erb :public_songs_not_found, layout: :public_layout
    end

    view_by = %w[artist votes].include?(params[:by]) ? params[:by] : 'title'
    song = Song.active.ready_for_band(band).find_by(id: params[:id])

    if song.nil?
      redirect "/band/#{band.slug}/songs?by=#{view_by}&error=#{URI.encode_www_form_component('Song not found')}"
    elsif SongVote.rate_limited?(device_id, song, band)
      already_voted_message = "You've already voted for this song recently"
      redirect "/band/#{band.slug}/songs?by=#{view_by}&error=#{URI.encode_www_form_component(already_voted_message)}"
    else
      SongVote.create!(song: song, band: band, ip_address: request.ip, device_id: device_id)
      SongBand.record_vote!(song, band)
      redirect "/band/#{band.slug}/songs?by=#{view_by}&voted=#{song.id}"
    end
  end

  # POST /band/:slug/songs/:id/downvote - Public retraction of a same-day up-vote
  post '/band/:slug/songs/:id/downvote' do
    band = Band.find_by(slug: params[:slug])

    if band.nil? || !band.public_songs_enabled?
      return erb :public_songs_not_found, layout: :public_layout
    end

    view_by = %w[artist votes].include?(params[:by]) ? params[:by] : 'title'
    song = Song.active.ready_for_band(band).find_by(id: params[:id])

    if song.nil?
      redirect "/band/#{band.slug}/songs?by=#{view_by}&error=#{URI.encode_www_form_component('Song not found')}"
    elsif !SongVote.voted_today?(device_id, song, band)
      no_vote_message = "You haven't voted for this song today"
      redirect "/band/#{band.slug}/songs?by=#{view_by}&error=#{URI.encode_www_form_component(no_vote_message)}"
    else
      SongVote.retract!(device_id, song, band)
      SongBand.retract_vote!(song, band)
      redirect "/band/#{band.slug}/songs?by=#{view_by}&voted=#{song.id}"
    end
  end

  # POST /band/:slug/songs/recommend - Public song recommendation submission
  post '/band/:slug/songs/recommend' do
    band = Band.find_by(slug: params[:slug])

    if band.nil? || !band.public_songs_enabled?
      return erb :public_songs_not_found, layout: :public_layout
    end

    # Honeypot: hidden field only bots fill in. Pretend success, never persist.
    if params[:website].to_s.strip != ''
      redirect "/band/#{band.slug}/songs?success=#{URI.encode_www_form_component('Thanks for your recommendation!')}"
    end

    if SongRecommendation.rate_limited?(device_id) || SongRecommendation.pending_limit_reached?(band)
      redirect "/band/#{band.slug}/songs?error=#{URI.encode_www_form_component('Unable to accept recommendations right now. Please try again later.')}"
    end

    rec = SongRecommendation.new(
      band: band,
      title: params[:title],
      artist: params[:artist],
      notes: params[:notes],
      ip_address: request.ip,
      device_id: device_id
    )

    if rec.save
      redirect "/band/#{band.slug}/songs?success=#{URI.encode_www_form_component('Thanks for your recommendation!')}"
    else
      @band = band
      @view_by = %w[artist votes].include?(params[:by]) ? params[:by] : 'title'
      @songs = songs_for_band_view(band, @view_by)
      @voted_song_ids = voted_song_ids_for(device_id, band, @songs)
      @recommend_errors = rec.errors.full_messages
      erb :public_songs, layout: :public_layout
    end
  end

  private

  def voted_song_ids_for(device_id, band, songs)
    return [].to_set if songs.empty?

    SongVote.where(song_id: songs.map(&:id), band: band, device_id: device_id, created_at: 1.day.ago..)
      .distinct
      .pluck(:song_id)
      .to_set
  end

  def songs_for_band_view(band, view_by)
    songs = Song.active.ready_for_band(band)
      .select("songs.*, #{SongBand::VOTES_COUNT_SQL} AS votes_count, songs_bands.total_votes_count AS total_votes_count")

    case view_by
    when 'artist'
      songs.order(Arel.sql('LOWER(artist), LOWER(title)'))
    when 'votes'
      songs.order(Arel.sql("#{SongBand::VOTES_COUNT_SQL} DESC, LOWER(title)"))
    else
      songs.order(Arel.sql('LOWER(title)'))
    end
  end
end
