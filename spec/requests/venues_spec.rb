require 'spec_helper'

RSpec.describe 'Venues API', type: :request do
  let(:user) { create(:user) }
  let(:band) { create(:band, owner: user) }
  let(:other_band) { create(:band, owner: user) }
  
  before do
    # UserBand relationships are automatically created by the band factory
  end
  
  def login_as(user, band)
    # Use the test auth route for authentication
    post '/test_auth', user_id: user.id, band_id: band.id
  end
  describe 'GET /venues' do
    it 'redirects to login when not authenticated' do
      get '/venues'
      expect(last_response).to be_redirect
      expect(last_response.location).to end_with('/login')
    end

    it 'redirects to create first band when user has no bands' do
      # Login without any bands
      post '/test_auth', user_id: user.id
      get '/venues'
      expect(last_response).to be_redirect
      expect(last_response.location).to end_with('/bands/new?first_band=true')
    end

    it 'redirects to band selection when user has bands but none selected' do
      # Create bands by referencing them (let blocks are lazy)
      band
      other_band
      # Login without selecting a band
      post '/test_auth', user_id: user.id
      get '/venues'
      expect(last_response).to be_redirect
      expect(last_response.location).to end_with('/bands')
    end

    it 'returns only venues for the current band' do
      login_as(user, band)
      venue1 = create(:venue, name: 'Band Venue A', band: band)
      venue2 = create(:venue, name: 'Band Venue B', band: band)
      other_venue = create(:venue, name: 'Other Venue', band: other_band)
      
      get '/venues'
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('Band Venue A')
      expect(last_response.body).to include('Band Venue B')
      expect(last_response.body).not_to include('Other Venue')
    end

    it 'displays venues in alphabetical order' do
      login_as(user, band)
      venue_c = create(:venue, name: 'C Venue', band: band)
      venue_a = create(:venue, name: 'A Venue', band: band)
      venue_b = create(:venue, name: 'B Venue', band: band)
      
      get '/venues'
      
      expect(last_response).to be_ok
      body = last_response.body
      a_index = body.index('A Venue')
      b_index = body.index('B Venue')
      c_index = body.index('C Venue')
      
      expect(a_index).to be < b_index
      expect(b_index).to be < c_index
    end
  end

  describe 'GET /venues/new' do
    it 'requires authentication and band selection' do
      get '/venues/new'
      expect(last_response).to be_redirect
      expect(last_response.location).to end_with('/login')
    end

    it 'displays the new venue form when authenticated' do
      login_as(user, band)
      get '/venues/new'
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('New Venue')
      expect(last_response.body).to include('name')
      expect(last_response.body).to include('location')
      expect(last_response.body).to include('contact_name')
      expect(last_response.body).to include('phone_number')
    end
  end

  describe 'POST /venues' do
    it 'requires authentication' do
      venue_params = { name: 'New Venue', location: '123 Main St', contact_name: 'John Doe', phone_number: '555-1234' }
      
      expect {
        post '/venues', venue: venue_params
      }.not_to change(Venue, :count)
      
      expect(last_response).to be_redirect
      expect(last_response.location).to end_with('/login')
    end

    it 'creates a new venue with valid attributes and associates with current band' do
      login_as(user, band)
      venue_params = {
        name: 'New Venue',
        location: '123 Main St, City, State',
        contact_name: 'John Doe',
        phone_number: '555-1234',
        website: 'http://example.com'
      }
      
      expect {
        post '/venues', venue: venue_params
      }.to change(Venue, :count).by(1)
      
      new_venue = Venue.last
      expect(new_venue.band).to eq(band)
      expect(last_response).to be_redirect
      follow_redirect!
      expect(last_response.body).to include('New Venue')
    end

    it 'displays errors for invalid attributes' do
      login_as(user, band)
      venue_params = {
        name: '',
        location: '',
        contact_name: '',
        phone_number: ''
      }
      
      expect {
        post '/venues', venue: venue_params
      }.not_to change(Venue, :count)
      
      expect(last_response).to be_ok
      expect(last_response.body).to include("can't be blank")
    end
  end

  describe 'GET /venues/:id' do
    it 'displays a venue from current band' do
      login_as(user, band)
      venue = create(:venue, name: 'Test Venue', location: 'Test Location', band: band)
      
      get "/venues/#{venue.id}"
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('Test Venue')
      expect(last_response.body).to include('Test Location')
    end

    it 'returns 404 for venue from another band' do
      login_as(user, band)
      other_venue = create(:venue, name: 'Other Venue', band: other_band)
      
      expect { get "/venues/#{other_venue.id}" }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'GET /venues/:id/edit' do
    it 'displays the edit form for a venue' do
      login_as(user, band)
      venue = create(:venue, name: 'Edit Venue', location: 'Edit Location', band: band)
      
      get "/venues/#{venue.id}/edit"
      
      expect(last_response).to be_ok
      expect(last_response.body).to include('Edit Venue')
      expect(last_response.body).to include('Edit Location')
      expect(last_response.body).to include('method="POST"')
      expect(last_response.body).to include('_method" value="PUT"')
    end

    it 'returns 404 for non-existent venue' do
      login_as(user, band)
      expect { get '/venues/999/edit' }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'PUT /venues/:id' do
    it 'updates a venue with valid attributes' do
      login_as(user, band)
      venue = create(:venue, name: 'Old Name', location: 'Old Location', band: band)
      update_params = {
        name: 'New Name',
        location: 'New Location',
        contact_name: 'New Contact',
        phone_number: '555-5678'
      }
      
      put "/venues/#{venue.id}", venue: update_params
      
      expect(last_response).to be_redirect
      follow_redirect!
      expect(last_response.body).to include('New Name')
      expect(last_response.body).to include('New Location')
    end

    it 'displays errors for invalid attributes' do
      login_as(user, band)
      venue = create(:venue, name: 'Valid Name', band: band)
      update_params = { name: '', location: 'Valid Location' }
      
      put "/venues/#{venue.id}", venue: update_params
      
      expect(last_response).to be_ok
      expect(last_response.body).to include("can't be blank")
    end

    it 'returns 404 for non-existent venue' do
      login_as(user, band)
      expect { put '/venues/999', venue: { name: 'New Name' } }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'DELETE /venues/:id' do
    it 'requires authentication and only allows deleting current band venues' do
      venue = create(:venue, name: 'Delete Venue', band: band)
      
      expect {
        delete "/venues/#{venue.id}"
      }.not_to change(Venue, :count)
      
      expect(last_response).to be_redirect
      expect(last_response.location).to end_with('/login')
    end

    it 'deletes a venue for current band' do
      login_as(user, band)
      venue = create(:venue, name: 'Delete Venue', band: band)
      
      expect {
        delete "/venues/#{venue.id}"
      }.to change(Venue, :count).by(-1)
      
      expect(last_response).to be_redirect
      expect(last_response.location).to end_with('/venues')
    end

    it 'cannot delete venue from another band' do
      login_as(user, band)
      other_venue = create(:venue, name: 'Other Band Venue', band: other_band)
      
      expect { delete "/venues/#{other_venue.id}" }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'Venue Copying' do
    describe 'GET /bands/:band_id/copy_venues' do
      it 'requires authentication' do
        get "/bands/#{band.id}/copy_venues"
        expect(last_response).to be_redirect
        expect(last_response.location).to end_with('/login')
      end

      it 'displays venues from other bands user is a member of' do
        login_as(user, band)
        venue1 = create(:venue, name: 'Other Band Venue 1', band: other_band)
        venue2 = create(:venue, name: 'Other Band Venue 2', band: other_band)
        current_band_venue = create(:venue, name: 'Current Band Venue', band: band)
        
        get "/bands/#{band.id}/copy_venues"
        
        expect(last_response).to be_ok
        expect(last_response.body).to include('Other Band Venue 1')
        expect(last_response.body).to include('Other Band Venue 2')
        expect(last_response.body).not_to include('Current Band Venue')
      end

      it 'excludes venues already copied (by name and location)' do
        login_as(user, band)
        original_venue = create(:venue, name: 'Test Venue', location: 'Test Location', band: other_band)
        copied_venue = create(:venue, name: 'Test Venue', location: 'Test Location', band: band)
        
        get "/bands/#{band.id}/copy_venues"
        
        expect(last_response).to be_ok
        expect(last_response.body).not_to include('Test Venue')
      end
    end

    describe 'POST /bands/:band_id/copy_venues' do
      it 'requires authentication' do
        venue = create(:venue, band: other_band)
        
        expect {
          post "/bands/#{band.id}/copy_venues", venue_ids: [venue.id.to_s]
        }.not_to change(Venue, :count)
        
        expect(last_response).to be_redirect
        expect(last_response.location).to end_with('/login')
      end

      it 'copies selected venues to the target band' do
        login_as(user, band)
        venue1 = create(:venue, name: 'Venue 1', location: 'Location 1', contact_name: 'Contact 1', phone_number: '111-1111', band: other_band)
        venue2 = create(:venue, name: 'Venue 2', location: 'Location 2', contact_name: 'Contact 2', phone_number: '222-2222', band: other_band)
        
        expect {
          post "/bands/#{band.id}/copy_venues", venue_ids: [venue1.id.to_s, venue2.id.to_s]
        }.to change(Venue, :count).by(2)
        
        expect(last_response).to be_redirect
        expect(last_response.location).to end_with("/bands/#{band.id}?venues_copied=2")
        
        copied_venues = band.venues.reload
        expect(copied_venues.map(&:name)).to include('Venue 1', 'Venue 2')
        expect(copied_venues.map(&:location)).to include('Location 1', 'Location 2')
      end

      it 'only copies venues from bands the user is a member of' do
        login_as(user, band)
        unauthorized_band = create(:band)
        unauthorized_venue = create(:venue, name: 'Unauthorized Venue', band: unauthorized_band)
        
        expect {
          post "/bands/#{band.id}/copy_venues", venue_ids: [unauthorized_venue.id.to_s]
        }.not_to change(Venue, :count)
        
        expect(last_response).to be_redirect
        expect(last_response.location).to end_with("/bands/#{band.id}?venues_copied=0")
      end
    end
  end

  describe 'Single Venue Copying' do
    describe 'GET /venues/:venue_id/copy' do
      it 'requires authentication' do
        venue = create(:venue, band: band)
        
        get "/venues/#{venue.id}/copy"
        expect(last_response).to be_redirect
        expect(last_response.location).to end_with('/login')
      end

      it 'displays copy form for venue with available target bands' do
        login_as(user, band)
        venue = create(:venue, name: 'Test Venue', band: band)

        # Force creation of other_band to ensure UserBand relationship is created
        other_band # This triggers the lazy evaluation

        get "/venues/#{venue.id}/copy"

        expect(last_response).to be_ok
        expect(last_response.body).to include('Copy Venue to Another Band')
        expect(last_response.body).to include('Test Venue')
        expect(last_response.body).to include(other_band.name)
      end

      it 'excludes target bands that already have a venue with the same name' do
        login_as(user, band)
        venue = create(:venue, name: 'Duplicate Venue', band: band)
        create(:venue, name: 'Duplicate Venue', band: other_band)
        
        get "/venues/#{venue.id}/copy"
        
        expect(last_response).to be_ok
        # The page should show the empty-state message and not render the select control
        expect(last_response.body).to include('No Available Bands')
        expect(last_response.body).not_to include('<select id="target_band_id"')
      end

      it 'cannot access venue from another band' do
        login_as(user, band)
        other_venue = create(:venue, name: 'Other Venue', band: other_band)
        
        expect { get "/venues/#{other_venue.id}/copy" }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    describe 'POST /venues/:venue_id/copy' do
      it 'requires authentication' do
        venue = create(:venue, band: band)
        
        expect {
          post "/venues/#{venue.id}/copy", target_band_id: other_band.id.to_s
        }.not_to change(Venue, :count)
        
        expect(last_response).to be_redirect
        expect(last_response.location).to end_with('/login')
      end

      it 'copies venue to target band successfully' do
        login_as(user, band)
        venue = create(:venue, name: 'Copy Me', location: 'Test Location', contact_name: 'Test Contact', phone_number: '123-456-7890', band: band)
        
        expect {
          post "/venues/#{venue.id}/copy", target_band_id: other_band.id.to_s
        }.to change(Venue, :count).by(1)
        
        expect(last_response).to be_redirect
        expect(last_response.location).to end_with("/venues/#{venue.id}?copied_to=#{other_band.name}")
        
        copied_venue = other_band.venues.find_by(name: 'Copy Me')
        expect(copied_venue).to be_present
        expect(copied_venue.location).to eq('Test Location')
        expect(copied_venue.contact_name).to eq('Test Contact')
        expect(copied_venue.phone_number).to eq('123-456-7890')
      end

      it 'shows error when no target band is selected' do
        login_as(user, band)
        venue = create(:venue, name: 'Test Venue', band: band)
        
        expect {
          post "/venues/#{venue.id}/copy", target_band_id: ''
        }.not_to change(Venue, :count)
        
        expect(last_response).to be_ok
        expect(last_response.body).to include('Please select a band to copy the venue to')
      end

      it 'shows error when target band already has venue with same name' do
        login_as(user, band)
        venue = create(:venue, name: 'Duplicate Name', band: band)
        create(:venue, name: 'Duplicate Name', band: other_band)
        
        expect {
          post "/venues/#{venue.id}/copy", target_band_id: other_band.id.to_s
        }.not_to change(Venue, :count)
        
        expect(last_response).to be_ok
        expect(last_response.body).to include("already has a venue named 'Duplicate Name'")
      end

      it 'only allows copying to bands user is a member of' do
        login_as(user, band)
        venue = create(:venue, name: 'Test Venue', band: band)
        unauthorized_band = create(:band)
        
        expect { post "/venues/#{venue.id}/copy", target_band_id: unauthorized_band.id.to_s }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it 'cannot copy venue from another band' do
        login_as(user, band)
        other_venue = create(:venue, name: 'Other Venue', band: other_band)
        
        expect { post "/venues/#{other_venue.id}/copy", target_band_id: band.id.to_s }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'Venue Archiving' do
    describe 'GET /venues shows only active venues' do
      it 'filters out archived venues from the main listing' do
        login_as(user, band)
        active_venue = create(:venue, name: 'Active Venue', band: band, archived: false)
        archived_venue = create(:venue, name: 'My Archived Venue', band: band, archived: true)

        get '/venues'

        expect(last_response).to be_ok
        expect(last_response.body).to include('Active Venue')
        expect(last_response.body).not_to include('My Archived Venue')
      end
    end

    describe 'POST /venues/:id/archive' do
      it 'requires authentication' do
        venue = create(:venue, band: band)

        post "/venues/#{venue.id}/archive"

        expect(last_response).to be_redirect
        expect(last_response.location).to end_with('/login')
        expect(venue.reload.archived).to be false
      end

      it 'archives a venue for current band' do
        login_as(user, band)
        venue = create(:venue, name: 'Archive Me', band: band)

        expect {
          post "/venues/#{venue.id}/archive"
        }.to change { venue.reload.archived }.from(false).to(true)

        expect(last_response).to be_redirect
        expect(last_response.location).to end_with('/venues')
      end

      it 'cannot archive venue from another band' do
        login_as(user, band)
        other_venue = create(:venue, name: 'Other Band Venue', band: other_band)

        expect { post "/venues/#{other_venue.id}/archive" }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    describe 'POST /venues/:id/unarchive' do
      it 'requires authentication' do
        venue = create(:venue, band: band, archived: true)

        post "/venues/#{venue.id}/unarchive"

        expect(last_response).to be_redirect
        expect(last_response.location).to end_with('/login')
        expect(venue.reload.archived).to be true
      end

      it 'unarchives a venue for current band' do
        login_as(user, band)
        venue = create(:venue, name: 'Unarchive Me', band: band, archived: true)

        expect {
          post "/venues/#{venue.id}/unarchive"
        }.to change { venue.reload.archived }.from(true).to(false)

        expect(last_response).to be_redirect
        expect(last_response.location).to end_with('/venues')
      end

      it 'cannot unarchive venue from another band' do
        login_as(user, band)
        other_venue = create(:venue, name: 'Other Band Venue', band: other_band, archived: true)

        expect { post "/venues/#{other_venue.id}/unarchive" }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    describe 'GET /venues/archived' do
      it 'requires authentication' do
        get '/venues/archived'

        expect(last_response).to be_redirect
        expect(last_response.location).to end_with('/login')
      end

      it 'shows only archived venues for current band' do
        login_as(user, band)
        active_venue = create(:venue, name: 'Active Venue', band: band, archived: false)
        archived_venue = create(:venue, name: 'Archived Venue', band: band, archived: true)
        other_band_archived = create(:venue, name: 'Other Band Archived', band: other_band, archived: true)

        get '/venues/archived'

        expect(last_response).to be_ok
        expect(last_response.body).to include('Archived Venue')
        expect(last_response.body).not_to include('Active Venue')
        expect(last_response.body).not_to include('Other Band Archived')
      end

      it 'shows message when no archived venues exist' do
        login_as(user, band)
        create(:venue, name: 'Active Venue', band: band, archived: false)

        get '/venues/archived'

        expect(last_response).to be_ok
        expect(last_response.body).to include('No archived venues')
      end
    end

    describe 'Gig forms exclude archived venues' do
      it 'excludes archived venues from gig creation form' do
        login_as(user, band)
        active_venue = create(:venue, name: 'Active Venue', band: band, archived: false)
        archived_venue = create(:venue, name: 'Archived Venue', band: band, archived: true)

        get '/gigs/new'

        expect(last_response).to be_ok
        expect(last_response.body).to include('Active Venue')
        expect(last_response.body).not_to include('Archived Venue')
      end

      it 'excludes archived venues from gig edit form' do
        login_as(user, band)
        active_venue = create(:venue, name: 'Active Venue', band: band, archived: false)
        archived_venue = create(:venue, name: 'Archived Venue', band: band, archived: true)
        gig = create(:gig, band: band, venue: active_venue)

        get "/gigs/#{gig.id}/edit"

        expect(last_response).to be_ok
        expect(last_response.body).to include('Active Venue')
        expect(last_response.body).not_to include('Archived Venue')
      end
    end
  end
end 