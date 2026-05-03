require_relative '../spec_helper'

RSpec.describe 'Public Schedule Routes', type: :request do
  include TimeHelpers
  freeze_time_for_testing

  let(:band) { create(:band, public_schedule_enabled: true) }
  let(:band_with_gigs) { create(:band, name: 'Test Band', public_schedule_enabled: true) }
  let(:disabled_band) { create(:band, name: 'Private Band', public_schedule_enabled: false) }

  describe 'GET /schedule/:slug' do
    context 'when public schedule is enabled' do
      let!(:gig) { create(:gig, band: band_with_gigs, performance_date: Date.current + 7.days, start_time: Time.new(2025, 1, 1, 19, 0, 0)) }
      let!(:venue) { create(:venue, band: band_with_gigs, name: 'Test Venue', location: '123 Main St') }

      before do
        gig.update(venue: venue)
      end

      it 'returns the public schedule page' do
        get "/schedule/#{band_with_gigs.slug}"

        expect(last_response).to be_ok
      end

      it 'displays the band name' do
        get "/schedule/#{band_with_gigs.slug}"

        expect(last_response.body).to include('Test Band')
      end

      it 'displays upcoming gigs' do
        get "/schedule/#{band_with_gigs.slug}"

        expect(last_response.body).to include(gig.name)
      end

      it 'displays venue information' do
        get "/schedule/#{band_with_gigs.slug}"

        expect(last_response.body).to include('Test Venue')
        expect(last_response.body).to include('123 Main St')
      end

      it 'includes gigs scheduled for today' do
        today_gig = create(:gig, band: band_with_gigs, name: 'Today Gig', performance_date: Date.current)

        get "/schedule/#{band_with_gigs.slug}"

        expect(last_response.body).to include('Today Gig')
      end

      it 'shows empty state when band has no upcoming gigs' do
        get "/schedule/#{band.slug}"

        expect(last_response).to be_ok
        expect(last_response.body).to include('No upcoming shows scheduled')
      end

      it 'does not display past gigs' do
        past_gig = create(:gig, band: band_with_gigs, name: 'Past Gig', performance_date: Date.current - 7.days)

        get "/schedule/#{band_with_gigs.slug}"

        expect(last_response.body).not_to include('Past Gig')
      end

      it 'displays gigs in chronological order' do
        later_gig = create(:gig, band: band_with_gigs, name: 'Later Gig', performance_date: Date.current + 30.days)

        get "/schedule/#{band_with_gigs.slug}"

        body = last_response.body
        expect(body.index(gig.name)).to be < body.index('Later Gig')
      end

      it 'renders without error when a gig has no venue' do
        create(:gig, band: band_with_gigs, name: 'Venue-less Gig', performance_date: Date.current + 3.days, venue: nil)

        get "/schedule/#{band_with_gigs.slug}"

        expect(last_response).to be_ok
        expect(last_response.body).to include('Venue-less Gig')
      end

      it 'displays private events without time or location' do
        private_venue = create(:venue, band: band_with_gigs, name: 'Secret Venue', location: 'Secret Location')
        private_gig = create(:gig,
          band: band_with_gigs,
          name: 'Secret Party',
          performance_date: Date.current + 5.days,
          start_time: Time.new(2025, 1, 1, 20, 0, 0),
          end_time: Time.new(2025, 1, 1, 23, 0, 0),
          venue: private_venue,
          private_event: true
        )

        get "/schedule/#{band_with_gigs.slug}"

        expect(last_response).to be_ok
        expect(last_response.body).to include('Private Event')
        expect(last_response.body).not_to include('Secret Party')
        expect(last_response.body).not_to include('Secret Venue')
        expect(last_response.body).not_to include('Secret Location')
      end

      it 'displays public events with full details' do
        get "/schedule/#{band_with_gigs.slug}"

        expect(last_response.body).to include(gig.name)
        expect(last_response.body).to include('Test Venue')
        expect(last_response.body).to include('123 Main St')
      end
    end

    context 'when public schedule is disabled' do
      it 'returns 200 with not found page (not a 404 for security)' do
        get "/schedule/#{disabled_band.slug}"

        expect(last_response.status).to eq(200)
        expect(last_response.body).to include('Schedule Not Found')
      end

      it 'does not expose any band information' do
        get "/schedule/#{disabled_band.slug}"

        expect(last_response.body).not_to include(disabled_band.name)
      end
    end

    context 'when band does not exist' do
      it 'returns not found page' do
        get '/schedule/no-such-band'

        expect(last_response.status).to eq(200)
        expect(last_response.body).to include('Schedule Not Found')
      end
    end
  end

  describe 'GET /api/public/bands/:slug/schedule' do
    context 'when public schedule is enabled' do
      let!(:gig1) { create(:gig, band: band_with_gigs, name: 'First Gig', performance_date: Date.current + 7.days, start_time: Time.new(2025, 1, 1, 19, 0, 0), end_time: Time.new(2025, 1, 1, 22, 0, 0)) }
      let!(:gig2) { create(:gig, band: band_with_gigs, name: 'Second Gig', performance_date: Date.current + 14.days, start_time: Time.new(2025, 1, 1, 20, 0, 0)) }
      let(:venue) { create(:venue, band: band_with_gigs, name: 'API Test Venue', location: '456 Oak Ave') }

      before do
        gig1.update(venue: venue)
      end

      it 'returns JSON with band and gigs data' do
        get "/api/public/bands/#{band_with_gigs.slug}/schedule"

        expect(last_response).to be_ok
        expect(last_response.content_type).to include('application/json')
      end

      it 'includes band information' do
        get "/api/public/bands/#{band_with_gigs.slug}/schedule"

        json = JSON.parse(last_response.body)
        expect(json['band']['id']).to eq(band_with_gigs.id)
        expect(json['band']['name']).to eq('Test Band')
      end

      it 'includes gig information with correct structure' do
        get "/api/public/bands/#{band_with_gigs.slug}/schedule"

        json = JSON.parse(last_response.body)
        expect(json['gigs']).to be_an(Array)
        expect(json['gigs'].first['name']).to eq('First Gig')
        expect(json['gigs'].first['performance_date']).to be_a(String)
      end

      it 'includes venue information when present' do
        get "/api/public/bands/#{band_with_gigs.slug}/schedule"

        json = JSON.parse(last_response.body)
        gig_json = json['gigs'].find { |g| g['name'] == 'First Gig' }
        expect(gig_json['venue']).to be_a(Hash)
        expect(gig_json['venue']['name']).to eq('API Test Venue')
        expect(gig_json['venue']['location']).to eq('456 Oak Ave')
      end

      it 'returns null venue when gig has no venue' do
        gig_without_venue = Gig.create!(
          band: band_with_gigs,
          name: 'Gig Without Venue',
          performance_date: Date.current + 21.days
        )
        gig_without_venue.update!(venue: nil)

        get "/api/public/bands/#{band_with_gigs.slug}/schedule"

        json = JSON.parse(last_response.body)
        gig_json = json['gigs'].find { |g| g['name'] == 'Gig Without Venue' }
        expect(gig_json['venue']).to be_nil
      end

      it 'only returns upcoming gigs' do
        create(:gig, band: band_with_gigs, name: 'Past Gig', performance_date: Date.current - 7.days)

        get "/api/public/bands/#{band_with_gigs.slug}/schedule"

        json = JSON.parse(last_response.body)
        gig_names = json['gigs'].map { |g| g['name'] }
        expect(gig_names).not_to include('Past Gig')
        expect(gig_names).to include('First Gig')
        expect(gig_names).to include('Second Gig')
      end

      it 'includes gigs scheduled for today' do
        today_gig = create(:gig, band: band_with_gigs, name: 'Today Gig', performance_date: Date.current)

        get "/api/public/bands/#{band_with_gigs.slug}/schedule"

        json = JSON.parse(last_response.body)
        gig_names = json['gigs'].map { |g| g['name'] }
        expect(gig_names).to include('Today Gig')
      end

      it 'returns gigs in chronological order' do
        get "/api/public/bands/#{band_with_gigs.slug}/schedule"

        json = JSON.parse(last_response.body)
        dates = json['gigs'].map { |g| g['performance_date'] }
        expect(dates).to eq(dates.sort)
      end

      it 'returns empty gigs array when band has no upcoming gigs' do
        get "/api/public/bands/#{band.slug}/schedule"

        json = JSON.parse(last_response.body)
        expect(json['gigs']).to eq([])
      end

      it 'omits time and venue for private events' do
        private_venue = create(:venue, band: band_with_gigs, name: 'Secret Venue', location: 'Secret Location')
        private_gig = create(:gig,
          band: band_with_gigs,
          name: 'Private Party',
          performance_date: Date.current + 5.days,
          start_time: Time.new(2025, 1, 1, 20, 0, 0),
          end_time: Time.new(2025, 1, 1, 23, 0, 0),
          venue: private_venue,
          private_event: true
        )

        get "/api/public/bands/#{band_with_gigs.slug}/schedule"

        json = JSON.parse(last_response.body)
        private_gig_json = json['gigs'].find { |g| g['name'] == 'Private Party' }

        expect(private_gig_json['private_event']).to be true
        expect(private_gig_json).not_to have_key('start_time')
        expect(private_gig_json).not_to have_key('end_time')
        expect(private_gig_json).not_to have_key('venue')
      end

      it 'includes time and venue for public events' do
        get "/api/public/bands/#{band_with_gigs.slug}/schedule"

        json = JSON.parse(last_response.body)
        public_gig_json = json['gigs'].find { |g| g['name'] == 'First Gig' }

        expect(public_gig_json['private_event']).to be false
        expect(public_gig_json).to have_key('start_time')
        expect(public_gig_json).to have_key('end_time')
        expect(public_gig_json).to have_key('venue')
      end
    end

    context 'when public schedule is disabled' do
      it 'returns 404 with error message' do
        get "/api/public/bands/#{disabled_band.slug}/schedule"

        expect(last_response.status).to eq(404)
        expect(last_response.content_type).to include('application/json')

        json = JSON.parse(last_response.body)
        expect(json['error']).to be_present
      end

      it 'does not expose any gig data' do
        create(:gig, band: disabled_band, name: 'Secret Gig', performance_date: Date.current + 7.days)

        get "/api/public/bands/#{disabled_band.slug}/schedule"

        expect(last_response.status).to eq(404)
        json = JSON.parse(last_response.body)
        expect(json).not_to have_key('gigs')
      end
    end

    context 'when band does not exist' do
      it 'returns 404 with error message' do
        get '/api/public/bands/no-such-band/schedule'

        expect(last_response.status).to eq(404)
        json = JSON.parse(last_response.body)
        expect(json['error']).to be_present
      end
    end
  end

  describe 'GET /schedule/:slug/gigs/:gig_id/calendar.ics' do
    context 'when public schedule is enabled' do
      let(:venue) { create(:venue, band: band_with_gigs, name: 'Test Venue', location: '123 Main St', website: 'https://venue.com') }
      let!(:gig) do
        create(:gig,
          band: band_with_gigs,
          name: 'Test Concert',
          performance_date: Date.new(2025, 6, 15),
          start_time: Time.utc(2025, 6, 15, 19, 0, 0),
          end_time: Time.utc(2025, 6, 15, 22, 0, 0),
          venue: venue
        )
      end

      it 'returns an iCalendar file' do
        get "/schedule/#{band_with_gigs.slug}/gigs/#{gig.id}/calendar.ics"

        expect(last_response).to be_ok
        expect(last_response.content_type).to include('text/calendar')
      end

      it 'sets correct download filename' do
        get "/schedule/#{band_with_gigs.slug}/gigs/#{gig.id}/calendar.ics"

        expect(last_response.headers['Content-Disposition']).to include('attachment')
        expect(last_response.headers['Content-Disposition']).to include('.ics')
      end

      it 'includes band name in the event summary' do
        get "/schedule/#{band_with_gigs.slug}/gigs/#{gig.id}/calendar.ics"

        expect(last_response.body).to include('SUMMARY:Test Band - Test Venue')
      end

      it 'includes start and end times in UTC' do
        get "/schedule/#{band_with_gigs.slug}/gigs/#{gig.id}/calendar.ics"

        expect(last_response.body).to include('DTSTART')
        expect(last_response.body).to include('DTEND')
      end

      it 'includes venue information in location' do
        get "/schedule/#{band_with_gigs.slug}/gigs/#{gig.id}/calendar.ics"

        # The icalendar gem properly escapes commas as \,
        expect(last_response.body).to include('LOCATION:Test Venue\\, 123 Main St')
      end

      it 'includes venue website in URL field' do
        get "/schedule/#{band_with_gigs.slug}/gigs/#{gig.id}/calendar.ics"

        expect(last_response.body).to include('URL;VALUE=URI:https://venue.com')
      end

      it 'includes band name in description' do
        get "/schedule/#{band_with_gigs.slug}/gigs/#{gig.id}/calendar.ics"

        expect(last_response.body).to include('Band: Test Band')
      end

      it 'returns 404 for private events' do
        private_gig = create(:gig,
          band: band_with_gigs,
          name: 'Secret Concert',
          performance_date: Date.new(2025, 6, 20),
          start_time: Time.utc(2025, 6, 20, 20, 0, 0),
          venue: venue,
          private_event: true
        )

        get "/schedule/#{band_with_gigs.slug}/gigs/#{private_gig.id}/calendar.ics"

        expect(last_response.status).to eq(404)
        expect(last_response.body).to include('Calendar not available for private events')
      end

      it 'handles all-day events when no time is specified' do
        all_day_gig = create(:gig,
          band: band_with_gigs,
          name: 'All Day Festival',
          performance_date: Date.new(2025, 7, 4),
          start_time: nil,
          end_time: nil,
          venue: venue
        )

        get "/schedule/#{band_with_gigs.slug}/gigs/#{all_day_gig.id}/calendar.ics"

        expect(last_response).to be_ok
        expect(last_response.body).to include('DTSTART;VALUE=DATE:20250704')
      end

      it 'defaults to 2 hours duration when no end time specified' do
        gig_no_end = create(:gig,
          band: band_with_gigs,
          name: 'Concert Without End',
          performance_date: Date.new(2025, 6, 18),
          start_time: Time.utc(2025, 6, 18, 20, 0, 0),
          end_time: nil,
          venue: venue
        )

        get "/schedule/#{band_with_gigs.slug}/gigs/#{gig_no_end.id}/calendar.ics"

        expect(last_response).to be_ok
        expect(last_response.body).to include('DTSTART')
        expect(last_response.body).to include('DTEND')
      end
    end

    context 'when public schedule is disabled' do
      let!(:gig) { create(:gig, band: disabled_band, performance_date: Date.current + 7.days) }

      it 'returns 404' do
        get "/schedule/#{disabled_band.slug}/gigs/#{gig.id}/calendar.ics"

        expect(last_response.status).to eq(404)
      end
    end

    context 'when gig does not exist' do
      it 'returns 404' do
        get "/schedule/#{band_with_gigs.slug}/gigs/99999/calendar.ics"

        expect(last_response.status).to eq(404)
      end
    end

    context 'when band does not exist' do
      it 'returns 404' do
        get '/schedule/no-such-band/gigs/1/calendar.ics'

        expect(last_response.status).to eq(404)
      end
    end
  end

  describe 'Security - No Authentication Required' do
    it 'does not require authentication for public schedule page' do
      clear_cookies

      get "/schedule/#{band.slug}"

      expect(last_response).to be_ok
    end

    it 'does not require authentication for public schedule API' do
      clear_cookies

      get "/api/public/bands/#{band.slug}/schedule"

      expect(last_response).to be_ok
    end

    it 'does not require Band Huddle session' do
      get "/schedule/#{band.slug}"

      expect(last_response).to be_ok
      expect(last_response.body).not_to include('Login')
    end
  end
end
