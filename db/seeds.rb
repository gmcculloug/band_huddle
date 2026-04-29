require_relative 'song_data'

puts "Seeding database with sample data..."

# Create users with password "test123"
users_data = [
  { username: "greg", email: "greg@bandhuddle.com" },
  { username: "vik", email: "vik@bandhuddle.com" },
  { username: "gershom", email: "gershom@bandhuddle.com" },
  { username: "ingrid", email: "ingrid@bandhuddle.com" },
  { username: "dave", email: "dave@bandhuddle.com" },
  { username: "armaan", email: "armaan@bandhuddle.com" },
  { username: "jim", email: "jim@bandhuddle.com" },
  { username: "bill", email: "bill@bandhuddle.com" },
  { username: "davep", email: "davep@bandhuddle.com" },
  { username: "deb", email: "deb@bandhuddle.com" },
  { username: "courtney", email: "courtney@bandhuddle.com" },
  { username: "steve", email: "steve@bandhuddle.com" },
  { username: "faith", email: "faith@bandhuddle.com" },
  { username: "gregb", email: "gregb@bandhuddle.com" },
  { username: "jen", email: "jen@bandhuddle.com" }
]

users = []
users_data.each do |user_data|
  user = User.find_or_create_by(username: user_data[:username]) do |u|
    u.email = user_data[:email]
    u.password = "test123"
    u.password_confirmation = "test123"
  end
  users << user
  puts "Created/found user: #{user.username}"
end

# Create the three specific bands
bands = []

# Get users for easy reference
greg = users.find { |u| u.username == "greg" }
steve = users.find { |u| u.username == "steve" }

# Create Sidepiece band with Greg as owner
side_piece_band = Band.find_or_create_by(name: "Sidepiece") do |b|
  b.owner = greg
  b.notes = "Sidepiece band"
  b.public_schedule_enabled = true
end
bands << side_piece_band

# Create Sound Bite band with Greg as owner
sound_bite_band = Band.find_or_create_by(name: "Sound Bite") do |b|
  b.owner = greg
  b.notes = "Sound Bite band with extensive song list"
  b.public_schedule_enabled = true
end
bands << sound_bite_band

# Create On Tap band with Steve as owner
on_tap_band = Band.find_or_create_by(name: "On Tap") do |b|
  b.owner = steve
  b.notes = "On Tap band"
  b.public_schedule_enabled = true
end
bands << on_tap_band

puts "Created/found band: #{side_piece_band.name} (owner: #{greg.username})"
puts "Created/found band: #{sound_bite_band.name} (owner: #{greg.username})"
puts "Created/found band: #{on_tap_band.name} (owner: #{steve.username})"

# Assign users to Sidepiece band (Greg, Vik, Gershom, Ingrid, Dave, Armaan)
side_piece_users = ["greg", "vik", "gershom", "ingrid", "dave", "armaan"]
side_piece_users.each do |username|
  user = users.find { |u| u.username == username }
  next unless user

  # Find or create UserBand entry with appropriate role
  user_band = UserBand.find_or_initialize_by(user: user, band: side_piece_band)
  role = username == "greg" ? "owner" : "member"
  user_band.role = role
  user_band.save!

  # Set as user's last selected band
  user.update(last_selected_band: side_piece_band)
end
puts "Added members to Sidepiece: #{side_piece_users.join(', ')} (Greg as owner)"

# Assign users to Sound Bite band (Greg, Jim, Bill, DaveP, Deb, Courtney)
sound_bite_users = ["greg", "jim", "bill", "davep", "deb", "courtney"]
sound_bite_users.each do |username|
  user = users.find { |u| u.username == username }
  next unless user

  # Find or create UserBand entry with appropriate role
  user_band = UserBand.find_or_initialize_by(user: user, band: sound_bite_band)
  role = username == "greg" ? "owner" : "member"
  user_band.role = role
  user_band.save!

  # Set as user's last selected band if they're not already in Sidepiece
  unless side_piece_users.include?(username)
    user.update(last_selected_band: sound_bite_band)
  end
end
puts "Added members to Sound Bite: #{sound_bite_users.join(', ')} (Greg as owner)"

# Assign users to On Tap band (Steve, Faith, Greg, GregB, Vik, Jen)
on_tap_users = ["steve", "faith", "greg", "gregb", "vik", "jen"]
on_tap_users.each do |username|
  user = users.find { |u| u.username == username }
  next unless user

  # Find or create UserBand entry with appropriate role
  user_band = UserBand.find_or_initialize_by(user: user, band: on_tap_band)
  # Assign appropriate role: Steve gets owner (primary owner), Greg gets owner (he's in multiple bands as owner)
  role = (username == "steve" || username == "greg") ? "owner" : "member"
  user_band.role = role
  user_band.save!

  # Set as user's last selected band if they're not already in other bands
  unless side_piece_users.include?(username) || sound_bite_users.include?(username)
    user.update(last_selected_band: on_tap_band)
  end
end
puts "Added members to On Tap: #{on_tap_users.join(', ')} (Steve and Greg as owners)"

# Use shared song data
song_catalogs = []
SongData::GLOBAL_SONGS.each do |song_data|
  song_catalog = SongCatalog.find_or_create_by(
    title: song_data[:title], 
    artist: song_data[:artist]
  ) do |gs|
    gs.key = song_data[:key]
    gs.original_key = song_data[:original_key]
    gs.tempo = song_data[:tempo]
    gs.genre = song_data[:genre]
    gs.year = song_data[:year]
    gs.album = song_data[:album]
    gs.duration = song_data[:duration]
  end
  song_catalogs << song_catalog
  puts "Created/found song catalog entry: #{song_catalog.title} by #{song_catalog.artist}"
end

# Create venues for each band
venue_types = [
  { name: "The Blue Note", location: "123 Main St, Downtown", contact_name: "Mike Johnson", phone_number: "(555) 123-4567", website: "http://bluenote.com" },
  { name: "Riverside Amphitheater", location: "456 River Rd, Westside", contact_name: "Sarah Williams", phone_number: "(555) 234-5678", website: "http://riverside-amp.com" },
  { name: "The Underground", location: "789 Basement Ave, Arts District", contact_name: "Tony Martinez", phone_number: "(555) 345-6789", website: "http://underground-venue.com" },
  { name: "Sunset Rooftop", location: "321 High St, Uptown", contact_name: "Lisa Chen", phone_number: "(555) 456-7890", website: "http://sunset-rooftop.com" },
  { name: "The Garden Stage", location: "654 Park Blvd, Midtown", contact_name: "David Brown", phone_number: "(555) 567-8901", website: "http://garden-stage.com" },
  { name: "Electric Lounge", location: "987 Neon Ave, Entertainment District", contact_name: "Jennifer Davis", phone_number: "(555) 678-9012", website: "http://electric-lounge.com" },
  { name: "Jazz Corner", location: "111 Melody Lane, Cultural District", contact_name: "Frank Miller", phone_number: "(555) 789-0123", website: "http://jazz-corner.com" },
  { name: "Rock & Roll Hall", location: "222 Rock Ave, Music Row", contact_name: "Joan Wilson", phone_number: "(555) 890-1234", website: "http://rockrollhall.com" },
  { name: "Acoustic Cafe", location: "333 Coffee St, Bohemian Quarter", contact_name: "Paul Garcia", phone_number: "(555) 901-2345", website: "http://acoustic-cafe.com" },
  { name: "Stadium Arena", location: "444 Sports Blvd, Arena District", contact_name: "Maria Rodriguez", phone_number: "(555) 012-3456", website: "http://stadium-arena.com" }
]

venues = []
bands.each do |band|
  # Each band gets 2-3 venues
  num_venues = rand(2..3)
  band_venue_types = venue_types.shuffle.first(num_venues)
  
  band_venue_types.each_with_index do |venue_data, index|
    # Make venue name unique per band
    venue_name = venue_data[:name]
    
    venue = Venue.find_or_create_by(
      name: venue_name,
      band: band
    ) do |v|
      v.location = venue_data[:location]
      v.contact_name = venue_data[:contact_name]
      v.phone_number = venue_data[:phone_number]
      v.website = venue_data[:website]
      v.notes = "Venue for #{band.name}"
    end
    venues << venue
    puts "Created/found venue: #{venue.name} for band #{band.name}"
  end
end

# Create songs for bands from global songs
bands.each do |band|
  if band.name == "Sidepiece"
    # Sidepiece gets specific songs
    side_piece_songs = SongData.side_piece_songs
    selected_song_catalogs = song_catalogs.select { |sc| side_piece_songs.any? { |song| song[:title] == sc.title && song[:artist] == sc.artist } }
  elsif band.name == "Sound Bite"
    # Sound Bite gets specific songs
    sound_bite_songs = SongData.sound_bite_songs
    selected_song_catalogs = song_catalogs.select { |sc| sound_bite_songs.any? { |song| song[:title] == sc.title && song[:artist] == sc.artist } }
  elsif band.name == "On Tap"
    # On Tap gets a mix of popular songs
    on_tap_songs = SongData.on_tap_songs
    selected_song_catalogs = song_catalogs.select { |sc| on_tap_songs.any? { |song| song[:title] == sc.title && song[:artist] == sc.artist } }
  else
    # Other bands get 30-50 random global songs
    selected_song_catalogs = song_catalogs.sample(rand(30..50))
  end
  
  selected_song_catalogs.each do |song_catalog|
    song = Song.find_or_create_by(
      title: song_catalog.title,
      artist: song_catalog.artist,
      song_catalog: song_catalog
    ) do |s|
      s.key = song_catalog.key
      s.original_key = song_catalog.original_key
      s.tempo = song_catalog.tempo
      s.genre = song_catalog.genre
      s.url = song_catalog.url
      s.notes = song_catalog.notes
      s.duration = song_catalog.duration
      s.year = song_catalog.year
      s.album = song_catalog.album
      s.lyrics = song_catalog.lyrics
    end
    
    # Add song to band if not already added
    unless band.songs.include?(song)
      band.songs << song
    end
  end
  puts "Added #{band.songs.count} songs to band #{band.name}"
end

# Create gigs for each band
bands.each do |band|
  band_venues = venues.select { |v| v.band == band }

  # Check if this band already has gigs - if so, skip gig creation
  if band.gigs.any?
    puts "Band #{band.name} already has #{band.gigs.count} gigs, skipping gig creation"
    next
  end

  # Create 3-4 past gigs
  rand(3..4).times do |i|
    past_date = Date.current - rand(30..365).days
    venue = band_venues.sample
    
    gig = Gig.find_or_create_by(
      name: "#{venue.name}",
      band: band,
      performance_date: past_date
    ) do |g|
      g.venue = venue
      g.start_time = Time.parse("#{rand(19..21)}:#{['00', '30'].sample}")
      g.end_time = g.start_time + rand(2..4).hours
      g.notes = "Past performance - great crowd!"
    end
    
    # Add 3-6 songs to each past gig (all in set 1)
    gig_songs = band.songs.sample(rand(3..6))
    gig_songs.each_with_index do |song, position|
      GigSong.find_or_create_by(
        gig: gig,
        song: song,
        position: position + 1,
        set_number: 1
      )
    end
    puts "Created past gig: #{gig.name} on #{gig.performance_date}"
  end
  
  # Create 6-8 future gigs  
  rand(6..8).times do |i|
    future_date = Date.current + rand(7..365).days
    venue = band_venues.sample
    
    gig = Gig.find_or_create_by(
      name: "#{venue.name}",
      band: band,
      performance_date: future_date
    ) do |g|
      g.venue = venue
      g.start_time = Time.parse("#{rand(19..22)}:#{['00', '30'].sample}")
      g.end_time = g.start_time + rand(2..4).hours
    end
    
    # Add songs to future gigs with multiple sets
    total_songs = rand(6..12)
    available_songs = band.songs.to_a.shuffle
    
    # Determine number of sets (70% chance of 2 sets, 20% chance of 1 set, 10% chance of 3 sets)
    rand_num = rand(100)
    num_sets = if rand_num < 20
                 1
               elsif rand_num < 90
                 2
               else
                 3
               end
    
    # Distribute songs across sets
    songs_per_set = (total_songs / num_sets.to_f).ceil
    current_song_index = 0
    
    (1..num_sets).each do |set_number|
      # Determine songs for this set (slightly random distribution)
      songs_in_set = if set_number == num_sets
                       # Last set gets remaining songs
                       total_songs - current_song_index
                     else
                       # Other sets get 3-6 songs
                       [rand(3..6), total_songs - current_song_index].min
                     end
      
      next if songs_in_set <= 0 || current_song_index >= available_songs.length
      
      set_songs = available_songs[current_song_index, songs_in_set] || []
      set_songs.each_with_index do |song, position|
        GigSong.find_or_create_by(
          gig: gig,
          song: song,
          position: position + 1,
          set_number: set_number
        )
      end
      
      current_song_index += songs_in_set
    end
    puts "Created future gig: #{gig.name} on #{gig.performance_date} (#{num_sets} sets, #{total_songs} total songs)"
  end
end

puts "\nSeeding completed successfully!"
puts "Created:"
puts "- #{User.count} users (all with password 'test123')"
puts "- #{Band.count} bands"
puts "- #{SongCatalog.count} song catalog entries"
puts "- #{Song.count} band-specific songs"
puts "- #{Venue.count} venues"
puts "- #{Gig.count} gigs (past and future)"
puts "- #{GigSong.count} gig songs"

puts "\nBand ownership structure:"
Band.all.each do |band|
  owners = UserBand.where(band: band, role: 'owner').includes(:user).map { |ub| ub.user.username }
  members = UserBand.where(band: band, role: 'member').includes(:user).map { |ub| ub.user.username }
  puts "- #{band.name}:"
  puts "  Owners: #{owners.any? ? owners.join(', ') : 'None'}"
  puts "  Members: #{members.any? ? members.join(', ') : 'None'}"
end