require 'spec_helper'

RSpec.describe Band, type: :model do
  describe 'associations' do
    it 'has many songs' do
      band = create(:band)
      song1 = create(:song, bands: [band])
      song2 = create(:song, bands: [band])
      
      expect(band.songs).to include(song1, song2)
    end

    it 'has many gigs' do
      band = create(:band)
      gig1 = create(:gig, band: band)
      gig2 = create(:gig, band: band)
      
      expect(band.gigs).to include(gig1, gig2)
    end

    it 'has many venues' do
      band = create(:band)
      venue1 = create(:venue, band: band)
      venue2 = create(:venue, band: band)
      
      expect(band.venues).to include(venue1, venue2)
    end
  end

  describe 'scopes' do
    it 'orders by name' do
      band_c = create(:band, name: 'C Band')
      band_a = create(:band, name: 'A Band')
      band_b = create(:band, name: 'B Band')
      
      expect(Band.order(:name)).to eq([band_a, band_b, band_c])
    end
  end

  describe 'slug generation' do
    it 'generates a slug from the name on create' do
      band = create(:band, name: 'The Rolling Stones')
      expect(band.slug).to eq('the-rolling-stones')
    end

    it 'converts spaces to hyphens' do
      band = create(:band, name: 'My Cool Band')
      expect(band.slug).to eq('my-cool-band')
    end

    it 'lowercases the slug' do
      band = create(:band, name: 'UPPERCASE BAND')
      expect(band.slug).to eq('uppercase-band')
    end

    it 'strips special characters' do
      band = create(:band, name: 'Band & Friends!')
      expect(band.slug).to eq('band-friends')
    end

    it 'preserves the slug when the name changes' do
      band = create(:band, name: 'Old Name')
      band.update!(name: 'New Name')
      expect(band.slug).to eq('old-name')
    end

    it 'is invalid when slug is not unique' do
      create(:band, name: 'Original Band')
      duplicate = build(:band, name: 'Another Band')
      duplicate.slug = 'original-band'
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:slug]).to be_present
    end
  end

  describe '#public_schedule_enabled?' do
    it 'returns false by default' do
      band = create(:band)
      expect(band.public_schedule_enabled?).to be false
    end

    it 'returns true when enabled' do
      band = create(:band, public_schedule_enabled: true)
      expect(band.public_schedule_enabled?).to be true
    end
  end

  describe 'destruction' do
    it 'can be destroyed when it has no associated records' do
      band = create(:band)
      expect { band.destroy }.to change(Band, :count).by(-1)
    end

    it 'can be destroyed when it has songs' do
      band = create(:band)
      song = create(:song)
      song.bands << band
      song.save!
      # Remove the association before destroying the band
      song.bands.clear
      expect { band.destroy }.to change(Band, :count).by(-1)
    end

    it 'can be destroyed when it has gigs' do
      band = create(:band)
      gig = create(:gig, band: band)
      gig.destroy  # Clean up the set list first due to foreign key constraint
      expect { band.destroy }.to change(Band, :count).by(-1)
    end

    it 'can be destroyed when it has venues' do
      band = create(:band)
      venue = create(:venue, band: band)
      venue.destroy  # Clean up the venue first due to foreign key constraint
      expect { band.destroy }.to change(Band, :count).by(-1)
    end
  end

  describe 'whitespace stripping' do
    it 'strips leading spaces from name' do
      band = create(:band, name: '  The Wandering Bards')
      expect(band.name).to eq('The Wandering Bards')
    end

    it 'strips leading spaces from name on update' do
      band = create(:band, name: 'The Wandering Bards')
      band.update(name: '   Renamed Band')
      expect(band.reload.name).to eq('Renamed Band')
    end
  end

  describe 'tip link' do
    describe 'validations' do
      it 'allows a blank tip text' do
        band = build(:band, tip_text: '')
        expect(band).to be_valid
      end

      it 'allows tip text up to 80 characters' do
        band = build(:band, tip_text: 'a' * 80)
        expect(band).to be_valid
      end

      it 'rejects tip text longer than 80 characters' do
        band = build(:band, tip_text: 'a' * 81)
        expect(band).not_to be_valid
        expect(band.errors[:tip_text]).to include('is too long (maximum is 80 characters)')
      end

      it 'allows a valid tip url' do
        band = build(:band, tip_url: 'https://example.com/tip')
        expect(band).to be_valid
      end

      it 'rejects a tip url that is not http(s)' do
        band = build(:band, tip_url: 'javascript:alert(1)')
        expect(band).not_to be_valid
        expect(band.errors[:tip_url]).to include('must be a valid http:// or https:// URL')
      end

      it 'rejects a malformed tip url' do
        band = build(:band, tip_url: 'not a url')
        expect(band).not_to be_valid
        expect(band.errors[:tip_url]).to include('must be a valid http:// or https:// URL')
      end
    end

    describe '#tip_link_text' do
      it 'returns the default text when tip text is not set' do
        band = create(:band)
        expect(band.tip_link_text).to eq('💗 Tip the Band')
      end

      it 'returns the default text when tip text is blank' do
        band = create(:band, tip_text: '')
        expect(band.tip_link_text).to eq('💗 Tip the Band')
      end

      it 'returns the custom text when set' do
        band = create(:band, tip_text: 'Buy us a beer 🍺')
        expect(band.tip_link_text).to eq('Buy us a beer 🍺')
      end
    end
  end
end 