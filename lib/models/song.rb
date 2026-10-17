class Song < ActiveRecord::Base
  include Archivable
  include HttpUrlValidation
  include StripsWhitespace
  validates_http_url :url
  belongs_to :song_catalog, optional: true
  has_many :song_bands, dependent: :destroy
  has_many :bands, through: :song_bands
  has_many :gig_songs
  has_many :gigs, through: :gig_songs
  
  validates :title, presence: true
  validates :artist, presence: true
  validates :key, presence: true
  validates :duration, presence: true
  validates :tempo, numericality: { greater_than: 0 }, allow_nil: true
  
  # Scopes
  scope :by_band, ->(band) { joins(:bands).where(bands: { id: band.id }) }
  scope :by_artist, ->(artist) { where('LOWER(artist) LIKE ?', "%#{artist.downcase}%") }
  scope :by_title, ->(title) { where('LOWER(title) LIKE ?', "%#{title.downcase}%") }
  scope :search, ->(query) { where('LOWER(title) LIKE ? OR LOWER(artist) LIKE ?', "%#{query.downcase}%", "%#{query.downcase}%") }
  scope :with_lyrics, -> { where.not(lyrics: [nil, '']) }
  scope :by_key, ->(key) { where(key: key) }
  scope :by_tempo_range, ->(min, max) { where(tempo: min..max) }
  scope :practice_for_band, ->(band) { joins(:bands).where(bands: { id: band.id }, 'songs_bands.practice_state': true) }
  scope :ready_for_band, ->(band) { joins(:bands).where(bands: { id: band.id }, 'songs_bands.practice_state': false) }

  # Create a band-specific copy from song catalog
  def self.create_from_song_catalog(song_catalog, band_ids = [])
    song = new(
      title: song_catalog.title,
      artist: song_catalog.artist,
      key: song_catalog.key,
      original_key: song_catalog.original_key,
      tempo: song_catalog.tempo,
      genre: song_catalog.genre,
      url: song_catalog.url,
      notes: song_catalog.notes,
      duration: song_catalog.duration,
      year: song_catalog.year,
      album: song_catalog.album,
      lyrics: song_catalog.lyrics,
      song_catalog: song_catalog
    )
    song.band_ids = band_ids
    song
  end

  # Practice state methods for band-specific practice management
  def practice_for_band?(band)
    song_band = SongBand.find_by_song_and_band(self, band)
    song_band&.practice_state || false
  end

  def ready_for_band?(band)
    !practice_for_band?(band)
  end

  def toggle_practice_for_band!(band)
    song_band = SongBand.find_or_create_by_song_and_band(self, band)
    song_band.toggle_practice_state!
  end

  def set_practice_for_band!(band, practice_state)
    song_band = SongBand.find_or_create_by_song_and_band(self, band)
    song_band.practice_state = practice_state
    song_band.practice_state_updated_at = Time.current
    song_band.save!
    practice_state
  end

end
