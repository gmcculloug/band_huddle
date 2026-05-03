require 'sinatra/base'
require 'icalendar'

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

  # GET /members/:slug/gigs/:gig_id/calendar.ics - Download iCalendar file
  get '/members/:slug/gigs/:gig_id/calendar.ics' do
    # Lookup by slug
    user = User.find_by(slug: params[:slug])

    if user.nil? || !user.public_profile_enabled?
      status 404
      return 'Member profile not found or not public'
    end

    # Find the gig and verify the user is a member of the band
    gig = Gig.joins(:band)
                 .joins("INNER JOIN user_bands ON user_bands.band_id = bands.id")
                 .where('user_bands.user_id = ?', user.id)
                 .where('bands.public_schedule_enabled = ?', true)
                 .where('gigs.id = ?', params[:gig_id])
                 .includes(:venue, :band)
                 .first

    if gig.nil?
      status 404
      return 'Gig not found'
    end

    # Don't allow calendar downloads for private events
    if gig.private_event
      status 404
      return 'Calendar not available for private events'
    end

    band = gig.band

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
      description_parts << "Artist: #{user.display_name}"
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
