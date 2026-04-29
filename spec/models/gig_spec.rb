require 'spec_helper'

RSpec.describe Gig, type: :model do
  describe 'associations' do
    it 'belongs to a band' do
      band = create(:band)
      gig = create(:gig, band: band)
      
      expect(gig.band).to eq(band)
    end

    it 'belongs to a venue optionally' do
      venue = create(:venue)
      gig = create(:gig, venue: venue)
      
      expect(gig.venue).to eq(venue)
    end

    it 'has many set list songs' do
      gig = create(:gig)
      gig_song1 = create(:gig_song, gig: gig)
      gig_song2 = create(:gig_song, gig: gig)
      
      expect(gig.gig_songs).to include(gig_song1, gig_song2)
    end

    it 'has many songs through set list songs' do
      gig = create(:gig)
      song1 = create(:song)
      song2 = create(:song)
      
      create(:gig_song, gig: gig, song: song1)
      create(:gig_song, gig: gig, song: song2)
      
      expect(gig.songs).to include(song1, song2)
    end
  end

  describe 'scopes' do
    it 'orders by name' do
      gig_c = create(:gig, name: 'C Set List')
      gig_a = create(:gig, name: 'A Set List')
      gig_b = create(:gig, name: 'B Set List')

      expect(Gig.order(:name)).to eq([gig_a, gig_b, gig_c])
    end

    it 'filters public events only' do
      public_gig = create(:gig, name: 'Public Gig', private_event: false)
      private_gig = create(:gig, name: 'Private Gig', private_event: true)

      expect(Gig.public_events).to include(public_gig)
      expect(Gig.public_events).not_to include(private_gig)
    end
  end

  describe 'song management' do
    it 'can add songs to the set list' do
      gig = create(:gig)
      song = create(:song)
      
      gig_song = GigSong.create!(
        gig: gig,
        song: song,
        position: 1
      )
      
      expect(gig.songs).to include(song)
      expect(gig.gig_songs).to include(gig_song)
    end

    it 'can remove songs from the set list' do
      gig = create(:gig)
      song = create(:song)
      gig_song = create(:gig_song, gig: gig, song: song)
      
      gig_song.destroy
      
      expect(gig.reload.songs).not_to include(song)
    end

    it 'reorders songs when a song is removed' do
      gig = create(:gig)
      song1 = create(:song)
      song2 = create(:song)
      song3 = create(:song)
      
      sls1 = create(:gig_song, gig: gig, song: song1, position: 1)
      sls2 = create(:gig_song, gig: gig, song: song2, position: 2)
      sls3 = create(:gig_song, gig: gig, song: song3, position: 3)
      
      # Remove song2
      sls2.destroy
      
      # Reorder remaining songs
      gig.gig_songs.order(:position).each_with_index do |sls, index|
        sls.update(position: index + 1)
      end
      
      expect(sls1.reload.position).to eq(1)
      expect(sls3.reload.position).to eq(2)
    end
  end

  describe 'copying' do
    it 'can be copied with a new name' do
      original_gig = create(:gig, name: 'Original Set List')
      song1 = create(:song)
      song2 = create(:song)
      
      create(:gig_song, gig: original_gig, song: song1, position: 1)
      create(:gig_song, gig: original_gig, song: song2, position: 2)
      
      new_name = "Copy - #{original_gig.name}"
      new_gig = Gig.create!(
        name: new_name,
        notes: original_gig.notes,
        band: original_gig.band,
        performance_date: original_gig.performance_date
      )
      
      # Copy all songs with their positions
      original_gig.gig_songs.includes(:song).order(:position).each do |gig_song|
        GigSong.create!(
          gig_id: new_gig.id,
          song_id: gig_song.song_id,
          position: gig_song.position
        )
      end
      
      expect(new_gig.name).to eq("Copy - Original Set List")
      expect(new_gig.band).to eq(original_gig.band)
      expect(new_gig.songs.count).to eq(2)
      expect(new_gig.songs).to include(song1, song2)
    end
  end

  describe 'destruction' do
    it 'destroys associated set list songs when destroyed' do
      gig = create(:gig)
      gig_song = create(:gig_song, gig: gig)
      
      expect { gig.destroy }.to change(GigSong, :count).by(-1)
    end
  end
end 