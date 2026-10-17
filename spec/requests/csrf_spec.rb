require_relative '../spec_helper'

RSpec.describe 'CSRF protection', type: :request do
  describe 'POST /login' do
    it 'rejects a browser mutation without an authenticity token' do
      post_without_csrf '/login', username: 'testuser'

      expect(last_response.status).to eq(403)
    end

    it 'accepts a browser mutation with the form authenticity token' do
      get '/login'
      token = last_response.body[/name="authenticity_token" value="([^"]+)"/, 1]

      post '/login', username: 'testuser', authenticity_token: token

      expect(last_response.status).to eq(200)
    end
  end

  describe 'POST /api/auth/login' do
    it 'does not confuse an authentication failure with a CSRF rejection' do
      post '/api/auth/login', username: 'testuser'

      expect(last_response.status).to eq(401)
      expect(JSON.parse(last_response.body)).to include('error' => 'Invalid username or password')
    end
  end

  describe 'POST /band/:slug/songs/:id/upvote' do
    it 'allows unauthenticated public voting without an authenticity token' do
      band = create(:band, public_songs_enabled: true)
      song = create(:song)
      band.songs << song

      post_without_csrf "/band/#{band.slug}/songs/#{song.id}/upvote"

      expect(last_response.status).to eq(302)
    end
  end
end
