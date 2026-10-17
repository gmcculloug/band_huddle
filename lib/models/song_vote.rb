class SongVote < ActiveRecord::Base
  belongs_to :song
  belongs_to :band

  validates :ip_address, presence: true
  validates :device_id, presence: true

  def self.rate_limited?(device_id, song, band, window: 1.day)
    where(song: song, band: band, device_id: device_id, created_at: window.ago..).exists?
  end

  def self.rate_limited_for_device_or_ip?(device_id, ip_address, song, band, window: 1.day)
    scope = where(song: song, band: band, created_at: window.ago..)
    device_scope = scope.where(device_id: device_id)
    return device_scope.exists? if ip_address.blank?

    device_scope.or(scope.where(ip_address: ip_address)).exists?
  end

  def self.band_rate_limited?(device_id, ip_address, band, window: 1.hour, max: 25)
    where(band: band, created_at: window.ago..)
      .where('device_id = ? OR ip_address = ?', device_id, ip_address)
      .count >= max
  end

  def self.voted_today?(device_id, song, band)
    rate_limited?(device_id, song, band, window: 1.day)
  end

  def self.retract!(device_id, song, band, window: 1.day)
    where(song: song, band: band, device_id: device_id, created_at: window.ago..).delete_all
  end
end
