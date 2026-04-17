require 'spec_helper'

RSpec.describe Venue, type: :model do
  describe 'associations' do
    it 'belongs to a band' do
      band = create(:band)
      venue = create(:venue, band: band)
      
      expect(venue.band).to eq(band)
    end

    it 'can exist without a band (optional association)' do
      venue = build(:venue, band: nil)
      expect(venue).to be_valid
    end

    it 'has many gigs' do
      venue = create(:venue)
      gig1 = create(:gig, venue: venue)
      gig2 = create(:gig, venue: venue)
      
      expect(venue.gigs).to include(gig1, gig2)
    end
  end

  describe 'scopes' do
    it 'orders by name' do
      venue_c = create(:venue, name: 'C Venue')
      venue_a = create(:venue, name: 'A Venue')
      venue_b = create(:venue, name: 'B Venue')

      expect(Venue.order(:name)).to eq([venue_a, venue_b, venue_c])
    end

    describe 'archived filtering' do
      let!(:active_venue) { create(:venue, name: 'Active Venue', archived: false) }
      let!(:archived_venue) { create(:venue, name: 'Archived Venue', archived: true) }

      it 'filters active venues' do
        expect(Venue.active).to include(active_venue)
        expect(Venue.active).not_to include(archived_venue)
      end

      it 'filters archived venues' do
        expect(Venue.archived).to include(archived_venue)
        expect(Venue.archived).not_to include(active_venue)
      end
    end
  end

  describe 'archiving functionality' do
    let(:venue) { create(:venue) }

    describe '#archive!' do
      it 'sets archived to true' do
        expect { venue.archive! }.to change { venue.archived }.from(false).to(true)
      end

      it 'persists the change' do
        venue.archive!
        expect(venue.reload.archived).to be true
      end
    end

    describe '#unarchive!' do
      let(:archived_venue) { create(:venue, archived: true) }

      it 'sets archived to false' do
        expect { archived_venue.unarchive! }.to change { archived_venue.archived }.from(true).to(false)
      end

      it 'persists the change' do
        archived_venue.unarchive!
        expect(archived_venue.reload.archived).to be false
      end
    end

    describe '#archived?' do
      it 'returns true when venue is archived' do
        venue.update!(archived: true)
        expect(venue.archived?).to be true
      end

      it 'returns false when venue is not archived' do
        venue.update!(archived: false)
        expect(venue.archived?).to be false
      end
    end

    describe '#active?' do
      it 'returns false when venue is archived' do
        venue.update!(archived: true)
        expect(venue.active?).to be false
      end

      it 'returns true when venue is not archived' do
        venue.update!(archived: false)
        expect(venue.active?).to be true
      end
    end
  end

  describe 'destruction' do
    it 'can be destroyed when it has no associated records' do
      venue = create(:venue)
      expect { venue.destroy }.to change(Venue, :count).by(-1)
    end

    it 'can be destroyed when it has gigs' do
      venue = create(:venue)
      gig = create(:gig, venue: venue)
      gig.destroy  # Clean up the set list first due to foreign key constraint
      expect { venue.destroy }.to change(Venue, :count).by(-1)
    end
  end
end 