class SongRecommendation < ActiveRecord::Base
  belongs_to :band

  before_validation :sanitize_fields

  validates :title, presence: true, length: { maximum: 200 }
  validates :artist, presence: true, length: { maximum: 200 }
  validates :notes, length: { maximum: 500 }, allow_blank: true
  validates :status, presence: true, inclusion: { in: %w[pending approved rejected] }
  validates :ip_address, presence: true

  scope :pending, -> { where(status: 'pending') }
  scope :approved, -> { where(status: 'approved') }
  scope :rejected, -> { where(status: 'rejected') }

  def self.rate_limited?(device_id, window: 1.hour, max: 5)
    where(device_id: device_id, created_at: window.ago..).count >= max
  end

  def self.pending_limit_reached?(band, max: 200)
    where(band: band, status: 'pending').count >= max
  end

  private

  def sanitize_fields
    self.title = title.to_s.strip.gsub(/[\r\n\t]/, ' ').squeeze(' ')[0, 200]
    self.artist = artist.to_s.strip.gsub(/[\r\n\t]/, ' ').squeeze(' ')[0, 200]
    self.notes = notes.to_s.strip[0, 500] if notes.present?
  end
end
