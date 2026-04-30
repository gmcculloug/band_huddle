require 'sinatra/base'

module Routes
end

class Routes::Practices < Sinatra::Base
  configure do
    set :views, File.join(File.dirname(__FILE__), '..', '..', 'views')
  end

  helpers ApplicationHelpers

  # ============================================================================
  # PRACTICE ROUTES
  # ============================================================================

  get '/practices' do
    require_login

    # If user has no bands, redirect to create or join a band
    if user_bands.empty?
      redirect '/bands/new?first_band=true'
    end

    # If no band is selected, redirect to band selection
    unless current_band
      redirect '/bands'
    end

    # Set breadcrumbs
    set_breadcrumbs(breadcrumb_for_section('practices'))

    @practices = current_band.practices.includes(:created_by_user)
    today = Date.current

    # Active practices: end_date is today or in the future
    @active_practices = @practices.where('end_date >= ?', today).order(start_date: :asc)

    # Count of archived practices for display
    @archived_practices_count = @practices.where('end_date < ?', today).count

    erb :practices
  end

  get '/practices/past' do
    require_login

    # If user has no bands, redirect to create or join a band
    if user_bands.empty?
      redirect '/bands/new?first_band=true'
    end

    # If no band is selected, redirect to band selection
    unless current_band
      redirect '/bands'
    end

    # Set breadcrumbs
    set_breadcrumbs(
      breadcrumb_for_section('practices'),
      { label: 'Past Practices', icon: '', url: nil }
    )

    @practices = current_band.practices.includes(:created_by_user)
    today = Date.current

    # Archived practices: end_date is in the past
    @archived_practices = @practices.where('end_date < ?', today).order(start_date: :asc)

    erb :past_practices
  end

  get '/practices/new' do
    require_login
    return redirect '/practices' unless current_band

    # Set breadcrumbs
    set_breadcrumbs(
      breadcrumb_for_section('practices'),
      { label: 'New', icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px; margin-right: 6px;"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="8" x2="12" y2="16"></line><line x1="8" y1="12" x2="16" y2="12"></line></svg>', url: nil }
    )

    @practice = Practice.new
    erb :new_practice
  end

  post '/practices' do
    require_login
    return redirect '/practices' unless current_band

    # Parse the start and end dates
    unless params[:start_date]
      @error = "Start date is required"
      return erb :new_practice
    end

    unless params[:end_date]
      @error = "End date is required"
      return erb :new_practice
    end

    begin
      start_date = Date.parse(params[:start_date])
      end_date = Date.parse(params[:end_date])
    rescue Date::Error
      @error = "Invalid date format"
      return erb :new_practice
    end

    # Validate that end date is after or equal to start date
    if end_date < start_date
      @error = "End date must be after or equal to start date"
      return erb :new_practice
    end

    # Parse start_time if provided - stored as UTC, browser handles timezone display
    start_time = nil
    if params[:start_time] && !params[:start_time].empty?
      begin
        # Parse time and store as UTC
        parsed_time = Time.parse(params[:start_time])
        start_time = parsed_time.utc
      rescue ArgumentError
        @error = "Invalid start time format"
        return erb :new_practice
      end
    end

    # Parse duration if provided
    duration = nil
    if params[:duration] && !params[:duration].empty?
      duration = params[:duration].to_i
      if duration <= 0
        @error = "Duration must be a positive number"
        return erb :new_practice
      end
    end

    @practice = current_band.practices.new(
      start_date: start_date,
      end_date: end_date,
      title: params[:title],
      description: params[:description],
      start_time: start_time,
      duration: duration,
      created_by_user: current_user
    )

    if @practice.save
      redirect "/practices/#{@practice.id}"
    else
      @error = @practice.errors.full_messages.join(', ')
      erb :new_practice
    end
  end

  get '/practices/:id' do
    require_login
    return redirect '/practices' unless current_band

    @practice = current_band.practices.find_by(id: params[:id])
    return redirect '/practices' unless @practice

    # Set breadcrumbs
    breadcrumb_label = @practice.title.present? ? "#{@practice.title} #{@practice.formatted_week_range}" : "Practice #{@practice.formatted_week_range}"
    set_breadcrumbs(
      breadcrumb_for_section('practices'),
      { label: breadcrumb_label, url: nil }
    )

    @band_members = current_band.users.order(:username)
    @current_user_availabilities = @practice.practice_availabilities.where(user: current_user).index_by(&:specific_date)
    @availability_summary = @practice.availability_summary
    @best_day = @practice.best_day

    erb :show_practice
  end

  get '/practices/:id/edit' do
    require_login
    return redirect '/practices' unless current_band

    @practice = current_band.practices.find_by(id: params[:id])
    return redirect '/practices' unless @practice

    # Only the creator or band owner can edit
    unless @practice.created_by_user == current_user || current_band.owned_by?(current_user)
      redirect "/practices/#{@practice.id}"
      return
    end

    # Set breadcrumbs
    breadcrumb_label = @practice.title.present? ? "Edit #{@practice.title}" : "Edit Practice"
    set_breadcrumbs(
      breadcrumb_for_section('practices'),
      { label: @practice.title.present? ? "#{@practice.title} #{@practice.formatted_week_range}" : "Practice #{@practice.formatted_week_range}", url: "/practices/#{@practice.id}" },
      { label: 'Edit', icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: -2px; margin-right: 6px;"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"></path><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"></path></svg>', url: nil }
    )

    erb :edit_practice
  end


  post '/practices/:id/responses' do
    require_login
    return redirect '/practices' unless current_band

    @practice = current_band.practices.find_by(id: params[:id])
    return redirect '/practices' unless @practice

    # Clear all existing availability for this practice
    @practice.practice_availabilities.destroy_all

    # Process availability data for all users from the responses form
    current_band.users.each do |user|
      @practice.practice_dates.each do |date|
        date_key = date.strftime('%Y-%m-%d')
        availability_param = params["user_#{user.id}_date_#{date_key}"]

        # Skip if no availability is set or if it's empty
        next unless availability_param && !availability_param.empty?

        # Get notes data for this specific user
        notes_param = params["user_#{user.id}_notes_#{date_key}"]

        @practice.practice_availabilities.create!(
          user: user,
          specific_date: date,
          availability: availability_param,
          notes: notes_param,
          suggested_start_time: nil,
          suggested_end_time: nil
        )
      end
    end

    # Check if this is an auto-save request (AJAX/fetch)
    if request.xhr? || params[:auto_save] == 'true'
      content_type :json
      { success: true, message: 'Availability saved successfully' }.to_json
    else
      redirect "/practices/#{@practice.id}"
    end
  end

  post '/practices/:id/availability' do
    require_login
    return redirect '/practices' unless current_band

    @practice = current_band.practices.find_by(id: params[:id])
    return redirect '/practices' unless @practice

    # Clear existing availability for this user on this practice
    @practice.practice_availabilities.where(user: current_user).destroy_all

    # Process availability data from the test format
    # Check if params are nested under a 'params' key (from test)
    availability_params = params[:params] || params

    availability_params.each do |key, value|
      # Look for availability_YYYY-MM-DD parameters
      if key.match(/^availability_(.+)$/) && value.present?
        date_key = $1
        begin
          specific_date = Date.parse(date_key)
          # Validate the date is within the practice period
          next unless @practice.practice_dates.include?(specific_date)

          notes_param = availability_params["notes_#{date_key}"]

          @practice.practice_availabilities.create!(
            user: current_user,
            specific_date: specific_date,
            availability: value,
            notes: notes_param,
            suggested_start_time: nil,
            suggested_end_time: nil
          )
        rescue Date::Error
          # Skip invalid date formats
          next
        end
      end
    end

    redirect "/practices/#{@practice.id}"
  end

  post '/practices/:id/finalize' do
    require_login
    return redirect '/practices' unless current_band

    @practice = current_band.practices.find_by(id: params[:id])
    return redirect '/practices' unless @practice

    # Only the creator or band owner can finalize
    unless @practice.created_by_user == current_user || current_band.owned_by?(current_user)
      redirect "/practices/#{@practice.id}"
      return
    end

    @practice.update!(status: 'finalized')
    redirect "/practices/#{@practice.id}"
  end

  post '/practices/:id/reopen' do
    require_login
    return redirect '/practices' unless current_band

    @practice = current_band.practices.find_by(id: params[:id])
    return redirect '/practices' unless @practice

    # Only the creator or band owner can reopen
    unless @practice.created_by_user == current_user || current_band.owned_by?(current_user)
      redirect "/practices/#{@practice.id}"
      return
    end

    @practice.update!(status: 'active')
    redirect "/practices/#{@practice.id}"
  end

  put '/practices/:id' do
    require_login
    return redirect '/practices' unless current_band

    @practice = current_band.practices.find_by(id: params[:id])
    return redirect '/practices' unless @practice

    # Only the creator or band owner can edit
    unless @practice.created_by_user == current_user || current_band.owned_by?(current_user)
      redirect "/practices/#{@practice.id}"
      return
    end

    # Parse the start and end dates
    unless params[:start_date]
      @error = "Start date is required"
      return erb :edit_practice
    end

    unless params[:end_date]
      @error = "End date is required"
      return erb :edit_practice
    end

    begin
      start_date = Date.parse(params[:start_date])
      end_date = Date.parse(params[:end_date])
    rescue Date::Error
      @error = "Invalid date format"
      return erb :edit_practice
    end

    # Validate that end date is after or equal to start date
    if end_date < start_date
      @error = "End date must be after or equal to start date"
      # Set the form values so they're preserved in the error view
      @practice.title = params[:title] if params[:title]
      @practice.description = params[:description] if params[:description]
      return erb :edit_practice
    end

    # Parse start_time if provided - stored as UTC, browser handles timezone display
    start_time = nil
    if params[:start_time] && !params[:start_time].empty?
      begin
        # Parse time and store as UTC
        parsed_time = Time.parse(params[:start_time])
        start_time = parsed_time.utc
      rescue ArgumentError
        @error = "Invalid start time format"
        @practice.title = params[:title] if params[:title]
        @practice.description = params[:description] if params[:description]
        return erb :edit_practice
      end
    end

    # Parse duration if provided
    duration = nil
    if params[:duration] && !params[:duration].empty?
      duration = params[:duration].to_i
      if duration <= 0
        @error = "Duration must be a positive number"
        @practice.title = params[:title] if params[:title]
        @practice.description = params[:description] if params[:description]
        return erb :edit_practice
      end
    end

    # Check if dates have changed - if so, we need to clear availability responses
    dates_changed = (@practice.start_date != start_date) || (@practice.end_date != end_date)

    # Update the practice
    @practice.assign_attributes(
      start_date: start_date,
      end_date: end_date,
      title: params[:title],
      description: params[:description],
      start_time: start_time,
      duration: duration
    )

    if @practice.save
      # If dates changed, clear all availability responses
      if dates_changed
        @practice.practice_availabilities.destroy_all
      end

      redirect "/practices/#{@practice.id}"
    else
      @error = @practice.errors.full_messages.join(', ')
      erb :edit_practice
    end
  end

  delete '/practices/:id' do
    require_login
    return redirect '/practices' unless current_band

    @practice = current_band.practices.find_by(id: params[:id])
    return redirect '/practices' unless @practice

    # Only the creator or band owner can delete
    unless @practice.created_by_user == current_user || current_band.owned_by?(current_user)
      redirect "/practices/#{@practice.id}"
      return
    end

    @practice.destroy
    redirect '/practices'
  end
end