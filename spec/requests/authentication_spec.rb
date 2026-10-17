require_relative '../spec_helper'
require 'stringio'

RSpec.describe 'Authentication', type: :request do
  describe 'GET /login' do
    it 'displays the login form' do
      get '/login'
      expect(last_response).to be_ok
      expect(last_response.body).to include('Login to Band Huddle')
      expect(last_response.body).to include('Username:')
      expect(last_response.body).to include('Password:')
    end
  end

  describe 'POST /login' do
    let!(:user) { User.create!(username: 'testuser', password: 'password123') }

    it 'logs in with valid credentials' do
      post '/login', username: 'testuser', password: 'password123'
      expect(last_response.status).to eq(302)
      expect(last_response.headers['Location']).to include('/')
    end

    it 'rejects invalid credentials' do
      post '/login', username: 'testuser', password: 'wrongpassword'
      expect(last_response).to be_ok
      expect(last_response.body).to include('Invalid username or password')
    end

    it 'does not log login credentials' do
      password = SecureRandom.hex(12)
      original_stdout = $stdout
      captured_stdout = StringIO.new
      $stdout = captured_stdout
      user.update!(password: password)

      begin
        post '/api/auth/login', username: 'testuser', password: password
      ensure
        $stdout = original_stdout
      end

      expect(last_response.status).to eq(200)
      expect(captured_stdout.string).not_to include(password)
      expect(captured_stdout.string).not_to include('params:')
    end
  end

  describe 'GET /signup' do
    it 'displays the signup form' do
      get '/signup'
      expect(last_response).to be_ok
      expect(last_response.body).to include('Sign Up for Band Huddle')
      expect(last_response.body).to include('Username:')
      expect(last_response.body).to include('Password:')
      expect(last_response.body).to include('Email Address (Optional):')
      expect(last_response.body).to include('Account Creation Code:')
    end
  end

  describe 'POST /signup' do
    before do
      ENV['BAND_HUDDLE_ACCT_CREATION_SECRET'] = 'test_secret_123'
    end

    after do
      ENV.delete('BAND_HUDDLE_ACCT_CREATION_SECRET')
    end

    it 'creates a new user with valid data and correct account creation code' do
      expect {
        post '/signup', username: 'newuser', password: 'password123', email: 'test@example.com', login_secret: 'test_secret_123'
      }.to change(User, :count).by(1)
      
      expect(last_response.status).to eq(302)
      expect(last_response.headers['Location']).to include('/')
    end

    it 'rejects signup with incorrect account creation code' do
      expect {
        post '/signup', username: 'newuser', password: 'password123', email: 'test@example.com', login_secret: 'wrong_secret'
      }.not_to change(User, :count)
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('Invalid account creation code')
    end

    it 'rejects signup without account creation code' do
      expect {
        post '/signup', username: 'newuser', password: 'password123', email: 'test@example.com'
      }.not_to change(User, :count)
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('Invalid account creation code')
    end

    it 'rejects invalid data' do
      post '/signup', username: '', password: '123', login_secret: 'test_secret_123'
      expect(last_response).to be_ok
      expect(last_response.body).to include('can\'t be blank')
    end

    it 'rejects signup when BAND_HUDDLE_ACCT_CREATION_SECRET environment variable is not set' do
      ENV.delete('BAND_HUDDLE_ACCT_CREATION_SECRET')
      
      expect {
        post '/signup', username: 'newuser', password: 'password123', email: 'test@example.com', login_secret: 'any_secret'
      }.not_to change(User, :count)
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('Account creation code not configured')
    end
  end

  describe 'POST /logout' do
    it 'logs out the user' do
      clear_cookies
      user = User.create!(username: 'testuser', password: 'password123', email: 'test@example.com')
      post '/login', username: 'testuser', password: 'password123'
      
      post '/logout'
      expect(last_response.status).to eq(302)
      expect(last_response.headers['Location']).to include('/login')
    end

    it 'requires authentication' do
      post '/logout'

      expect(last_response.status).to eq(302)
      expect(last_response.headers['Location']).to include('/login')
    end

    it 'requires an authenticity token' do
      user = User.create!(username: 'testuser', password: 'password123', email: 'test@example.com')
      post '/login', username: 'testuser', password: 'password123'

      post_without_csrf '/logout'

      expect(last_response.status).to eq(403)
    end
  end

  describe 'protected routes' do
    it 'redirects to login when not authenticated' do
      get '/'
      expect(last_response.status).to eq(302)
      expect(last_response.headers['Location']).to include('/login')
      
      get '/songs'
      expect(last_response.status).to eq(302)
      expect(last_response.headers['Location']).to include('/login')
      
      get '/gigs'
      expect(last_response.status).to eq(302)
      expect(last_response.headers['Location']).to include('/login')
    end
  end

  describe 'Account deletion' do
    let(:user) { create(:user, username: 'testuser', password: 'password123', email: 'test@example.com') }
    let(:band) { create(:band, name: 'Test Band', owner: user) }

    before do
      login_as(user, band)
    end

    describe 'GET /account/delete' do
      it 'displays the delete account form' do
        get '/account/delete'
        expect(last_response).to be_ok
        expect(last_response.body).to include('Delete Account')
        expect(last_response.body).to include('Permanently Delete My Account')
      end

      it 'displays breadcrumbs navigation' do
        get '/account/delete'
        expect(last_response).to be_ok
        expect(last_response.body).to include('<nav class="breadcrumbs"')
        expect(last_response.body).to include('Profile')
        expect(last_response.body).to include('Delete Account')
      end

      it 'displays SVG wireframe icons in breadcrumbs' do
        get '/account/delete'
        expect(last_response).to be_ok
        # Check for SVG home icon
        expect(last_response.body).to include('<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor"')
        expect(last_response.body).to include('<path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"')
        # Check for SVG profile/settings icon
        expect(last_response.body).to include('<circle cx="12" cy="12" r="3"')
        # Check for SVG trash/delete icon
        expect(last_response.body).to include('<path d="M3 6h18"')
        expect(last_response.body).to include('<path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6"')
      end
    end

    describe 'POST /account/delete' do
      it 'deletes the account with correct password' do
        post '/account/delete', password: 'password123'
        
        expect(last_response.status).to eq(302)
        expect(last_response.headers['Location']).to include('/login?account_deleted=true')
      end

      it 'rejects deletion with incorrect password' do
        expect {
          post '/account/delete', password: 'wrongpassword'
        }.not_to change(User, :count)
        
        expect(last_response).to be_ok
        expect(last_response.body).to include('Incorrect password')
      end

      it 'rejects deletion without password' do
        expect {
          post '/account/delete', password: ''
        }.not_to change(User, :count)
        
        expect(last_response).to be_ok
        expect(last_response.body).to include('Incorrect password')
      end

      it 'removes user from bands when deleting account' do
        expect {
          post '/account/delete', password: 'password123'
        }.to change(UserBand, :count).by(-1)
        
        expect(last_response.status).to eq(302)
        # Check that the band was deleted since user was the only member and owner
        expect(Band.find_by(id: band.id)).to be_nil
      end
    end
  end

  describe 'User Profile' do
    let!(:user) { User.create!(username: 'testuser', password: 'password123', email: 'test@example.com') }

    before do
      post '/login', username: 'testuser', password: 'password123'
    end

    describe 'GET /profile' do
      it 'displays the profile page' do
        get '/profile'
        expect(last_response).to be_ok
        expect(last_response.body).to include('User Profile')
        expect(last_response.body).to include('testuser')
        expect(last_response.body).to include('test@example.com')
      end

      it 'displays breadcrumbs navigation' do
        get '/profile'
        expect(last_response).to be_ok
        expect(last_response.body).to include('<nav class="breadcrumbs"')
        expect(last_response.body).to include('Profile')
      end

      it 'displays SVG wireframe icons in breadcrumbs' do
        get '/profile'
        expect(last_response).to be_ok
        # Check for SVG home icon
        expect(last_response.body).to include('<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor"')
        expect(last_response.body).to include('<path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"')
        # Check for SVG profile/settings icon
        expect(last_response.body).to include('<circle cx="12" cy="12" r="3"')
      end
    end

    describe 'PUT /profile' do
      it 'updates user email successfully' do
        put '/profile', user: { email: 'newemail@example.com' }
        expect(last_response).to be_ok
        expect(last_response.body).to include('Profile updated successfully!')
        
        user.reload
        expect(user.email).to eq('newemail@example.com')
      end

      it 'rejects invalid email format' do
        put '/profile', user: { email: 'invalid-email' }
        expect(last_response).to be_ok
        expect(last_response.body).to include('Email is invalid')
      end
    end

    describe 'POST /profile/change_password' do
      it 'changes password successfully' do
        post '/profile/change_password', 
          current_password: 'password123',
          new_password: 'newpassword123',
          confirm_password: 'newpassword123'
        
        expect(last_response).to be_ok
        expect(last_response.body).to include('Password changed successfully!')
        
        # Verify new password works
        clear_cookies
        post '/login', username: 'testuser', password: 'newpassword123'
        expect(last_response.status).to eq(302)
        expect(last_response.headers['Location']).to include('/')
      end

      it 'rejects incorrect current password' do
        post '/profile/change_password', 
          current_password: 'wrongpassword',
          new_password: 'newpassword123',
          confirm_password: 'newpassword123'
        
        expect(last_response).to be_ok
        expect(last_response.body).to include('Current password is incorrect')
      end

      it 'rejects mismatched new passwords' do
        post '/profile/change_password', 
          current_password: 'password123',
          new_password: 'newpassword123',
          confirm_password: 'differentpassword'
        
        expect(last_response).to be_ok
        expect(last_response.body).to include('New passwords don\'t match')
      end

      it 'rejects password that is too short' do
        post '/profile/change_password', 
          current_password: 'password123',
          new_password: '123',
          confirm_password: '123'
        
        expect(last_response).to be_ok
        expect(last_response.body).to include('Password is too short')
      end
    end
  end
end
