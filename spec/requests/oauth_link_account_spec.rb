require_relative '../spec_helper'

RSpec.describe 'OAuth account linking', type: :request do
  let(:account_password) { 'password123' }
  let(:wrong_password) { 'not-the-account-password' }
  let!(:local_user) { create(:user, email: 'existing@example.com', password: account_password) }

  def stub_github_callback(user_info)
    allow(OauthService).to receive(:exchange_code_for_token).and_return('access_token' => 'test-token')
    allow(OauthService).to receive(:fetch_user_info).and_return(user_info)
  end

  def github_callback
    get '/auth/github/callback', { code: 'auth-code' }
  end

  describe 'callback email matching' do
    it 'does not link an unverified provider email to an existing account' do
      stub_github_callback('id' => '99999', 'email' => local_user.email,
                           'email_verified' => false, 'name' => 'Attacker', 'username' => 'attacker')

      github_callback

      expect(last_response.status).to eq(302)
      expect(last_response.headers['Location']).to include('/login?error=')
      expect(local_user.reload.oauth_provider).to be_nil
      expect(local_user.reload.oauth_uid).to be_nil
    end

    it 'requires password confirmation before linking a verified email' do
      stub_github_callback('id' => '99999', 'email' => local_user.email,
                           'email_verified' => true, 'name' => 'Legit User', 'username' => 'legit')

      github_callback

      expect(last_response.status).to eq(302)
      expect(last_response.headers['Location']).to include('/auth/link_account')
      expect(local_user.reload.oauth_provider).to be_nil
    end

    it 'matches a verified email that differs only in case' do
      stub_github_callback('id' => '99999', 'email' => 'Existing@Example.COM',
                           'email_verified' => true, 'name' => 'Legit User', 'username' => 'legit')

      github_callback

      expect(last_response.status).to eq(302)
      expect(last_response.headers['Location']).to include('/auth/link_account')
      expect(local_user.reload.oauth_provider).to be_nil
    end

    it 'does not match when the verified email belongs to no account' do
      stub_github_callback('id' => '99999', 'email' => 'nobody@example.com',
                           'email_verified' => true, 'name' => 'New User', 'username' => 'new')

      github_callback

      expect(last_response.status).to eq(302)
      expect(last_response.headers['Location']).to include('/auth/verify_account_creation_code')
    end
  end

  describe 'Apple callback' do
    it 'passes the whole token response to fetch_user_info' do
      token_data = {
        'access_token' => 'apple-token',
        'user_info' => { 'sub' => 'apple-1', 'email' => 'apple-new@example.com', 'email_verified' => 'true' }
      }
      user_info = { 'id' => 'apple-1', 'email' => 'apple-new@example.com', 'email_verified' => true }

      allow(OauthService).to receive(:exchange_code_for_token).and_return(token_data)
      expect(OauthService).to receive(:fetch_user_info).with('apple', token_data).and_return(user_info)

      get '/auth/apple/callback', { code: 'auth-code' }

      expect(last_response.status).to eq(302)
    end
  end

  describe 'GET /auth/link_account' do
    it 'redirects to login without pending link data' do
      get '/auth/link_account'

      expect(last_response.status).to eq(302)
      expect(last_response.headers['Location']).to include('/login?error=')
    end

    it 'renders the password confirmation form for a pending link' do
      stub_github_callback('id' => '99999', 'email' => local_user.email,
                           'email_verified' => true, 'name' => 'Legit User', 'username' => 'legit')
      github_callback

      get '/auth/link_account'

      expect(last_response).to be_ok
      expect(last_response.body).to include('Confirm Account Link')
      expect(last_response.body).to include(local_user.email)
    end
  end

  describe 'POST /auth/link_account' do
    before do
      stub_github_callback('id' => '99999', 'email' => local_user.email,
                           'email_verified' => true, 'name' => 'Legit User', 'username' => 'legit')
      github_callback
    end

    it 'links the OAuth identity after the correct password' do
      post '/auth/link_account', password: account_password

      expect(last_response.status).to eq(302)
      expect(last_response.headers['Location']).to include('/gigs')
      expect(local_user.reload.oauth_provider).to eq('github')
      expect(local_user.reload.oauth_uid).to eq('99999')
    end

    it 'does not link after an incorrect password' do
      post '/auth/link_account', password: wrong_password

      expect(last_response).to be_ok
      expect(last_response.body).to include('Incorrect password')
      expect(local_user.reload.oauth_provider).to be_nil
    end

    it 'locks out after five incorrect attempts' do
      5.times { post '/auth/link_account', password: wrong_password }

      expect(local_user.reload.oauth_provider).to be_nil

      post '/auth/link_account', password: account_password

      expect(last_response.status).to eq(302)
      expect(last_response.headers['Location']).to include('/login?error=')
      expect(local_user.reload.oauth_provider).to be_nil
    end

    it 'refuses when the account gained an OAuth provider meanwhile' do
      local_user.update!(oauth_provider: 'google', oauth_uid: 'g-1')

      post '/auth/link_account', password: account_password

      expect(last_response.status).to eq(302)
      expect(last_response.headers['Location']).to include('/login?error=')
      expect(local_user.reload.oauth_provider).to eq('google')
      expect(local_user.reload.oauth_uid).to eq('g-1')
    end
  end
end
