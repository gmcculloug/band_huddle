class SongVote < ActiveRecord::Base
  belongs_to :song
  belongs_to :band

  validates :ip_address, presence: true
  validates :device_id, presence: true

  def self.rate_limited?(device_id, song, band, window: 1.day)
    where(song: song, band: band, device_id: device_id, created_at: window.ago..).exists?
  end

  def self.voted_today?(device_id, song, band)
    rate_limited?(device_id, song, band, window: 1.day)
  end

  def self.retract!(device_id, song, band, window: 1.day)
    where(song: song, band: band, device_id: device_id, created_at: window.ago..).delete_all
  end
end
