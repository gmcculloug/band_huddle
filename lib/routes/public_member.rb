require 'sinatra/base'

module Routes
end

class Routes::PublicMember < Sinatra::Base
  configure do
    set :views, File.join(File.dirname(__FILE__), '..', '..', 'views')
  end

  helpers ApplicationHelpers

  # ============================================================================
  # PUBLIC MEMBER ROUTES
  # No authentication required - these are public endpoints
  # ============================================================================

  # GET /members/:slug - Public HTML member profile
  get '/members/:slug' do
    # Lookup by slug
    user = User.find_by(slug: params[:slug])

    # Return "not found" page (status 200) for security if disabled/missing
    if user.nil? || !user.public_profile_enabled?
      return erb :public_member_not_found, layout: :public_layout
    end

    @user = user

    # Get all gigs from bands where:
    # 1. User is a member (through user_bands)
    # 2. Band has public_schedule_enabled = true
    # 3. Performance date >= today
    # Sorted chronologically
    today = Date.current
    @upcoming_gigs = Gig.joins(:band)
                        .joins("INNER JOIN user_bands ON user_bands.band_id = bands.id")
                        .where('user_bands.user_id = ?', user.id)
                        .where('bands.public_schedule_enabled = ?', true)
                        .where('gigs.performance_date >= ?', today)
                        .includes(:venue, :band)
                        .order(:performance_date)

    erb :public_member, layout: :public_layout
  end

  # GET /api/public/members/:slug/schedule - Public JSON API
  get '/api/public/members/:slug/schedule' do
    content_type :json

    # Lookup by slug
    user = User.find_by(slug: params[:slug])

    if user.nil? || !user.public_profile_enabled?
      status 404
      return { error: 'Member profile not found or not public' }.to_json
    end

    today = Date.current
    gigs = Gig.joins(:band)
              .joins("INNER JOIN user_bands ON user_bands.band_id = bands.id")
              .where('user_bands.user_id = ?', user.id)
              .where('bands.public_schedule_enabled = ?', true)
              .where('gigs.performance_date >= ?', today)
              .includes(:venue, :band)
              .order(:performance_date)

    {
      member: {
        username: user.username,
        display_name: user.display_name
      },
      gigs: gigs.map { |gig|
        entry = {
          id: gig.id,
          name: gig.name,
          performance_date: gig.performance_date.iso8601,
          private_event: gig.private_event,
          band: {
            id: gig.band.id,
            name: gig.band.name
          }
        }
        unless gig.private_event
          entry[:start_time] = gig.start_time&.strftime('%H:%M')
          entry[:end_time]   = gig.end_time&.strftime('%H:%M')
          entry[:venue]      = gig.venue ? { name: gig.venue.name, location: gig.venue.location } : nil
        end
        entry
      }
    }.to_json
  end
end
