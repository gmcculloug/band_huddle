require 'sinatra/base'
require 'icalendar'

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

  # GET /schedule/:slug/gigs/:gig_id/calendar.ics - Download iCalendar file
  get '/schedule/:slug/gigs/:gig_id/calendar.ics' do
    band = Band.find_by(slug: params[:slug])

    if band.nil? || !band.public_schedule_enabled?
      status 404
      return 'Schedule not found or not public'
    end

    gig = band.gigs.find_by(id: params[:gig_id])

    if gig.nil?
      status 404
      return 'Gig not found'
    end

    # Don't allow calendar downloads for private events
    if gig.private_event
      status 404
      return 'Calendar not available for private events'
    end

    # Create iCalendar
    cal = Icalendar::Calendar.new

    # Build event
    cal.event do |e|
      # Event summary (title) - band name first, then venue
      if gig.venue
        summary = "#{band.name} - #{gig.venue.name}"
      else
        summary = "#{band.name} - #{gig.name}"
      end
      e.summary = summary

      # Start and end times
      if gig.start_time
        # Store times in UTC in the database, use them directly for the calendar
        e.dtstart = Icalendar::Values::DateTime.new(gig.start_time, 'tzid' => 'UTC')
        if gig.end_time
          e.dtend = Icalendar::Values::DateTime.new(gig.end_time, 'tzid' => 'UTC')
        else
          # Default to 2 hours if no end time
          e.dtend = Icalendar::Values::DateTime.new(gig.start_time + 2.hours, 'tzid' => 'UTC')
        end
      else
        # All-day event if no time specified
        e.dtstart = Icalendar::Values::Date.new(gig.performance_date)
        e.dtend = Icalendar::Values::Date.new(gig.performance_date + 1.day)
      end

      # Location
      if gig.venue
        location_parts = []
        location_parts << gig.venue.name if gig.venue.name.present?
        location_parts << gig.venue.location if gig.venue.location.present?
        e.location = location_parts.join(', ') if location_parts.any?

        # Add URL if venue has a website
        e.url = gig.venue.website if gig.venue.website.present?
      end

      # Description
      description_parts = []
      description_parts << "Band: #{band.name}"
      description_parts << "Event: #{gig.name}"
      if gig.venue
        description_parts << "Venue: #{gig.venue.name}" if gig.venue.name.present?
        description_parts << "Location: #{gig.venue.location}" if gig.venue.location.present?
        description_parts << "Website: #{gig.venue.website}" if gig.venue.website.present?
      end
      e.description = description_parts.join("\n")

      # Unique ID
      e.uid = "gig-#{gig.id}@band-huddle"
      e.created = gig.created_at if gig.respond_to?(:created_at)
      e.last_modified = gig.updated_at if gig.respond_to?(:updated_at)
    end

    # Set calendar metadata
    cal.prodid = '-//Band Huddle//Schedule//EN'
    cal.append_custom_property('X-WR-CALNAME', "#{band.name} - #{gig.name}")

    # Return as .ics file
    content_type 'text/calendar; charset=utf-8'
    attachment "#{band.name.gsub(/[^0-9A-Za-z]/, '_')}_#{gig.name.gsub(/[^0-9A-Za-z]/, '_')}.ics"
    cal.to_ical
  end
end