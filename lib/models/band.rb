require 'uri'

class Band < ActiveRecord::Base
  SOCIAL_MEDIA_PLATFORMS = {
    'facebook' => 'Facebook',
    'instagram' => 'Instagram',
    'x' => 'X',
    'youtube' => 'YouTube',
    'tiktok' => 'TikTok',
    'spotify' => 'Spotify',
    'website' => 'Website'
  }.freeze

  # Text shown for the tip link on public pages when no custom text is set
  DEFAULT_TIP_TEXT = '💗 Tip the Band'

  include StripsWhitespace

  belongs_to :owner, class_name: 'User', optional: true
  has_many :song_bands, dependent: :destroy
  has_many :songs, through: :song_bands
  has_many :gigs
  has_many :venues
  has_many :user_bands, dependent: :destroy
  has_many :users, through: :user_bands
  has_many :owner_user_bands, -> { where(role: 'owner') }, class_name: 'UserBand'
  has_many :owners, through: :owner_user_bands, source: :user
  has_many :google_calendar_events, dependent: :destroy
  has_many :practices, dependent: :destroy
  
  validates :name, presence: true
  validates :name, uniqueness: true
  validates :slug, uniqueness: true, allow_nil: true
  validates :logo_shape, inclusion: { in: %w[round square] }
  validates :google_calendar_id, presence: true, if: :google_calendar_enabled?
  validates :tip_text, length: { maximum: 80 }
  validate :tip_url_must_be_http_url

  before_save :generate_slug, if: -> { new_record? || slug.blank? }

  def google_calendar_enabled?
    read_attribute(:google_calendar_enabled) == true
  end

  def public_schedule_enabled?
    read_attribute(:public_schedule_enabled) == true
  end

  def public_songs_enabled?
    read_attribute(:public_songs_enabled) == true
  end

  # Text displayed on the public tip link; falls back to the default
  # when no custom text is set.
  def tip_link_text
    tip_text.presence || DEFAULT_TIP_TEXT
  end

  def owner?
    owners.exists?
  end

  def owned_by?(user)
    return false unless user
    user_bands.exists?(user_id: user.id, role: 'owner')
  end

  # Alias for clarity - same as owned_by?
  alias_method :owner_of?, :owned_by?

  def owner_users
    owners
  end

  # Google Calendar integration methods
  def google_calendar_service
    @google_calendar_service ||= GoogleCalendarService.new(self)
  end

  def sync_gig_to_google_calendar(gig)
    return false unless google_calendar_enabled?
    google_calendar_service.sync_gig_to_calendar(gig)
  end

  def remove_gig_from_google_calendar(gig)
    return false unless google_calendar_enabled?
    google_calendar_service.remove_gig_from_calendar(gig)
  end

  def sync_all_gigs_to_google_calendar
    return false unless google_calendar_enabled?
    google_calendar_service.sync_all_gigs
  end

  def test_google_calendar_connection
    return { success: false, error: 'Google Calendar not enabled' } unless google_calendar_enabled?
    google_calendar_service.test_connection
  end

  private

  def tip_url_must_be_http_url
    return if tip_url.blank?

    parsed_url = URI.parse(tip_url)
    return if %w[http https].include?(parsed_url.scheme&.downcase) && parsed_url.host.present?

    errors.add(:tip_url, 'must be a valid http:// or https:// URL')
  rescue URI::InvalidURIError
    errors.add(:tip_url, 'must be a valid http:// or https:// URL')
  end

  # Generates slug on create or when slug is blank (e.g. backfilled records).
  # Slug is intentionally left unchanged on updates to preserve public URLs.
  def generate_slug
    self.slug = name.parameterize if name.present?
  end
end
