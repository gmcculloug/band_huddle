require_relative '../spec_helper'

RSpec.describe 'Public Song Votes Routes', type: :request do
  let(:band) { create(:band, public_songs_enabled: true) }
  let(:disabled_band) { create(:band, name: 'Private Band', public_songs_enabled: false) }

  def add_song(band, title: 'Song', artist: 'Artist')
    song = create(:song, title: title, artist: artist)
    band.songs << song
    song
  end

  describe 'GET /band/:slug/songs/vote_counts' do
    it 'returns current daily and total counts for the band songs' do
      song = add_song(band)
      SongBand.record_vote!(song, band)
      SongBand.record_vote!(song, band)

      get "/band/#{band.slug}/songs/vote_counts"

      expect(last_response.status).to eq(200)
      expect(last_response.headers['Content-Type']).to include('application/json')
      expect(JSON.parse(last_response.body)['votes']).to eq([
        { 'id' => song.id, 'votes_count' => 2, 'total_votes_count' => 2, 'voted' => false }
      ])
    end

    it 'reports the requesting visitor vote state' do
      song = add_song(band)
      post "/band/#{band.slug}/songs/#{song.id}/upvote"

      get "/band/#{band.slug}/songs/vote_counts"
      expect(JSON.parse(last_response.body)['votes'].first['voted']).to be true

      post "/band/#{band.slug}/songs/#{song.id}/downvote"
      get "/band/#{band.slug}/songs/vote_counts"
      expect(JSON.parse(last_response.body)['votes'].first['voted']).to be false
    end

    it 'does not return vote counts when public songs are disabled' do
      get "/band/#{disabled_band.slug}/songs/vote_counts"

      expect(last_response.status).to eq(404)
      expect(JSON.parse(last_response.body)).to eq('error' => 'Songs not found')
    end
  end

  describe 'POST /band/:slug/songs/:id/upvote' do
    context 'with a fresh vote' do
      it 'increments the vote count and redirects with the voted song id' do
        song = add_song(band)

        post "/band/#{band.slug}/songs/#{song.id}/upvote"

        expect(last_response.status).to eq(302)
        expect(last_response.location).to include("/band/#{band.slug}/songs")
        expect(last_response.location).to include("voted=#{song.id}")

        song_band = SongBand.find_by_song_and_band(song, band)
        expect(song_band.votes_count).to eq(1)
      end

      it 'returns the updated vote state for an asynchronous request' do
        song = add_song(band)

        post "/band/#{band.slug}/songs/#{song.id}/upvote", {}, 'HTTP_ACCEPT' => 'application/json'

        expect(last_response.status).to eq(200)
        expect(JSON.parse(last_response.body)).to eq(
          'success' => true,
          'vote' => {
            'id' => song.id,
            'votes_count' => 1,
            'total_votes_count' => 1,
            'voted' => true
          }
        )
      end

      it 'preserves the sort mode in the redirect' do
        song = add_song(band)

        post "/band/#{band.slug}/songs/#{song.id}/upvote?by=votes"

        expect(last_response.location).to include('by=votes')
      end

      it 'immediately shows the updated count on the public page' do
        song = add_song(band, title: 'Freebird')

        post "/band/#{band.slug}/songs/#{song.id}/upvote"
        get "/band/#{band.slug}/songs"

        expect(last_response.body).to match(/Freebird.*vote-count[^\"]*vote-count--voted[^\"]*">1</m)
      end

      it 'does not display the all-time vote total' do
        song = add_song(band, title: 'Freebird')
        SongBand.where(song_id: song.id, band_id: band.id).update_all(total_votes_count: 41)

        post "/band/#{band.slug}/songs/#{song.id}/upvote"
        get "/band/#{band.slug}/songs"

        expect(last_response.body).not_to include('42 total')
      end
    end

    context 'rate limiting' do
      it 'rejects a second vote for the same song from the same device' do
        song = add_song(band)

        post "/band/#{band.slug}/songs/#{song.id}/upvote"
        post "/band/#{band.slug}/songs/#{song.id}/upvote"

        expect(last_response.location).to include('error=')
        song_band = SongBand.find_by_song_and_band(song, band)
        expect(song_band.votes_count).to eq(1)
      end

      it 'allows different devices on the same IP to vote independently' do
        song = add_song(band)
        device_a = '11111111-1111-4111-8111-111111111111'
        device_b = '22222222-2222-4222-8222-222222222222'
        cookie_name = BandHuddle::DeviceId::COOKIE_NAME

        post "/band/#{band.slug}/songs/#{song.id}/upvote", {},
          'HTTP_COOKIE' => "#{cookie_name}=#{device_a}"
        post "/band/#{band.slug}/songs/#{song.id}/upvote", {},
          'HTTP_COOKIE' => "#{cookie_name}=#{device_b}"

        expect(last_response.location).to include("voted=#{song.id}")
        expect(SongVote.order(:id).last(2).pluck(:device_id)).to eq([device_a, device_b])
        expect(SongBand.find_by_song_and_band(song, band).votes_count).to eq(2)
      end

      it 'allows voting for a different song from the same device' do
        song = add_song(band, title: 'Song A')
        other_song = add_song(band, title: 'Song B')

        post "/band/#{band.slug}/songs/#{song.id}/upvote"
        post "/band/#{band.slug}/songs/#{other_song.id}/upvote"

        expect(last_response.location).to include("voted=#{other_song.id}")
        expect(SongBand.find_by_song_and_band(other_song, band).votes_count).to eq(1)
      end
    end

    context 'daily reset' do
      it 'resets to 1 instead of incrementing a stale prior-day count' do
        song = add_song(band)
        SongBand.record_vote!(song, band)
        SongBand.record_vote!(song, band)
        SongBand.where(song_id: song.id, band_id: band.id).update_all(votes_date: 1.day.ago.to_date)

        post "/band/#{band.slug}/songs/#{song.id}/upvote"

        expect(SongBand.find_by_song_and_band(song, band).votes_count).to eq(1)
      end
    end

    context 'sorting by votes' do
      it 'orders the most-voted song first' do
        low = add_song(band, title: 'Low Votes')
        high = add_song(band, title: 'High Votes')
        SongBand.record_vote!(high, band)

        get "/band/#{band.slug}/songs?by=votes"

        body = last_response.body
        expect(body.index('High Votes')).to be < body.index('Low Votes')
      end
    end

    context 'when the song does not belong to the band' do
      it 'does not increment votes and redirects with an error' do
        other_band = create(:band)
        song = add_song(other_band)

        post "/band/#{band.slug}/songs/#{song.id}/upvote"

        expect(last_response.location).to include('error=')
        expect(SongBand.where(song_id: song.id, band_id: band.id)).to be_empty
      end
    end

    context 'when public songs is disabled' do
      it 'returns the not-found page without recording a vote' do
        song = add_song(disabled_band)

        post "/band/#{disabled_band.slug}/songs/#{song.id}/upvote"

        expect(last_response.status).to eq(200)
        expect(last_response.body).to include('Songs Not Found')
        expect(SongVote.count).to eq(0)
      end
    end

    context 'when band does not exist' do
      it 'returns the not-found page' do
        post '/band/no-such-band/songs/1/upvote'

        expect(last_response.status).to eq(200)
        expect(last_response.body).to include('Songs Not Found')
      end
    end
  end

  describe 'POST /band/:slug/songs/:id/downvote' do
    it "removes the caller's up-vote from today's count" do
      song = add_song(band)
      post "/band/#{band.slug}/songs/#{song.id}/upvote"

      post "/band/#{band.slug}/songs/#{song.id}/downvote"

      expect(last_response.status).to eq(302)
      expect(last_response.location).to include("voted=#{song.id}")
      expect(SongBand.find_by_song_and_band(song, band).votes_count).to eq(0)
    end

    it 'returns the changed count after an asynchronous downvote' do
      song = add_song(band)
      post "/band/#{band.slug}/songs/#{song.id}/upvote"

      post "/band/#{band.slug}/songs/#{song.id}/downvote", {}, 'HTTP_ACCEPT' => 'application/json'

      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body)['vote']).to include(
        'votes_count' => 0,
        'total_votes_count' => 0,
        'voted' => false
      )
    end

    it 'allows voting again after a downvote' do
      song = add_song(band)
      post "/band/#{band.slug}/songs/#{song.id}/upvote"
      post "/band/#{band.slug}/songs/#{song.id}/downvote"

      post "/band/#{band.slug}/songs/#{song.id}/upvote"

      expect(last_response.location).to include("voted=#{song.id}")
      expect(SongBand.find_by_song_and_band(song, band).votes_count).to eq(1)
    end

    it "errors when the caller hasn't voted for the song today" do
      song = add_song(band)

      post "/band/#{band.slug}/songs/#{song.id}/downvote"

      expect(last_response.location).to include('error=')
      expect(SongBand.find_by_song_and_band(song, band).votes_count).to eq(0)
    end

    it 'preserves the sort mode in the redirect' do
      song = add_song(band)
      post "/band/#{band.slug}/songs/#{song.id}/upvote"

      post "/band/#{band.slug}/songs/#{song.id}/downvote?by=votes"

      expect(last_response.location).to include('by=votes')
    end

    context 'when public songs is disabled' do
      it 'returns the not-found page without changing votes' do
        song = add_song(disabled_band)

        post "/band/#{disabled_band.slug}/songs/#{song.id}/downvote"

        expect(last_response.status).to eq(200)
        expect(last_response.body).to include('Songs Not Found')
      end
    end
  end
end
