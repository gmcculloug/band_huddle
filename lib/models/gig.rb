class Gig < ActiveRecord::Base
  belongs_to :band
  belongs_to :venue, optional: true
  has_many :gig_songs, dependent: :destroy
  has_many :songs, through: :gig_songs
  
  validates :name, presence: true
  validates :band, presence: true
  validates :performance_date, presence: true

  # Scopes
  scope :upcoming, -> { where('performance_date >= ?', Date.current) }
  scope :past, -> { where('performance_date < ?', Date.current) }
  scope :by_date_range, ->(start_date, end_date) { where(performance_date: start_date..end_date) }
  scope :by_band, ->(band) { where(band: band) }
  scope :with_venue, -> { joins(:venue) }
  scope :without_venue, -> { left_joins(:venue).where(venues: { id: nil }) }
  scope :chronological, -> { order(:performance_date) }
  scope :reverse_chronological, -> { order(performance_date: :desc) }
  scope :public_events, -> { where(private_event: false) }
end