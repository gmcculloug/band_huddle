require 'spec_helper'

RSpec.describe Song, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      song = build(:song)
      expect(song).to be_valid
    end

    it 'is invalid without a title' do
      song = build(:song, title: nil)
      expect(song).not_to be_valid
      expect(song.errors[:title]).to include("can't be blank")
    end

    it 'is invalid without an artist' do
      song = build(:song, artist: nil)
      expect(song).not_to be_valid
      expect(song.errors[:artist]).to include("can't be blank")
    end

    it 'is invalid without a key' do
      song = build(:song, key: nil)
      expect(song).not_to be_valid
      expect(song.errors[:key]).to include("can't be blank")
    end


    it 'is valid with a positive tempo' do
      song = build(:song, tempo: 120)
      expect(song).to be_valid
    end

    it 'is invalid with a negative tempo' do
      song = build(:song, tempo: -10)
      expect(song).not_to be_valid
      expect(song.errors[:tempo]).to include('must be greater than 0')
    end

    it 'is invalid with a zero tempo' do
      song = build(:song, tempo: 0)
      expect(song).not_to be_valid
      expect(song.errors[:tempo]).to include('must be greater than 0')
    end

    it 'is valid with a nil tempo' do
      song = build(:song, tempo: nil)
      expect(song).to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to many bands' do
      song = create(:song)
      band1 = create(:band)
      band2 = create(:band)
      
      song.bands << band1
      song.bands << band2
      
      expect(song.bands).to include(band1, band2)
    end

    it 'has many gig songs' do
      song = create(:song)
      gig_song1 = create(:gig_song, song: song)
      gig_song2 = create(:gig_song, song: song)
      
      expect(song.gig_songs).to include(gig_song1, gig_song2)
    end

    it 'has many gigs through gig songs' do
      song = create(:song)
      gig1 = create(:gig)
      gig2 = create(:gig)
      
      create(:gig_song, song: song, gig: gig1)
      create(:gig_song, song: song, gig: gig2)
      
      expect(song.gigs).to include(gig1, gig2)
    end
  end

  describe 'search functionality' do
    it 'finds songs by title' do
      song1 = create(:song, title: 'Wonderwall', artist: 'Oasis')
      song2 = create(:song, title: 'Yellow', artist: 'Coldplay')
      
      results = Song.where('LOWER(title) LIKE ?', '%wonderwall%')
      expect(results).to include(song1)
      expect(results).not_to include(song2)
    end

    it 'finds songs by artist' do
      song1 = create(:song, title: 'Wonderwall', artist: 'Oasis')
      song2 = create(:song, title: 'Yellow', artist: 'Coldplay')
      
      results = Song.where('LOWER(artist) LIKE ?', '%oasis%')
      expect(results).to include(song1)
      expect(results).not_to include(song2)
    end
  end

  describe 'band filtering' do
    it 'filters songs by band' do
      band1 = create(:band, name: 'Band 1')
      band2 = create(:band, name: 'Band 2')
      
      song1 = create(:song, bands: [band1])
      song2 = create(:song, bands: [band2])
      song3 = create(:song, bands: [band1, band2])
      
      results = Song.joins(:bands).where(bands: { id: band1.id })
      expect(results).to include(song1, song3)
      expect(results).not_to include(song2)
    end
  end
end 