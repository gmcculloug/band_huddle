require 'sinatra/base'

module Routes
end

class Routes::PublicSchedule < Sinatra::Base
  configure do
    set :views, File.join(File.dirname(__FILE__), '..', '..', 'views')
  end

  helpers ApplicationHelpers

  # ============================================================================
  # PUBLIC SCHEDULE ROUTES
  # No authentication required - these are public endpoints
  # ============================================================================

  # GET /schedule/:slug - Public HTML schedule view
  get '/schedule/:slug' do
    band = Band.find_by(slug: params[:slug])

    if band.nil? || !band.public_schedule_enabled?
      return erb :public_schedule_not_found, layout: :public_layout
    end

    @band = band
    today = Date.current
    @upcoming_gigs = band.gigs
                        .where('performance_date >= ?', today)
                        .includes(:venue)
                        .order(:performance_date)

    erb :public_schedule, layout: :public_layout
  end

  # GET /api/public/bands/:slug/schedule - Public JSON API for fans
  get '/api/public/bands/:slug/schedule' do
    content_type :json

    band = Band.find_by(slug: params[:slug])

    if band.nil? || !band.public_schedule_enabled?
      status 404
      return { error: 'Schedule not found or not public' }.to_json
    end

    today = Date.current
    gigs = band.gigs
               .where('performance_date >= ?', today)
               .includes(:venue)
               .order(:performance_date)

    {
      band: {
        id: band.id,
        name: band.name
      },
      gigs: gigs.map { |gig|
        entry = {
          id: gig.id,
          name: gig.name,
          performance_date: gig.performance_date.iso8601,
          private_event: gig.private_event
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