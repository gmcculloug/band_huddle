class User < ActiveRecord::Base
  has_secure_password validations: false  # We'll handle password validations manually
  has_many :user_bands
  has_many :bands, through: :user_bands
  has_many :blackout_dates, dependent: :destroy
  belongs_to :last_selected_band, class_name: 'Band', optional: true
  has_many :created_practices, class_name: 'Practice', foreign_key: 'created_by_user_id', dependent: :destroy
  has_many :practice_availabilities, dependent: :destroy

  # Basic validations
  validates :username, presence: true, uniqueness: { case_sensitive: false }
  validates :email, uniqueness: { case_sensitive: false }, allow_blank: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :display_name, presence: true, length: { maximum: 100 }
  validates :slug, uniqueness: true, allow_nil: true
  validates :slug, format: { with: /\A[a-z0-9\-]+\z/, message: "can only contain lowercase letters, numbers, and hyphens" }, allow_blank: true

  # Password validations - only required if no OAuth provider
  validates :password, length: { minimum: 6 }, if: :password_required?
  validates :password_digest, presence: true, if: :password_required?

  # OAuth validations
  validates :oauth_provider, inclusion: { in: ['google', 'github'] }, allow_nil: true
  validates :oauth_uid, presence: true, if: :oauth_provider?
  validates :oauth_uid, uniqueness: { scope: :oauth_provider }, if: :oauth_provider?
  validates :oauth_provider, uniqueness: { scope: :id }, if: :oauth_provider?

  # Ensure user has at least one authentication method
  validate :must_have_authentication_method

  # Set default display name before validation if not set
  before_validation :set_default_display_name, on: :create
  after_create :generate_slug_after_create, if: -> { slug.blank? }

  # Helper methods for checking ownership and membership
  def owner_of?(band)
    return false unless band
    user_bands.exists?(band_id: band.id, role: 'owner')
  end

  def member_of?(band)
    return false unless band
    user_bands.exists?(band_id: band.id)
  end

  # OAuth helper methods
  def oauth_user?
    oauth_provider.present? && oauth_uid.present?
  end

  def password_user?
    password_digest.present?
  end

  def can_unlink_oauth?
    oauth_user? && password_user?
  end

  def oauth_display_name
    oauth_username || email&.split('@')&.first || username
  end

  def has_oauth_provider?(provider)
    oauth_provider == provider.to_s
  end

  # Public profile helper
  def public_profile_enabled?
    # Use read_attribute to access boolean directly
    # Returns false if column doesn't exist (for backward compatibility)
    self.class.column_names.include?('public_profile_enabled') &&
      read_attribute(:public_profile_enabled) == true
  end

  # Display name helpers
  def display_name_or_fallback
    display_name.presence || default_display_name
  end

  def default_display_name
    if oauth_user?
      oauth_username.presence || oauth_email&.split('@')&.first
    end || email&.split('@')&.first || username
  end

  # Override authenticate to work with OAuth users
  def authenticate(password)
    return false if oauth_user? && !password_user?  # OAuth-only users can't login with password
    return false if password.blank?

    super(password)
  end

  # Ensures slug uniqueness when manually updated
  # Appends random number if the desired slug is taken
  def ensure_slug_uniqueness(desired_slug)
    base_slug = desired_slug.parameterize
    candidate_slug = base_slug

    # Ensure uniqueness by appending random numbers if needed
    while User.where(slug: candidate_slug).where.not(id: id).exists?
      candidate_slug = "#{base_slug}-#{rand(1000..9999)}"
    end

    candidate_slug
  end

  private

  # Validation helper methods
  def password_required?
    !oauth_user? && password_digest_changed?
  end

  def must_have_authentication_method
    unless oauth_user? || password_digest.present?
      errors.add(:base, "Must have either password or OAuth authentication")
    end
  end

  def set_default_display_name
    return if display_name.present?
    self.display_name = default_display_name
  end

  # Generates slug after create when username is available
  # Default value is the user's username (parameterized)
  # If slug already exists, append random number to make it unique
  def generate_slug_after_create
    base_slug = username.parameterize
    candidate_slug = base_slug

    # Ensure uniqueness by appending random numbers if needed
    while User.where(slug: candidate_slug).where.not(id: id).exists?
      candidate_slug = "#{base_slug}-#{rand(1000..9999)}"
    end

    update_column(:slug, candidate_slug)
  end
end