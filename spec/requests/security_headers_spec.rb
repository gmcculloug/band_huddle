require_relative '../spec_helper'

RSpec.describe 'Security headers', type: :request do
  describe 'GET /login' do
    it 'sets a nonce-based CSP and browser security headers' do
      get '/login'

      csp = last_response.headers['Content-Security-Policy']
      nonce = last_response.body[/nonce="([^"]+)"/, 1]

      expect(last_response).to be_ok
      expect(csp).to include("script-src-elem 'self' 'nonce-#{nonce}'")
      expect(csp).not_to include("script-src-elem 'unsafe-inline'")
      expect(csp).to include("default-src 'self'")
      expect(last_response.headers['Permissions-Policy']).to include('camera=()')
      expect(last_response.headers['Cross-Origin-Opener-Policy']).to eq('same-origin')
      expect(last_response.headers['Cross-Origin-Embedder-Policy']).to eq('require-corp')
      expect(last_response.body).to include('/vendor/flatpickr/flatpickr.js')
      expect(last_response.body).not_to include('cdn.jsdelivr.net')
    end
  end

  describe 'authenticated responses' do
    let(:user) { create(:user) }

    it 'are not persistently cacheable' do
      login_as(user)
      get '/health'

      expect(last_response).to be_ok
      expect(last_response.headers['Cache-Control']).to eq('no-store, private')
      expect(last_response.headers['Pragma']).to eq('no-cache')
      expect(last_response.headers['Expires']).to eq('0')
    end
  end

  describe 'static assets' do
    it 'remain cacheable' do
      get '/vendor/flatpickr/flatpickr.js'

      expect(last_response).to be_ok
      expect(last_response.headers['Cache-Control']).to be_nil
    end
  end
end
