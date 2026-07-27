class SongVote < ActiveRecord::Base
  belongs_to :song
  belongs_to :band

  validates :ip_address, presence: true

  def self.rate_limited?(ip_address, song, band, window: 1.day)
    where(song: song, band: band, ip_address: ip_address, created_at: window.ago..).exists?
  end

  def self.voted_today?(ip_address, song, band)
    rate_limited?(ip_address, song, band, window: 1.day)
  end

  def self.retract!(ip_address, song, band, window: 1.day)
    where(song: song, band: band, ip_address: ip_address, created_at: window.ago..).delete_all
  end
end
