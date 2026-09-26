class SongBand < ActiveRecord::Base
  self.table_name = 'songs_bands'
  self.primary_key = nil  # No single primary key, use composite keys

  belongs_to :song
  belongs_to :band

  validates :song_id, uniqueness: { scope: :band_id }
  validates :song, presence: true
  validates :band, presence: true

  # Scopes
  scope :practice, -> { where(practice_state: true) }
  scope :ready, -> { where(practice_state: false) }
  scope :for_band, ->(band) { where(band_id: band.id) }
  scope :for_song, ->(song) { where(song_id: song.id) }

  # Default practice_state to false if not set
  before_validation :set_default_practice_state, on: :create

  # Helper methods
  def practice?
    practice_state
  end

  def ready?
    !practice_state
  end

  def toggle_practice_state!
    new_state = !practice_state
    self.class.where(song_id: song_id, band_id: band_id).update_all(
      practice_state: new_state,
      practice_state_updated_at: Time.current
    )
    self.practice_state = new_state
    new_state
  end

  # Class method to find or create a song_band relationship
  def self.find_by_song_and_band(song, band)
    find_by(song_id: song.id, band_id: band.id)
  end

  def self.find_or_create_by_song_and_band(song, band)
    find_or_create_by(song_id: song.id, band_id: band.id)
  end

  # Votes are a same-day tally for gig-day song requests; a new day starts the count over.
  VOTES_COUNT_SQL = "CASE WHEN songs_bands.votes_date = (NOW() AT TIME ZONE 'utc')::date THEN songs_bands.votes_count ELSE 0 END".freeze

  def self.record_vote!(song, band)
    song_band = find_or_create_by_song_and_band(song, band)
    today = Time.now.utc.to_date
    scope = where(song_id: song.id, band_id: band.id)

    if song_band.votes_date == today
      scope.update_all('votes_count = votes_count + 1, total_votes_count = total_votes_count + 1')
    else
      scope.update_all(['votes_count = 1, votes_date = ?, total_votes_count = total_votes_count + 1', today])
    end
    song_band
  end

  def self.retract_vote!(song, band)
    song_band = find_by_song_and_band(song, band)
    return song_band if song_band.nil?

    if song_band.votes_date == Time.now.utc.to_date
      where(song_id: song.id, band_id: band.id)
        .update_all('votes_count = GREATEST(votes_count - 1, 0), total_votes_count = GREATEST(total_votes_count - 1, 0)')
    else
      where(song_id: song.id, band_id: band.id).update_all('total_votes_count = GREATEST(total_votes_count - 1, 0)')
    end
    song_band
  end

  def self.reset_votes_for_band!(band)
    transaction do
      where(band_id: band.id).update_all(votes_count: 0, votes_date: nil, total_votes_count: 0)
      SongVote.where(band_id: band.id).delete_all
    end
  end

  private

  def set_default_practice_state
    self.practice_state = false if self.practice_state.nil?
  end
end