class Band < ActiveRecord::Base
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
  validates :timezone, inclusion: { in: ActiveSupport::TimeZone.all.flat_map { |tz| [tz.name, tz.tzinfo.name] } }, allow_nil: true
  validates :google_calendar_id, presence: true, if: :google_calendar_enabled?

  before_save :generate_slug

  def google_calendar_enabled?
    read_attribute(:google_calendar_enabled) == true
  end

  def public_schedule_enabled?
    read_attribute(:public_schedule_enabled) == true
  end

  def band_timezone
    timezone.presence || 'UTC'
  end
  
  def owner?
    owners.exists?
  end
  
  def owned_by?(user)
    return false unless user
    user_bands.exists?(user_id: user.id, role: 'owner')
  end
  
  def owner_of?(user)
    return false unless user
    user_bands.exists?(user_id: user.id, role: 'owner')
  end
  
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

  # Regenerates slug from name on every save. Changing a band name will update
  # the slug, which silently breaks any previously shared public schedule URLs.
  def generate_slug
    self.slug = name.parameterize if name.present?
  end
end