require_relative '../spec_helper'

RSpec.describe SongCatalog, type: :model do
  describe 'validations' do
    it 'allows a valid http streaming URL' do
      song_catalog = SongCatalog.new(
        title: 'Test Song',
        artist: 'Test Artist',
        key: 'C',
        duration: '3:45',
        url: 'http://example.com/stream'
      )

      expect(song_catalog).to be_valid
    end

    it 'rejects unsafe and malformed streaming URLs' do
      unsafe_song_catalog = SongCatalog.new(
        title: 'Test Song',
        artist: 'Test Artist',
        key: 'C',
        duration: '3:45',
        url: 'javascript:alert(1)'
      )
      malformed_song_catalog = SongCatalog.new(
        title: 'Test Song',
        artist: 'Test Artist',
        key: 'C',
        duration: '3:45',
        url: 'not a url'
      )

      expect(unsafe_song_catalog).not_to be_valid
      expect(unsafe_song_catalog.errors[:url]).to include('must be a valid http:// or https:// URL')
      expect(malformed_song_catalog).not_to be_valid
      expect(malformed_song_catalog.errors[:url]).to include('must be a valid http:// or https:// URL')
    end

    it 'is valid with valid attributes' do
      song_catalog = SongCatalog.new(
        title: 'Test Song',
        artist: 'Test Artist',
        key: 'C',
        duration: '3:45'
      )
      expect(song_catalog).to be_valid
    end

    it 'is invalid without a title' do
      song_catalog = SongCatalog.new(
        artist: 'Test Artist',
        key: 'C'
      )
      expect(song_catalog).not_to be_valid
      expect(song_catalog.errors[:title]).to include("can't be blank")
    end

    it 'is invalid without an artist' do
      song_catalog = SongCatalog.new(
        title: 'Test Song',
        key: 'C'
      )
      expect(song_catalog).not_to be_valid
      expect(song_catalog.errors[:artist]).to include("can't be blank")
    end

    it 'is invalid without a key' do
      song_catalog = SongCatalog.new(
        title: 'Test Song',
        artist: 'Test Artist'
      )
      expect(song_catalog).not_to be_valid
      expect(song_catalog.errors[:key]).to include("can't be blank")
    end

    it 'validates tempo is positive when present' do
      song_catalog = SongCatalog.new(
        title: 'Test Song',
        artist: 'Test Artist',
        key: 'C',
        tempo: -10
      )
      expect(song_catalog).not_to be_valid
      expect(song_catalog.errors[:tempo]).to include("must be greater than 0")
    end

    it 'allows nil tempo' do
      song_catalog = SongCatalog.new(
        title: 'Test Song',
        artist: 'Test Artist',
        key: 'C',
        duration: '3:45',
        tempo: nil
      )
      expect(song_catalog).to be_valid
    end

    it 'allows positive tempo' do
      song_catalog = SongCatalog.new(
        title: 'Test Song',
        artist: 'Test Artist',
        key: 'C',
        duration: '3:45',
        tempo: 120
      )
      expect(song_catalog).to be_valid
    end
  end

  describe 'associations' do
    it 'has many songs' do
      song_catalog = SongCatalog.create!(
        title: 'Test Song',
        artist: 'Test Artist',
        key: 'C',
        duration: '3:45'
      )

      song1 = Song.create!(
        title: 'Test Song',
        artist: 'Test Artist',
        key: 'C',
        duration: '3:45',
        song_catalog: song_catalog
      )

      song2 = Song.create!(
        title: 'Test Song',
        artist: 'Test Artist',
        key: 'C',
        duration: '3:45',
        song_catalog: song_catalog
      )

      expect(song_catalog.songs).to include(song1, song2)
      expect(song_catalog.songs.count).to eq(2)
    end
  end

  describe 'scopes' do
    let!(:song1) do
      SongCatalog.create!(
        title: 'Hotel California',
        artist: 'Eagles',
        key: 'Bm',
        duration: '6:30'
      )
    end

    let!(:song2) do
      SongCatalog.create!(
        title: 'Stairway to Heaven',
        artist: 'Led Zeppelin',
        key: 'Am',
        duration: '8:02'
      )
    end

    let!(:song3) do
      SongCatalog.create!(
        title: 'Wonderwall',
        artist: 'Oasis',
        key: 'Em',
        duration: '4:18'
      )
    end

    describe '.search' do
      it 'finds songs by title' do
        results = SongCatalog.search('hotel')
        expect(results).to include(song1)
        expect(results).not_to include(song2, song3)
      end

      it 'finds songs by artist' do
        results = SongCatalog.search('eagles')
        expect(results).to include(song1)
        expect(results).not_to include(song2, song3)
      end

      it 'is case insensitive' do
        results = SongCatalog.search('HOTEL')
        expect(results).to include(song1)

        results = SongCatalog.search('EAGLES')
        expect(results).to include(song1)
      end

      it 'finds multiple results' do
        results = SongCatalog.search('e') # matches Eagles, Led Zeppelin, and Oasis
        expect(results.count).to eq(3) # All songs match the letter 'e'
        expect(results).to include(song1, song2, song3)
      end

      it 'returns empty when no matches' do
        results = SongCatalog.search('nonexistent')
        expect(results).to be_empty
      end

      it 'returns all songs when query is blank' do
        results = SongCatalog.search('')
        expect(results.count).to eq(3)
        expect(results.to_a).to match_array([song1, song2, song3])
      end

      it 'returns all songs when query is nil' do
        results = SongCatalog.search(nil)
        expect(results.count).to eq(3)
        expect(results.to_a).to match_array([song1, song2, song3])
      end
    end
  end
end
