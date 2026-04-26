require 'spec_helper'

RSpec.describe 'Bands API', type: :request do
  let(:user) { create(:user) }
  let(:band) { create(:band, owner: user) }
  
  before do
    # UserBand relationship is automatically created by the band factory
  end
  describe 'GET /bands' do
    it 'returns a list of user bands' do
      login_as(user, band)
      band1 = create(:band, name: 'Band A', owner: user)
      band2 = create(:band, name: 'Band B', owner: user)

      # UserBand relationships are automatically created by the band factory
      
      get '/bands'
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('Band A')
      expect(last_response.body).to include('Band B')
    end

    it 'displays bands in alphabetical order' do
      login_as(user, band)
      band_c = create(:band, name: 'C Band', owner: user)
      band_a = create(:band, name: 'A Band', owner: user)
      band_b = create(:band, name: 'B Band', owner: user)

      # UserBand relationships are automatically created by the band factory
      
      get '/bands'
      
      expect(last_response).to be_ok
      body = last_response.body
      a_index = body.index('A Band')
      b_index = body.index('B Band')
      c_index = body.index('C Band')
      
      expect(a_index).to be < b_index
      expect(b_index).to be < c_index
    end
  end

  describe 'GET /bands/new' do
    it 'displays the new band form' do
      login_as(user, band)
      get '/bands/new'
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('New Band')
      expect(last_response.body).to include('name')
      expect(last_response.body).to include('notes')
    end
  end

  describe 'POST /bands' do
    it 'creates a new band with valid attributes' do
      login_as(user, band)
      band_params = { name: 'New Band', notes: 'A great band' }
      
      expect {
        post '/bands', band: band_params
      }.to change(Band, :count).by(1)
      
      expect(last_response).to be_redirect
      follow_redirect!
      expect(last_response.body).to include('New Band')
    end

    it 'creates the first band and redirects to home' do
      # Create a user without any bands initially
      new_user = create(:user)
      login_as(new_user)
      band_params = { name: 'First Band', notes: 'The first band' }
      
      expect {
        post '/bands', band: band_params
      }.to change(Band, :count).by(1)
      
      expect(last_response).to be_redirect
      expect(last_response.location).to end_with('/gigs')
    end

    it 'creates subsequent bands and redirects to bands index' do
      login_as(user, band)
      create(:band, name: 'Existing Band')
      band_params = { name: 'Second Band', notes: 'Another band' }
      
      expect {
        post '/bands', band: band_params
      }.to change(Band, :count).by(1)
      
      expect(last_response).to be_redirect
      expect(last_response.location).to end_with('/bands')
    end

    it 'displays errors for invalid attributes' do
      login_as(user, band)
      band_params = { name: '', notes: 'Invalid band' }
      
      expect {
        post '/bands', band: band_params
      }.not_to change(Band, :count)
      
      expect(last_response).to be_ok
      expect(last_response.body).to include("can't be blank")
    end

    it 'displays errors for duplicate band names' do
      login_as(user, band)
      create(:band, name: 'Duplicate Band')
      band_params = { name: 'Duplicate Band', notes: 'Another band' }
      
      expect {
        post '/bands', band: band_params
      }.not_to change(Band, :count)
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('has already been taken')
    end
  end

  describe 'GET /bands/:id' do
    it 'displays a specific band' do
      login_as(user, band)
      test_band = create(:band, name: 'Test Band', notes: 'Test notes', owner: user)
      # UserBand relationship is automatically created by the band factory
      
      get "/bands/#{test_band.id}"
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('Test Band')
      expect(last_response.body).to include('Test notes')
    end

    it 'returns error for non-existent band' do
      login_as(user, band)
      expect {
        get '/bands/999'
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'GET /bands/:id/edit' do
    it 'displays the edit form for a band' do
      login_as(user, band)
      edit_band = create(:band, name: 'Edit Band', notes: 'Edit notes', owner: user)
      # UserBand relationship is automatically created by the band factory
      
      get "/bands/#{edit_band.id}/edit"
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('Edit Band')
      expect(last_response.body).to include('Edit notes')
      expect(last_response.body).to include('method="post"')
      expect(last_response.body).to include('_method" value="PUT"')
    end

    it 'returns error for non-existent band' do
      login_as(user, band)
      expect {
        get '/bands/999/edit'
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'PUT /bands/:id' do
    it 'updates a band with valid attributes' do
      login_as(user, band)
      update_band = create(:band, name: 'Old Name', notes: 'Old notes', owner: user)
      # UserBand relationship is automatically created by the band factory
      update_params = { name: 'New Name', notes: 'New notes' }
      
      put "/bands/#{update_band.id}", band: update_params
      
      expect(last_response).to be_redirect
      follow_redirect!
      expect(last_response.body).to include('New Name')
      expect(last_response.body).to include('New notes')
    end

    it 'displays errors for invalid attributes' do
      login_as(user, band)
      update_band = create(:band, name: 'Valid Name', owner: user)
      # UserBand relationship is automatically created by the band factory
      update_params = { name: '', notes: 'Valid notes' }
      
      put "/bands/#{update_band.id}", band: update_params
      
      expect(last_response).to be_ok
      expect(last_response.body).to include("can't be blank")
    end

    it 'returns error for non-existent band' do
      login_as(user, band)
      expect {
        put '/bands/999', band: { name: 'New Name' }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'DELETE /bands/:id' do
    it 'deletes a band' do
      login_as(user, band)
      delete_band = create(:band, name: 'Delete Band', owner: user)
      # UserBand relationship is automatically created by the band factory
      
      expect {
        delete "/bands/#{delete_band.id}"
      }.to change(Band, :count).by(-1)
      
      expect(last_response).to be_redirect
      expect(last_response.location).to end_with('/bands')
    end

    it 'returns error for non-existent band' do
      login_as(user, band)
      expect {
        delete '/bands/999'
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'Google Calendar Integration' do
    let(:google_calendar_band) { create(:band, owner: user, google_calendar_enabled: true, google_calendar_id: 'test_calendar_id') }
    let(:mock_service) { instance_double(GoogleCalendarService) }

    before do
      # UserBand relationship is automatically created by the band factory
      allow(GoogleCalendarService).to receive(:new).with(google_calendar_band).and_return(mock_service)
    end

    describe 'POST /bands/:id/google_calendar_settings' do
      it 'updates Google Calendar settings successfully' do
        login_as(user, google_calendar_band)

        post "/bands/#{google_calendar_band.id}/google_calendar_settings", {
          google_calendar_enabled: '1',
          google_calendar_id: 'new_calendar_id'
        }

        expect(last_response).to be_ok
        expect(last_response.body).to include('Google Calendar settings updated successfully')
        google_calendar_band.reload
        expect(google_calendar_band.google_calendar_enabled).to be true
        expect(google_calendar_band.google_calendar_id).to eq('new_calendar_id')
      end

      it 'validates calendar ID when Google Calendar is enabled' do
        login_as(user, google_calendar_band)

        post "/bands/#{google_calendar_band.id}/google_calendar_settings", {
          google_calendar_enabled: '1',
          google_calendar_id: ''
        }

        expect(last_response).to be_ok
        expect(last_response.body).to include('Calendar ID is required when Google Calendar sync is enabled')
      end

      it 'allows disabling Google Calendar without calendar ID' do
        login_as(user, google_calendar_band)

        post "/bands/#{google_calendar_band.id}/google_calendar_settings", {
          google_calendar_enabled: '0',
          google_calendar_id: ''
        }

        expect(last_response).to be_ok
        google_calendar_band.reload
        expect(google_calendar_band.google_calendar_enabled).to be false
      end

      it 'requires band membership' do
        other_user = create(:user)
        other_band = create(:band, owner: other_user)
        # UserBand relationship is automatically created by the band factory
        login_as(other_user, other_band)

        expect {
          post "/bands/#{google_calendar_band.id}/google_calendar_settings", {
            google_calendar_enabled: '1',
            google_calendar_id: 'test_id'
          }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    describe 'POST /bands/:id/test_google_calendar' do
      it 'tests Google Calendar connection successfully' do
        login_as(user, google_calendar_band)
        allow(mock_service).to receive(:test_connection).and_return({
          success: true,
          calendar_name: 'Test Calendar'
        })

        post "/bands/#{google_calendar_band.id}/test_google_calendar", {
          google_calendar_id: 'test_calendar_id'
        }

        expect(last_response.status).to eq(200)
        expect(last_response.content_type).to include('application/json')
        response_data = JSON.parse(last_response.body)
        expect(response_data['success']).to be true
        expect(response_data['calendar_name']).to eq('Test Calendar')
      end

      it 'handles connection failure' do
        login_as(user, google_calendar_band)
        allow(mock_service).to receive(:test_connection).and_return({
          success: false,
          error: 'Calendar not found'
        })

        post "/bands/#{google_calendar_band.id}/test_google_calendar", {
          google_calendar_id: 'invalid_calendar_id'
        }

        expect(last_response.status).to eq(200)
        response_data = JSON.parse(last_response.body)
        expect(response_data['success']).to be false
        expect(response_data['error']).to eq('Calendar not found')
      end

      it 'requires band membership' do
        other_user = create(:user)
        other_band = create(:band, owner: other_user)
        # UserBand relationship is automatically created by the band factory
        login_as(other_user, other_band)

        expect {
          post "/bands/#{google_calendar_band.id}/test_google_calendar", {
            google_calendar_id: 'test_id'
          }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    describe 'POST /bands/:id/sync_google_calendar' do
      it 'syncs all gigs to Google Calendar successfully' do
        login_as(user, google_calendar_band)
        allow(mock_service).to receive(:sync_all_gigs).and_return({
          success: true,
          synced_count: 5,
          total_count: 5,
          errors: []
        })

        post "/bands/#{google_calendar_band.id}/sync_google_calendar"

        expect(last_response.status).to eq(200)
        expect(last_response.content_type).to include('application/json')
        response_data = JSON.parse(last_response.body)
        expect(response_data['success']).to be true
        expect(response_data['synced_count']).to eq(5)
        expect(response_data['total_count']).to eq(5)
      end

      it 'handles partial sync failures' do
        login_as(user, google_calendar_band)
        allow(mock_service).to receive(:sync_all_gigs).and_return({
          success: false,
          synced_count: 3,
          total_count: 5,
          errors: ['Failed to sync gig: Test Gig 1', 'Failed to sync gig: Test Gig 2']
        })

        post "/bands/#{google_calendar_band.id}/sync_google_calendar"

        expect(last_response.status).to eq(200)
        response_data = JSON.parse(last_response.body)
        expect(response_data['success']).to be false
        expect(response_data['synced_count']).to eq(3)
        expect(response_data['errors'].length).to eq(2)
      end

      it 'returns error when Google Calendar is not enabled' do
        disabled_band = create(:band, owner: user, google_calendar_enabled: false)
        # UserBand relationship is automatically created by the band factory
        login_as(user, disabled_band)

        post "/bands/#{disabled_band.id}/sync_google_calendar"

        expect(last_response.status).to eq(200)
        response_data = JSON.parse(last_response.body)
        expect(response_data['success']).to be false
        expect(response_data['error']).to eq('Google Calendar sync is not enabled for this band')
      end

      it 'requires band membership' do
        other_user = create(:user)
        other_band = create(:band, owner: other_user)
        # UserBand relationship is automatically created by the band factory
        login_as(other_user, other_band)

        expect {
          post "/bands/#{google_calendar_band.id}/sync_google_calendar"
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'Public Schedule Settings' do
    describe 'POST /bands/:id/public_schedule_settings' do
      it 'enables the public schedule' do
        login_as(user, band)

        post "/bands/#{band.id}/public_schedule_settings", { public_schedule_enabled: '1' }

        expect(last_response).to be_ok
        expect(last_response.body).to include('Public schedule settings updated successfully')
        band.reload
        expect(band.public_schedule_enabled).to be true
      end

      it 'disables the public schedule' do
        band.update!(public_schedule_enabled: true)
        login_as(user, band)

        post "/bands/#{band.id}/public_schedule_settings", {}

        expect(last_response).to be_ok
        band.reload
        expect(band.public_schedule_enabled).to be false
      end

      it 'requires band membership' do
        other_user = create(:user)
        other_band = create(:band, owner: other_user)
        login_as(other_user, other_band)

        expect {
          post "/bands/#{band.id}/public_schedule_settings", { public_schedule_enabled: '1' }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end 