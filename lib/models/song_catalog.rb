class SongCatalog < ActiveRecord::Base
  include Archivable
  include HttpUrlValidation
  include StripsWhitespace
  validates_http_url :url
  has_many :songs
  
  validates :title, presence: true
  validates :artist, presence: true
  validates :key, presence: true
  validates :duration, presence: true
  validates :tempo, numericality: { greater_than: 0 }, allow_nil: true
  
  # Scope for searching global songs
  scope :search, ->(query) {
    where('LOWER(title) LIKE ? OR LOWER(artist) LIKE ?', "%#{query.downcase}%", "%#{query.downcase}%") if query.present?
  }
end
