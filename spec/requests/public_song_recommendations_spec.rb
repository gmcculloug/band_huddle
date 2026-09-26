require_relative '../spec_helper'

RSpec.describe 'Public Song Recommendations Routes', type: :request do
  let(:band) { create(:band, public_songs_enabled: true) }
  let(:disabled_band) { create(:band, name: 'Private Band', public_songs_enabled: false) }

  describe 'POST /band/:slug/songs/recommend' do
    context 'with valid input' do
      it 'creates a pending recommendation and redirects with success' do
        post "/band/#{band.slug}/songs/recommend", title: 'New Song', artist: 'New Artist', notes: 'Great tune'

        expect(last_response.status).to eq(302)
        expect(last_response.location).to include("/band/#{band.slug}/songs")

        rec = SongRecommendation.last
        expect(rec.band).to eq(band)
        expect(rec.title).to eq('New Song')
        expect(rec.artist).to eq('New Artist')
        expect(rec.status).to eq('pending')
      end

      it 'stores the submitter IP address and browser device ID' do
        post "/band/#{band.slug}/songs/recommend", title: 'New Song', artist: 'New Artist'

        recommendation = SongRecommendation.last
        expect(recommendation.ip_address).to be_present
        expect(recommendation.device_id).to match(BandHuddle::DeviceId::UUID_PATTERN)
      end
    end

    context 'with invalid input' do
      it 're-renders the form with errors and does not create a record' do
        post "/band/#{band.slug}/songs/recommend", title: '', artist: ''

        expect(last_response).to be_ok
        expect(last_response.body).to include("can&#39;t be blank")
        expect(SongRecommendation.count).to eq(0)
      end
    end

    context 'honeypot triggered' do
      it 'looks like success but does not persist a record' do
        post "/band/#{band.slug}/songs/recommend", title: 'Bot Song', artist: 'Bot Artist', website: 'http://spam.example'

        expect(last_response.status).to eq(302)
        expect(SongRecommendation.count).to eq(0)
      end
    end

    context 'rate limiting' do
      it 'rejects submissions once the per-device hourly limit is reached' do
        5.times do |n|
          post "/band/#{band.slug}/songs/recommend", title: "Song #{n}", artist: 'Artist'
        end
        expect(SongRecommendation.count).to eq(5)

        post "/band/#{band.slug}/songs/recommend", title: 'One Too Many', artist: 'Artist'

        expect(last_response.status).to eq(302)
        expect(last_response.location).to include('error=')
        expect(SongRecommendation.count).to eq(5)
      end

      it 'applies the recommendation limit independently to devices on the same IP' do
        device_a = '11111111-1111-4111-8111-111111111111'
        device_b = '22222222-2222-4222-8222-222222222222'
        cookie_name = BandHuddle::DeviceId::COOKIE_NAME

        5.times do |n|
          post "/band/#{band.slug}/songs/recommend", { title: "Song #{n}", artist: 'Artist' },
            'HTTP_COOKIE' => "#{cookie_name}=#{device_a}"
        end
        post "/band/#{band.slug}/songs/recommend", { title: 'Another device', artist: 'Artist' },
          'HTTP_COOKIE' => "#{cookie_name}=#{device_b}"

        expect(SongRecommendation.count).to eq(6)
        expect(SongRecommendation.order(:id).last.device_id).to eq(device_b)
      end
    end

    context 'per-band pending cap' do
      it 'rejects submissions once the band has too many pending recommendations' do
        allow(SongRecommendation).to receive(:pending_limit_reached?).and_return(true)

        post "/band/#{band.slug}/songs/recommend", title: 'New Song', artist: 'New Artist'

        expect(last_response.status).to eq(302)
        expect(last_response.location).to include('error=')
        expect(SongRecommendation.count).to eq(0)
      end
    end

    context 'when public songs is disabled' do
      it 'returns the not-found page without persisting anything' do
        post "/band/#{disabled_band.slug}/songs/recommend", title: 'Song', artist: 'Artist'

        expect(last_response.status).to eq(200)
        expect(last_response.body).to include('Songs Not Found')
        expect(SongRecommendation.count).to eq(0)
      end
    end

    context 'when band does not exist' do
      it 'returns the not-found page without persisting anything' do
        post '/band/no-such-band/songs/recommend', title: 'Song', artist: 'Artist'

        expect(last_response.status).to eq(200)
        expect(last_response.body).to include('Songs Not Found')
        expect(SongRecommendation.count).to eq(0)
      end
    end

    context 'malicious input' do
      it 'stores raw input as-is; escaping happens at render time via h()' do
        post "/band/#{band.slug}/songs/recommend", title: '<script>alert(1)</script>', artist: 'Artist'

        rec = SongRecommendation.last
        expect(rec.title).to eq('<script>alert(1)</script>')
        # Rendering (escaped via h()) is covered by the review-page spec.
      end

      it 'truncates overly long input rather than erroring or overflowing the DB column' do
        post "/band/#{band.slug}/songs/recommend", title: 'A' * 5000, artist: 'B' * 5000

        rec = SongRecommendation.last
        expect(rec.title.length).to eq(200)
        expect(rec.artist.length).to eq(200)
      end

      it 'strips newlines and control characters from single-line fields' do
        post "/band/#{band.slug}/songs/recommend", title: "Evil\r\nInjected-Header: x", artist: 'Artist'

        rec = SongRecommendation.last
        expect(rec.title).not_to include("\r")
        expect(rec.title).not_to include("\n")
      end
    end
  end
end
