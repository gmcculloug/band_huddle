FactoryBot.define do
  factory :user do
    sequence(:username) { |n| "user#{n}" }
    password { "password123" }
    email { Faker::Internet.email }
  end

  factory :user_band do
    association :user
    association :band
    role { 'member' }
    
    trait :owner do
      role { 'owner' }
    end
    
    trait :member do
      role { 'member' }
    end
  end

  factory :band do
    sequence(:name) { |n| "Band #{n}" }
    notes { Faker::Lorem.paragraph }
    association :owner, factory: :user
    
    after(:create) do |band|
      # Ensure owner is added as a user_band with owner role
      unless band.users.include?(band.owner)
        UserBand.create!(band: band, user: band.owner, role: 'owner')
      else
        # Update existing user_band to owner role
        user_band = band.user_bands.find_by(user: band.owner)
        user_band&.update!(role: 'owner')
      end
    end
  end

  factory :song_catalog do
    sequence(:title) { |n| "Song Catalog #{n}" }
    artist { Faker::Music.band }
    key { ['C', 'G', 'D', 'A', 'E', 'B', 'F#', 'C#', 'F', 'Bb', 'Eb', 'Ab'].sample }
    tempo { rand(60..180) }
    duration { "#{rand(2..5)}:#{rand(10..59)}" }
    genre { ['Rock', 'Pop', 'Jazz', 'Blues', 'Country'].sample }
    notes { Faker::Lorem.paragraph }
  end

  factory :song do
    sequence(:title) { |n| "Song #{n}" }
    artist { Faker::Music.band }
    key { ['C', 'G', 'D', 'A', 'E', 'B', 'F#', 'C#', 'F', 'Bb', 'Eb', 'Ab'].sample }
    tempo { rand(60..180) }
    duration { "#{rand(2..5)}:#{rand(10..59)}" }
    notes { Faker::Lorem.paragraph }
  end

  factory :venue do
    sequence(:name) { |n| "Venue #{n}" }
    location { Faker::Address.full_address }
    contact_name { Faker::Name.name }
    phone_number { Faker::PhoneNumber.phone_number }
    website { Faker::Internet.url }
    
    association :band
  end

  factory :gig do
    sequence(:name) { |n| "Gig #{n}" }
    performance_date { Date.current + rand(1..30).days }
    start_time { "20:00" }
    end_time { "22:00" }
    notes { Faker::Lorem.paragraph }
    
    association :band
    association :venue
  end

  factory :gig_song do
    association :gig
    association :song
    sequence(:position) { |n| n }
  end

  factory :blackout_date do
    association :user
    blackout_date { Date.current + rand(0..30).days }
    reason { ['Vacation', 'Personal', 'Work', nil].sample }
  end

  factory :google_calendar_event do
    sequence(:google_event_id) { |n| "google_event_#{n}" }
    last_synced_at { Time.current }

    association :band
    association :gig
  end

  factory :practice do
    association :band
    association :created_by_user, factory: :user
    start_date { Date.current }
    end_date { Date.current + 6.days }
    title { "Weekly Practice" }
    description { "Let's practice our upcoming setlist" }
    status { "active" }
  end

  factory :practice_availability do
    association :practice
    association :user
    specific_date { Date.current }
    availability { 'available' }
    notes { "Available in the evening" }
  end
end 