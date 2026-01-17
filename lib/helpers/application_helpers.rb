require_relative 'icon_helpers'

module ApplicationHelpers
  include IconHelpers
  # Authentication helpers
  def current_user
    # Return cached user if already loaded
    return @current_user if @current_user

    if settings.test?
      # In test mode, try to get user from test session
      test_user_id = @test_session&.dig(:user_id) || session[:user_id]
      @current_user = User.find(test_user_id) if test_user_id
    else
      # Check for JWT token first (for mobile API)
      @current_user = user_from_jwt_token

      # Fall back to session (for web)
      @current_user ||= user_from_session
    end

    @current_user
  end

  def logged_in?
    !!current_user
  end

  def require_login
    unless logged_in?
      redirect '/login'
    end
  end

  def require_api_auth
    unless logged_in?
      content_type :json
      status 401
      halt({ error: 'Authentication required', code: 'UNAUTHORIZED' }.to_json)
    end
  end

  def current_band
    if settings.test?
      # In test mode, try to get band from test session
      test_band_id = @test_session&.dig(:band_id) || session[:band_id]
      if test_band_id && logged_in?
        current_user.bands.find_by(id: test_band_id)
      end
    elsif session[:band_id] && logged_in?
      current_user.bands.find_by(id: session[:band_id])
    end
  end

  def user_bands
    logged_in? ? current_user.bands.order(:name) : Band.none
  end
  
  def current_user_owner_of?(band)
    return false unless band && logged_in?
    current_user.owner_of?(band)
  end
  
  def current_user_member_of?(band)
    return false unless band && logged_in?
    current_user.member_of?(band)
  end

  def filter_by_current_band(collection)
    return collection.none unless current_band && collection.respond_to?(:where)

    case collection.name
    when 'Song'
      collection.joins(:bands).where(bands: { id: current_band.id })
    when 'Gig'
      collection.where(band: current_band)
    when 'Venue'
      collection.where(band: current_band)
    else
      collection
    end
  end

  # Helper method for getting gigs based on view mode
  def gigs_for_view_mode(view_mode, user)
    if view_mode == 'all' && user.bands.count > 1
      user_band_ids = user.bands.pluck(:id)
      Gig.joins(:band).where(bands: { id: user_band_ids }).includes(:venue, :band)
    elsif current_band
      filter_by_current_band(Gig).includes(:venue)
    else
      Gig.none
    end
  end
  
  # Calendar helper methods
  def calendar_days_for_month(year, month)
    start_date = Date.new(year, month, 1)
    
    # Get last day of month
    next_month = month == 12 ? Date.new(year + 1, 1, 1) : Date.new(year, month + 1, 1)
    end_date = next_month - 1
    
    # Get the first day of the calendar (Sunday of the week containing the 1st)
    days_back_to_sunday = start_date.wday
    calendar_start = start_date - days_back_to_sunday
    
    # Get the last day of the calendar (Saturday of the week containing the last day)
    days_forward_to_saturday = 6 - end_date.wday
    calendar_end = end_date + days_forward_to_saturday
    
    # Generate all days in the calendar
    (calendar_start..calendar_end).to_a
  end
  
  def gigs_for_date(date, current_band_gigs: [], other_band_gigs: [], band_huddle_conflicts: [], blackout_dates: [])
    gigs = {}
    
    # Current band gigs
    current_band_gigs.select { |gig| gig.performance_date == date }.each do |gig|
      gigs[:current] ||= []
      gigs[:current] << gig
    end
    
    # Other band gigs
    other_band_gigs.select { |gig| gig.performance_date == date }.each do |gig|
      gigs[:other] ||= []
      gigs[:other] << gig
    end
    
    # Band Huddle conflicts
    band_huddle_conflicts.select { |gig| gig.performance_date == date }.each do |gig|
      gigs[:conflicts] ||= []
      gigs[:conflicts] << gig
    end
    
    # Blackout dates
    blackout_dates.select { |blackout| blackout.blackout_date == date }.each do |blackout|
      gigs[:blackouts] ||= []
      gigs[:blackouts] << blackout
    end
    
    gigs
  end

  # Legacy method for backward compatibility
  def gigs_for_date_legacy(date)
    gigs_for_date(
      date,
      current_band_gigs: @current_band_gigs || [],
      other_band_gigs: @other_band_gigs || [],
      band_huddle_conflicts: @band_huddle_conflicts || [],
      blackout_dates: @blackout_dates || []
    )
  end
  
  def month_name(month)
    Date::MONTHNAMES[month]
  end
  
  def prev_month_link(year, month)
    if month == 1
      "/calendar?year=#{year - 1}&month=12"
    else
      "/calendar?year=#{year}&month=#{month - 1}"
    end
  end
  
  def next_month_link(year, month)
    if month == 12
      "/calendar?year=#{year + 1}&month=1"
    else
      "/calendar?year=#{year}&month=#{month + 1}"
    end
  end

  # Breadcrumb helper methods
  def set_breadcrumbs(*crumbs)
    @breadcrumbs = []

    # Always start with Home
    @breadcrumbs << { label: '', icon: breadcrumb_icon(:home), url: '/gigs' }

    # Add provided breadcrumbs
    crumbs.each do |crumb|
      @breadcrumbs << crumb
    end
  end

  def add_breadcrumb(label, url = nil, icon = nil)
    @breadcrumbs ||= []
    @breadcrumbs << { label: label, url: url, icon: icon }
  end

  # Redirect path mapping for band selection
  def redirect_path_for_section(current_path)
    SECTION_REDIRECTS.each do |pattern, redirect|
      return redirect if current_path.match?(pattern)
    end
    '/gigs' # default fallback
  end

  def breadcrumb_for_section(section)
    section_key = section.to_s.downcase

    # Map section names to icon keys and URLs
    section_config = {
      'gigs' => { label: 'Gigs', icon_key: :gigs, url: '/gigs' },
      'songs' => { label: 'Songs', icon_key: :songs, url: '/songs' },
      'venues' => { label: 'Venues', icon_key: :venues, url: '/venues' },
      'calendar' => { label: 'Calendar', icon_key: :calendar, url: '/calendar' },
      'practices' => { label: 'Practice', icon_key: :practices, url: '/practices' },
      'bands' => { label: 'Bands', icon_key: :bands, url: '/bands' },
      'profile' => { label: 'Profile', icon_key: :profile, url: '/profile' },
      'song_catalogs' => { label: 'Song Catalog', icon_key: :song_catalog, url: '/song_catalogs' }
    }

    if config = section_config[section_key]
      {
        label: config[:label],
        icon: breadcrumb_icon(config[:icon_key]),
        url: config[:url]
      }
    else
      { label: section.to_s.capitalize, icon: '', url: nil }
    end
  end

  # Section redirect mappings for band selection
  SECTION_REDIRECTS = {
    /^\/songs/ => '/songs',
    /^\/venues/ => '/venues',
    /^\/gigs/ => '/gigs',
    /^\/calendar/ => '/calendar',
    /^\/profile/ => '/profile',
    /^\/song_catalog/ => '/songs'
  }.freeze

  # Band color helper - generates consistent colors for band labels
  def band_label_color(band)
    # Define a palette of visually distinct, bold colors
    # Each color is a hash with background and text colors
    color_palette = [
      { bg: '#3b82f6', text: '#ffffff' },  # Bold Blue
      { bg: '#10b981', text: '#ffffff' },  # Bold Green
      { bg: '#ec4899', text: '#ffffff' },  # Bold Pink
      { bg: '#f59e0b', text: '#ffffff' },  # Bold Amber
      { bg: '#6366f1', text: '#ffffff' },  # Bold Indigo
      { bg: '#f97316', text: '#ffffff' },  # Bold Orange
      { bg: '#e11d48', text: '#ffffff' },  # Bold Rose
      { bg: '#06b6d4', text: '#ffffff' },  # Bold Cyan
      { bg: '#8b5cf6', text: '#ffffff' },  # Bold Purple
      { bg: '#84cc16', text: '#ffffff' }   # Bold Lime
    ]

    # Use band ID to consistently select a color from the palette
    index = band.id % color_palette.length
    color_palette[index]
  end

  # OAuth helper methods
  def oauth_provider_configured?(provider)
    require_relative '../services/oauth_service'
    OauthService.provider_configured?(provider)
  end

  def configured_oauth_providers
    require_relative '../services/oauth_service'
    OauthService.configured_providers
  end

  private

  # Extract user from JWT token
  def user_from_jwt_token
    return nil unless request.env['HTTP_AUTHORIZATION']

    auth_header = request.env['HTTP_AUTHORIZATION']
    return nil unless auth_header.start_with?('Bearer ')

    token = auth_header.split(' ')[1]
    return nil unless token

    # Use JWT service to authenticate token
    require_relative '../services/jwt_service'
    JwtService.authenticate_token(token)
  rescue => e
    # Log error but don't expose details to client
    puts "JWT authentication error: #{e.message}" if settings.development?
    nil
  end

  # Extract user from session
  def user_from_session
    return nil unless session[:user_id]

    begin
      User.find(session[:user_id])
    rescue ActiveRecord::RecordNotFound
      # Clear invalid session
      session.delete(:user_id)
      nil
    end
  end
end