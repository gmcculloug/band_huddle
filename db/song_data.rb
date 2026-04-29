# Shared song data for seeding tasks
module SongData
  GLOBAL_SONGS = [
    # Classic Rock
    { title: "Sweet Home Alabama", artist: "Lynyrd Skynyrd", key: "G", original_key: "G", tempo: 100, genre: "Rock", year: 1974, album: "Second Helping", duration: "4:43" },
    { title: "Hotel California", artist: "Eagles", key: "Bm", original_key: "Bm", tempo: 75, genre: "Rock", year: 1976, album: "Hotel California", duration: "6:30" },
    { title: "Stairway to Heaven", artist: "Led Zeppelin", key: "Am", original_key: "Am", tempo: 82, genre: "Rock", year: 1971, album: "Led Zeppelin IV", duration: "8:02" },
    { title: "Free Bird", artist: "Lynyrd Skynyrd", key: "G", original_key: "G", tempo: 65, genre: "Southern Rock", year: 1973, album: "Pronounced Leh-nerd Skin-nerd", duration: "9:07" },
    { title: "Bohemian Rhapsody", artist: "Queen", key: "Bb", original_key: "Bb", tempo: 72, genre: "Progressive Rock", year: 1975, album: "A Night at the Opera", duration: "5:55" },
    { title: "Don't Stop Believin'", artist: "Journey", key: "E", original_key: "E", tempo: 119, genre: "Rock", year: 1981, album: "Escape", duration: "4:09" },
    { title: "Livin' on a Prayer", artist: "Bon Jovi", key: "Em", original_key: "Em", tempo: 123, genre: "Rock", year: 1986, album: "Slippery When Wet", duration: "4:09" },
    { title: "We Will Rock You", artist: "Queen", key: "C", original_key: "C", tempo: 114, genre: "Rock", year: 1977, album: "News of the World", duration: "2:02" },
    { title: "Another Brick in the Wall", artist: "Pink Floyd", key: "Dm", original_key: "Dm", tempo: 104, genre: "Progressive Rock", year: 1979, album: "The Wall", duration: "3:59" },
    { title: "Born to Run", artist: "Bruce Springsteen", key: "E", original_key: "E", tempo: 147, genre: "Rock", year: 1975, album: "Born to Run", duration: "4:30" },
    { title: "Smoke on the Water", artist: "Deep Purple", key: "G", original_key: "G", tempo: 112, genre: "Hard Rock", year: 1972, album: "Machine Head", duration: "5:40" },
    { title: "More Than a Feeling", artist: "Boston", key: "G", original_key: "G", tempo: 115, genre: "Rock", year: 1976, album: "Boston", duration: "4:45" },
    { title: "Tom Sawyer", artist: "Rush", key: "E", original_key: "E", tempo: 88, genre: "Progressive Rock", year: 1981, album: "Moving Pictures", duration: "4:33" },
    { title: "Back in Black", artist: "AC/DC", key: "E", original_key: "E", tempo: 94, genre: "Hard Rock", year: 1980, album: "Back in Black", duration: "4:15" },
    { title: "Highway to Hell", artist: "AC/DC", key: "A", original_key: "A", tempo: 115, genre: "Hard Rock", year: 1979, album: "Highway to Hell", duration: "3:28" },

    # Folk Rock & Singer-Songwriter
    { title: "Brown Eyed Girl", artist: "Van Morrison", key: "G", original_key: "G", tempo: 150, genre: "Folk Rock", year: 1967, album: "Blowin' Your Mind!", duration: "3:05" },
    { title: "Sweet Caroline", artist: "Neil Diamond", key: "C", original_key: "C", tempo: 125, genre: "Pop", year: 1969, album: "Brother Love's Travelling Salvation Show", duration: "3:21" },
    { title: "Fire and Rain", artist: "James Taylor", key: "A", original_key: "A", tempo: 76, genre: "Folk Rock", year: 1970, album: "Sweet Baby James", duration: "3:20" },
    { title: "American Pie", artist: "Don McLean", key: "G", original_key: "G", tempo: 76, genre: "Folk Rock", year: 1971, album: "American Pie", duration: "8:36" },
    { title: "The Sound of Silence", artist: "Simon & Garfunkel", key: "Am", original_key: "Am", tempo: 90, genre: "Folk Rock", year: 1964, album: "Wednesday Morning, 3 A.M.", duration: "3:05" },
    { title: "Mrs. Robinson", artist: "Simon & Garfunkel", key: "E", original_key: "E", tempo: 120, genre: "Folk Rock", year: 1968, album: "Bookends", duration: "4:04" },
    { title: "Blackbird", artist: "The Beatles", key: "G", original_key: "G", tempo: 96, genre: "Folk Rock", year: 1968, album: "The Beatles (White Album)", duration: "2:18" },
    { title: "Here Comes the Sun", artist: "The Beatles", key: "A", original_key: "A", tempo: 129, genre: "Folk Rock", year: 1969, album: "Abbey Road", duration: "3:05" },

    # 80s Rock & New Wave
    { title: "Eye of the Tiger", artist: "Survivor", key: "Cm", original_key: "Cm", tempo: 109, genre: "Rock", year: 1982, album: "Eye of the Tiger", duration: "4:04" },
    { title: "Don't Stop Me Now", artist: "Queen", key: "F", original_key: "F", tempo: 156, genre: "Rock", year: 1978, album: "Jazz", duration: "3:29" },
    { title: "Billie Jean", artist: "Michael Jackson", key: "F#m", original_key: "F#m", tempo: 117, genre: "Pop", year: 1982, album: "Thriller", duration: "4:54" },
    { title: "Beat It", artist: "Michael Jackson", key: "Em", original_key: "Em", tempo: 139, genre: "Pop Rock", year: 1982, album: "Thriller", duration: "4:18" },
    { title: "Sweet Child O' Mine", artist: "Guns N' Roses", key: "D", original_key: "D", tempo: 125, genre: "Hard Rock", year: 1987, album: "Appetite for Destruction", duration: "5:03" },
    { title: "Pour Some Sugar on Me", artist: "Def Leppard", key: "E", original_key: "E", tempo: 96, genre: "Hard Rock", year: 1987, album: "Hysteria", duration: "4:25" },
    { title: "Jump", artist: "Van Halen", key: "C", original_key: "C", tempo: 131, genre: "Hard Rock", year: 1983, album: "1984", duration: "4:04" },
    { title: "Runnin' with the Devil", artist: "Van Halen", key: "E", original_key: "E", tempo: 100, genre: "Hard Rock", year: 1978, album: "Van Halen", duration: "3:35" },
    { title: "Walk This Way", artist: "Aerosmith", key: "C", original_key: "C", tempo: 120, genre: "Hard Rock", year: 1975, album: "Toys in the Attic", duration: "3:40" },

    # Alternative & Grunge
    { title: "Wonderwall", artist: "Oasis", key: "Em", original_key: "Em", tempo: 87, genre: "Alternative Rock", year: 1995, album: "What's the Story Morning Glory?", duration: "4:18" },
    { title: "Smells Like Teen Spirit", artist: "Nirvana", key: "F", original_key: "F", tempo: 117, genre: "Grunge", year: 1991, album: "Nevermind", duration: "5:01" },
    { title: "Black", artist: "Pearl Jam", key: "E", original_key: "E", tempo: 69, genre: "Grunge", year: 1991, album: "Ten", duration: "5:43" },
    { title: "Alive", artist: "Pearl Jam", key: "A", original_key: "A", tempo: 76, genre: "Grunge", year: 1991, album: "Ten", duration: "5:41" },
    { title: "Come As You Are", artist: "Nirvana", key: "Em", original_key: "Em", tempo: 122, genre: "Grunge", year: 1991, album: "Nevermind", duration: "3:39" },
    { title: "Basket Case", artist: "Green Day", key: "Eb", original_key: "Eb", tempo: 168, genre: "Punk Rock", year: 1994, album: "Dookie", duration: "3:01" },
    { title: "Longview", artist: "Green Day", key: "Eb", original_key: "Eb", tempo: 148, genre: "Punk Rock", year: 1994, album: "Dookie", duration: "3:56" },
    { title: "Mr. Brightside", artist: "The Killers", key: "D", original_key: "D", tempo: 148, genre: "Alternative Rock", year: 2003, album: "Hot Fuss", duration: "3:42" },

    # Country & Folk
    { title: "Friends in Low Places", artist: "Garth Brooks", key: "A", original_key: "A", tempo: 128, genre: "Country", year: 1990, album: "No Fences", duration: "4:28" },
    { title: "Wagon Wheel", artist: "Old Crow Medicine Show", key: "G", original_key: "G", tempo: 150, genre: "Country Folk", year: 2004, album: "Old Crow Medicine Show", duration: "3:12" },
    { title: "Copperhead Road", artist: "Steve Earle", key: "Dm", original_key: "Dm", tempo: 126, genre: "Country Rock", year: 1988, album: "Copperhead Road", duration: "4:29" },
    { title: "Take Me Home, Country Roads", artist: "John Denver", key: "A", original_key: "A", tempo: 80, genre: "Country Folk", year: 1971, album: "Poems, Prayers & Promises", duration: "3:13" },
    { title: "Mammas Don't Let Your Babies Grow Up to Be Cowboys", artist: "Willie Nelson & Waylon Jennings", key: "D", original_key: "D", tempo: 120, genre: "Country", year: 1978, album: "Waylon & Willie", duration: "2:47" },
    { title: "Ring of Fire", artist: "Johnny Cash", key: "G", original_key: "G", tempo: 152, genre: "Country", year: 1963, album: "Ring of Fire: The Best of Johnny Cash", duration: "2:36" },
    { title: "Folsom Prison Blues", artist: "Johnny Cash", key: "E", original_key: "E", tempo: 123, genre: "Country", year: 1955, album: "With His Hot and Blue Guitar", duration: "2:49" },

    # Blues & R&B
    { title: "Pride and Joy", artist: "Stevie Ray Vaughan", key: "E", original_key: "E", tempo: 134, genre: "Blues", year: 1983, album: "Texas Flood", duration: "3:39" },
    { title: "The Thrill Is Gone", artist: "B.B. King", key: "Bm", original_key: "Bm", tempo: 64, genre: "Blues", year: 1969, album: "Completely Well", duration: "5:26" },
    { title: "Cross Road Blues", artist: "Robert Johnson", key: "A", original_key: "A", tempo: 120, genre: "Blues", year: 1936, album: "King of the Delta Blues Singers", duration: "2:41" },
    { title: "Mustang Sally", artist: "Wilson Pickett", key: "C", original_key: "C", tempo: 108, genre: "R&B", year: 1966, album: "The Wicked Pickett", duration: "4:04" },
    { title: "I Feel Good", artist: "James Brown", key: "D", original_key: "D", tempo: 144, genre: "Soul", year: 1965, album: "Papa's Got a Brand New Bag", duration: "2:51" },

    # Reggae & Ska
    { title: "No Woman No Cry", artist: "Bob Marley", key: "C", original_key: "C", tempo: 76, genre: "Reggae", year: 1974, album: "Natty Dread", duration: "7:08" },
    { title: "Three Little Birds", artist: "Bob Marley", key: "A", original_key: "A", tempo: 76, genre: "Reggae", year: 1977, album: "Exodus", duration: "3:00" },
    { title: "Red Red Wine", artist: "UB40", key: "Bb", original_key: "Bb", tempo: 78, genre: "Reggae", year: 1983, album: "Labour of Love", duration: "3:06" },
    { title: "The Impression That I Get", artist: "The Mighty Mighty Bosstones", key: "F", original_key: "F", tempo: 150, genre: "Ska", year: 1997, album: "Let's Face It", duration: "3:13" },

    # Indie & Modern Rock
    { title: "Float On", artist: "Modest Mouse", key: "F", original_key: "F", tempo: 90, genre: "Indie Rock", year: 2004, album: "Good News for People Who Love Bad News", duration: "3:28" },
    { title: "Seven Nation Army", artist: "The White Stripes", key: "Em", original_key: "Em", tempo: 124, genre: "Alternative Rock", year: 2003, album: "Elephant", duration: "3:51" },
    { title: "I Will Follow", artist: "U2", key: "A", original_key: "A", tempo: 150, genre: "Rock", year: 1980, album: "Boy", duration: "3:36" },
    { title: "Where the Streets Have No Name", artist: "U2", key: "D", original_key: "D", tempo: 131, genre: "Rock", year: 1987, album: "The Joshua Tree", duration: "5:36" },
    { title: "Clocks", artist: "Coldplay", key: "Eb", original_key: "Eb", tempo: 131, genre: "Alternative Rock", year: 2002, album: "A Rush of Blood to the Head", duration: "5:07" },
    { title: "Yellow", artist: "Coldplay", key: "B", original_key: "B", tempo: 87, genre: "Alternative Rock", year: 2000, album: "Parachutes", duration: "4:29" },
    { title: "Use Somebody", artist: "Kings of Leon", key: "C", original_key: "C", tempo: 136, genre: "Alternative Rock", year: 2008, album: "Only by the Night", duration: "3:51" },
    { title: "Sex on Fire", artist: "Kings of Leon", key: "E", original_key: "E", tempo: 150, genre: "Alternative Rock", year: 2008, album: "Only by the Night", duration: "3:23" },
    { title: "Somebody Told Me", artist: "The Killers", key: "Bb", original_key: "Bb", tempo: 133, genre: "Alternative Rock", year: 2004, album: "Hot Fuss", duration: "3:17" },

    # Classic Pop & Motown
    { title: "Dancing Queen", artist: "ABBA", key: "A", original_key: "A", tempo: 100, genre: "Pop", year: 1976, album: "Arrival", duration: "3:52" },
    { title: "Mamma Mia", artist: "ABBA", key: "D", original_key: "D", tempo: 138, genre: "Pop", year: 1975, album: "ABBA", duration: "3:32" },
    { title: "My Girl", artist: "The Temptations", key: "C", original_key: "C", tempo: 86, genre: "Motown", year: 1964, album: "The Temptations Sing Smokey", duration: "2:52" },
    { title: "I Heard It Through the Grapevine", artist: "Marvin Gaye", key: "Bb", original_key: "Bb", tempo: 87, genre: "Motown", year: 1968, album: "In the Groove", duration: "3:16" },
    { title: "Superstition", artist: "Stevie Wonder", key: "Eb", original_key: "Eb", tempo: 100, genre: "Funk", year: 1972, album: "Talking Book", duration: "4:26" },
    { title: "I Want You Back", artist: "The Jackson 5", key: "Ab", original_key: "Ab", tempo: 100, genre: "Motown", year: 1969, album: "Diana Ross Presents The Jackson 5", duration: "2:59" },

    # Punk & New Wave
    { title: "Blitzkrieg Bop", artist: "Ramones", key: "A", original_key: "A", tempo: 176, genre: "Punk Rock", year: 1976, album: "Ramones", duration: "2:12" },
    { title: "I Wanna Be Sedated", artist: "Ramones", key: "E", original_key: "E", tempo: 150, genre: "Punk Rock", year: 1978, album: "Road to Ruin", duration: "2:30" },
    { title: "London Calling", artist: "The Clash", key: "Em", original_key: "Em", tempo: 133, genre: "Punk Rock", year: 1979, album: "London Calling", duration: "3:19" },
    { title: "Should I Stay or Should I Go", artist: "The Clash", key: "G", original_key: "G", tempo: 115, genre: "Punk Rock", year: 1982, album: "Combat Rock", duration: "3:06" },
    { title: "Once in a Lifetime", artist: "Talking Heads", key: "C", original_key: "C", tempo: 102, genre: "New Wave", year: 1980, album: "Remain in Light", duration: "4:20" },
    { title: "Burning Down the House", artist: "Talking Heads", key: "Bb", original_key: "Bb", tempo: 126, genre: "New Wave", year: 1983, album: "Speaking in Tongues", duration: "4:00" },

    # Metal & Hard Rock
    { title: "Enter Sandman", artist: "Metallica", key: "Em", original_key: "Em", tempo: 123, genre: "Metal", year: 1991, album: "Metallica (Black Album)", duration: "5:31" },
    { title: "Master of Puppets", artist: "Metallica", key: "Em", original_key: "Em", tempo: 220, genre: "Metal", year: 1986, album: "Master of Puppets", duration: "8:35" },
    { title: "Breaking the Law", artist: "Judas Priest", key: "A", original_key: "A", tempo: 150, genre: "Metal", year: 1980, album: "British Steel", duration: "2:35" },
    { title: "Ace of Spades", artist: "Motörhead", key: "E", original_key: "E", tempo: 134, genre: "Metal", year: 1980, album: "Ace of Spades", duration: "2:49" },
    { title: "Crazy Train", artist: "Ozzy Osbourne", key: "A", original_key: "A", tempo: 138, genre: "Metal", year: 1980, album: "Blizzard of Ozz", duration: "4:53" },
    { title: "Iron Man", artist: "Black Sabbath", key: "B", original_key: "B", tempo: 71, genre: "Metal", year: 1970, album: "Paranoid", duration: "5:56" },
    { title: "Paranoid", artist: "Black Sabbath", key: "E", original_key: "E", tempo: 164, genre: "Metal", year: 1970, album: "Paranoid", duration: "2:48" },

    # 90s Alternative & Pop
    { title: "Torn", artist: "Natalie Imbruglia", key: "F", original_key: "F", tempo: 104, genre: "Alternative Pop", year: 1997, album: "Left of the Middle", duration: "4:04" },
    { title: "Creep", artist: "Radiohead", key: "G", original_key: "G", tempo: 92, genre: "Alternative Rock", year: 1992, album: "Pablo Honey", duration: "3:58" },
    { title: "1979", artist: "The Smashing Pumpkins", key: "Eb", original_key: "Eb", tempo: 120, genre: "Alternative Rock", year: 1995, album: "Mellon Collie and the Infinite Sadness", duration: "4:25" },
    { title: "Today", artist: "The Smashing Pumpkins", key: "Eb", original_key: "Eb", tempo: 132, genre: "Alternative Rock", year: 1993, album: "Siamese Dream", duration: "3:20" },
    { title: "What's Up?", artist: "4 Non Blondes", key: "G", original_key: "G", tempo: 78, genre: "Alternative Rock", year: 1992, album: "Bigger, Better, Faster, More!", duration: "4:55" },
    { title: "Zombie", artist: "The Cranberries", key: "Em", original_key: "Em", tempo: 84, genre: "Alternative Rock", year: 1994, album: "No Need to Argue", duration: "5:06" },
    { title: "I'm Gonna Be (500 Miles)", artist: "The Proclaimers", key: "E", original_key: "E", tempo: 131, genre: "Folk Rock", year: 1988, album: "Sunshine on Leith", duration: "3:36" },

    # Classic Jazz Standards (Easy versions)
    { title: "Fly Me to the Moon", artist: "Frank Sinatra", key: "C", original_key: "C", tempo: 120, genre: "Jazz", year: 1964, album: "It Might as Well Be Swing", duration: "2:29" },
    { title: "Blue Moon", artist: "Various Artists", key: "Bb", original_key: "Bb", tempo: 80, genre: "Jazz Standard", year: 1934, album: "", duration: "3:00" },
    { title: "Autumn Leaves", artist: "Various Artists", key: "Gm", original_key: "Gm", tempo: 120, genre: "Jazz Standard", year: 1945, album: "", duration: "3:30" },

    # Easy Crowd Pleasers
    { title: "Brown Sugar", artist: "The Rolling Stones", key: "C", original_key: "C", tempo: 125, genre: "Rock", year: 1971, album: "Sticky Fingers", duration: "3:49" },
    { title: "Start Me Up", artist: "The Rolling Stones", key: "C", original_key: "C", tempo: 126, genre: "Rock", year: 1981, album: "Tattoo You", duration: "3:33" },
    { title: "Paint It Black", artist: "The Rolling Stones", key: "Em", original_key: "Em", tempo: 126, genre: "Rock", year: 1966, album: "Aftermath", duration: "3:22" },
    { title: "Satisfaction", artist: "The Rolling Stones", key: "E", original_key: "E", tempo: 134, genre: "Rock", year: 1965, album: "Out of Our Heads", duration: "3:43" },
    { title: "Wild Thing", artist: "The Troggs", key: "A", original_key: "A", tempo: 120, genre: "Rock", year: 1966, album: "From Nowhere", duration: "2:35" },
    { title: "La Bamba", artist: "Ritchie Valens", key: "C", original_key: "C", tempo: 144, genre: "Rock & Roll", year: 1958, album: "Ritchie Valens", duration: "2:06" },
    { title: "Twist and Shout", artist: "The Beatles", key: "D", original_key: "D", tempo: 124, genre: "Rock & Roll", year: 1963, album: "Please Please Me", duration: "2:33" },
    { title: "Good Lovin'", artist: "The Young Rascals", key: "A", original_key: "A", tempo: 132, genre: "Rock", year: 1966, album: "The Young Rascals", duration: "2:53" },
    { title: "Hang on Sloopy", artist: "The McCoys", key: "C", original_key: "C", tempo: 150, genre: "Rock", year: 1965, album: "Hang On Sloopy", duration: "3:12" },

    # Sidepiece specific songs
    { title: "My Church", artist: "Maren Morris", key: "E", original_key: "E", tempo: 120, genre: "Country", year: 2016, album: "Hero", duration: "3:30" },
    { title: "Glory Days", artist: "Bruce Springsteen", key: "E", original_key: "E", tempo: 140, genre: "Rock", year: 1984, album: "Born in the U.S.A.", duration: "4:15" },
    { title: "Faith", artist: "George Michael", key: "C", original_key: "C", tempo: 96, genre: "Pop", year: 1987, album: "Faith", duration: "3:16" },
    { title: "Lay Down Sally", artist: "Eric Clapton", key: "A", original_key: "A", tempo: 105, genre: "Rock", year: 1977, album: "Slowhand", duration: "3:54" },
    { title: "Tipsy", artist: "J-Kwon", key: "Bb", original_key: "Bb", tempo: 95, genre: "Hip Hop", year: 2004, album: "Hood Hop", duration: "4:17" },
    { title: "Let Your Love Flow", artist: "Bellamy Brothers", key: "D", original_key: "D", tempo: 120, genre: "Country Rock", year: 1976, album: "Bellamy Brothers", duration: "3:18" },
    { title: "Jolene", artist: "Dolly Parton", key: "Am", original_key: "Am", tempo: 120, genre: "Country", year: 1973, album: "Jolene", duration: "2:42" },
    { title: "Have You Ever Seen the Rain", artist: "Creedence Clearwater Revival", key: "C", original_key: "C", tempo: 117, genre: "Rock", year: 1970, album: "Pendulum", duration: "2:40" },
    { title: "Flowers", artist: "Miley Cyrus", key: "G", original_key: "G", tempo: 95, genre: "Pop", year: 2023, album: "Endless Summer Vacation", duration: "3:20" },
    { title: "Pink Houses", artist: "John Mellencamp", key: "G", original_key: "G", tempo: 122, genre: "Rock", year: 1983, album: "Uh-Huh", duration: "4:44" },
    { title: "Mary Jane's Last Dance", artist: "Tom Petty and the Heartbreakers", key: "Am", original_key: "Am", tempo: 100, genre: "Rock", year: 1993, album: "Greatest Hits", duration: "4:33" },
    { title: "Crazy Little Thing", artist: "Queen", key: "D", original_key: "D", tempo: 156, genre: "Rock", year: 1979, album: "The Game", duration: "2:42" },
    { title: "Don't Start Now", artist: "Dua Lipa", key: "Am", original_key: "Am", tempo: 124, genre: "Pop", year: 2019, album: "Future Nostalgia", duration: "3:03" },
    { title: "Karma Chameleon", artist: "Culture Club", key: "Bb", original_key: "Bb", tempo: 150, genre: "Pop", year: 1983, album: "Colour by Numbers", duration: "4:07" },
    { title: "Santeria", artist: "Sublime", key: "E", original_key: "E", tempo: 80, genre: "Alternative Rock", year: 1996, album: "Sublime", duration: "3:03" },
    { title: "Jenny", artist: "Tommy Tutone", key: "F#m", original_key: "F#m", tempo: 140, genre: "Rock", year: 1981, album: "Tommy Tutone 2", duration: "3:58" },
    { title: "American Girl", artist: "Tom Petty and the Heartbreakers", key: "D", original_key: "D", tempo: 122, genre: "Rock", year: 1976, album: "Tom Petty and the Heartbreakers", duration: "3:31" },
    { title: "Country Roads", artist: "John Denver", key: "A", original_key: "A", tempo: 80, genre: "Country Folk", year: 1971, album: "Poems, Prayers & Promises", duration: "3:13" },
    { title: "When Will I Be Loved", artist: "The Everly Brothers", key: "A", original_key: "A", tempo: 140, genre: "Country Rock", year: 1960, album: "A Date with the Everly Brothers", duration: "2:03" },
    { title: "Your Mama Don't Dance", artist: "Loggins and Messina", key: "E", original_key: "E", tempo: 120, genre: "Rock", year: 1972, album: "Loggins and Messina", duration: "2:56" },
    { title: "Hurts So Good", artist: "John Mellencamp", key: "A", original_key: "A", tempo: 120, genre: "Rock", year: 1982, album: "American Fool", duration: "3:28" },
    { title: "You May Be Right", artist: "Billy Joel", key: "E", original_key: "E", tempo: 150, genre: "Rock", year: 1980, album: "Glass Houses", duration: "4:14" },
    { title: "You Belong With Me", artist: "Taylor Swift", key: "G", original_key: "G", tempo: 130, genre: "Country Pop", year: 2008, album: "Fearless", duration: "3:51" },
    { title: "Tennessee Whiskey", artist: "Chris Stapleton", key: "A", original_key: "A", tempo: 67, genre: "Country", year: 2015, album: "Traveller", duration: "4:53" },
    { title: "Rolling in the Deep", artist: "Adele", key: "Cm", original_key: "Cm", tempo: 105, genre: "Pop", year: 2010, album: "21", duration: "3:48" },
    { title: "Take It On the Run", artist: "REO Speedwagon", key: "D", original_key: "D", tempo: 118, genre: "Rock", year: 1980, album: "Hi Infidelity", duration: "3:59" },
    { title: "The Weight", artist: "The Band", key: "A", original_key: "A", tempo: 90, genre: "Americana", year: 1968, album: "Music from Big Pink", duration: "4:35" },
    { title: "Hard to Handle", artist: "The Black Crowes", key: "A", original_key: "A", tempo: 100, genre: "Rock", year: 1990, album: "Shake Your Money Maker", duration: "3:07" },
    { title: "Go Your Own Way", artist: "Fleetwood Mac", key: "F", original_key: "F", tempo: 130, genre: "Rock", year: 1976, album: "Rumours", duration: "3:38" },
    { title: "Suspicious Minds", artist: "Elvis Presley", key: "G", original_key: "G", tempo: 120, genre: "Rock", year: 1969, album: "From Elvis in Memphis", duration: "4:22" },
    { title: "Who Says You Can't Go Home", artist: "Bon Jovi", key: "D", original_key: "D", tempo: 76, genre: "Country Rock", year: 2005, album: "Have a Nice Day", duration: "4:40" },
    { title: "Every Rose Has Its Thorn", artist: "Poison", key: "G", original_key: "G", tempo: 65, genre: "Rock Ballad", year: 1988, album: "Open Up and Say... Ahh!", duration: "4:20" },
    { title: "Good Riddance", artist: "Green Day", key: "G", original_key: "G", tempo: 94, genre: "Alternative Rock", year: 1997, album: "Nimrod", duration: "2:34" },

    # Sound Bite specific songs
    { title: "Authority Song", artist: "John Mellencamp", key: "E", original_key: "E", tempo: 120, genre: "Rock", year: 1983, album: "Uh-Huh", duration: "3:49" },
    { title: "Back On The Chain Gang", artist: "The Pretenders", key: "A", original_key: "A", tempo: 120, genre: "Rock", year: 1982, album: "Learning to Crawl", duration: "3:49" },
    { title: "Bang a Gong", artist: "T-Rex", key: "E", original_key: "E", tempo: 110, genre: "Glam Rock", year: 1971, album: "Electric Warrior", duration: "4:28" },
    { title: "Because the Night", artist: "Patti Smith", key: "E", original_key: "E", tempo: 120, genre: "Rock", year: 1978, album: "Easter", duration: "3:23" },
    { title: "Black Velvet", artist: "Alannah Myles", key: "Em", original_key: "Em", tempo: 90, genre: "Rock", year: 1989, album: "Alannah Myles", duration: "4:48" },
    { title: "Blood and Roses", artist: "The Smithereens", key: "A", original_key: "A", tempo: 130, genre: "Alternative Rock", year: 1986, album: "Especially for You", duration: "3:58" },
    { title: "Blue On Black", artist: "Kenny Wayne Shepherd", key: "Em", original_key: "Em", tempo: 80, genre: "Blues Rock", year: 1997, album: "Trouble Is...", duration: "4:15" },
    { title: "Comfortably Numb", artist: "Pink Floyd", key: "Bm", original_key: "Bm", tempo: 63, genre: "Progressive Rock", year: 1979, album: "The Wall", duration: "6:23" },
    { title: "Dreams", artist: "Fleetwood Mac", key: "F", original_key: "F", tempo: 120, genre: "Rock", year: 1977, album: "Rumours", duration: "4:14" },
    { title: "Everybody Talks", artist: "Neon Trees", key: "C", original_key: "C", tempo: 120, genre: "Alternative Rock", year: 2011, album: "Picture Show", duration: "2:58" },
    { title: "Ex's & Oh's", artist: "Elle King", key: "G", original_key: "G", tempo: 95, genre: "Alternative Rock", year: 2014, album: "Love Stuff", duration: "2:58" },
    { title: "Gimme Some Lovin", artist: "The Blues Brothers", key: "C", original_key: "C", tempo: 140, genre: "R&B", year: 1980, album: "Briefcase Full of Blues", duration: "3:05" },
    { title: "Girlfriend", artist: "Matthew Sweet", key: "G", original_key: "G", tempo: 120, genre: "Alternative Rock", year: 1991, album: "Girlfriend", duration: "3:19" },
    { title: "Gold On the Ceiling", artist: "The Black Keys", key: "C", original_key: "C", tempo: 120, genre: "Blues Rock", year: 2011, album: "El Camino", duration: "3:39" },
    { title: "Good", artist: "Better than Ezra", key: "G", original_key: "G", tempo: 120, genre: "Alternative Rock", year: 1995, album: "Deluxe", duration: "3:28" },
    { title: "Hold the Line", artist: "Toto", key: "Am", original_key: "Am", tempo: 120, genre: "Rock", year: 1978, album: "Toto", duration: "3:56" },
    { title: "I Feel Fine", artist: "The Beatles", key: "G", original_key: "G", tempo: 125, genre: "Rock", year: 1964, album: "Beatles '65", duration: "2:20" },
    { title: "I Hate Myself for Loving You", artist: "Joan Jett", key: "E", original_key: "E", tempo: 120, genre: "Rock", year: 1988, album: "Up Your Alley", duration: "4:10" },
    { title: "I'm a Believer", artist: "The Monkees", key: "G", original_key: "G", tempo: 140, genre: "Pop Rock", year: 1966, album: "More of the Monkees", duration: "2:47" },
    { title: "Learn To Fly", artist: "Foo Fighters", key: "B", original_key: "B", tempo: 136, genre: "Alternative Rock", year: 1999, album: "There Is Nothing Left to Lose", duration: "3:56" },
    { title: "Lonely is the Night", artist: "Billy Squier", key: "Em", original_key: "Em", tempo: 120, genre: "Rock", year: 1981, album: "Don't Say No", duration: "4:39" },
    { title: "Love Shack", artist: "The B-52's", key: "C", original_key: "C", tempo: 130, genre: "New Wave", year: 1989, album: "Cosmic Thing", duration: "5:20" },
    { title: "Lovin Touchin Squeezin", artist: "Journey", key: "E", original_key: "E", tempo: 120, genre: "Rock", year: 1979, album: "Evolution", duration: "3:55" },
    { title: "My Own Worst Enemy", artist: "Lit", key: "G", original_key: "G", tempo: 160, genre: "Alternative Rock", year: 1999, album: "A Place in the Sun", duration: "2:51" },
    { title: "New Orleans", artist: "Joan Jett", key: "A", original_key: "A", tempo: 120, genre: "Rock", year: 1988, album: "Up Your Alley", duration: "4:18" },
    { title: "No Excuses", artist: "Alice In Chains", key: "G", original_key: "G", tempo: 120, genre: "Grunge", year: 1994, album: "Jar of Flies", duration: "4:15" },
    { title: "No Matter What", artist: "Badfinger", key: "Ab", original_key: "Ab", tempo: 120, genre: "Rock", year: 1970, album: "No Dice", duration: "3:02" },
    { title: "Not Dead Yet", artist: "Lord Huron", key: "Am", original_key: "Am", tempo: 120, genre: "Indie Folk", year: 2015, album: "Strange Trails", duration: "4:06" },
    { title: "Play that Funky Music", artist: "Wild Cherry", key: "E", original_key: "E", tempo: 108, genre: "Funk Rock", year: 1976, album: "Wild Cherry", duration: "5:07" },
    { title: "Promises in the Dark", artist: "Pat Benatar", key: "C", original_key: "C", tempo: 120, genre: "Rock", year: 1981, album: "Precious Time", duration: "4:48" },
    { title: "Proud Mary", artist: "Ike and Tina Turner", key: "D", original_key: "D", tempo: 100, genre: "Rock", year: 1971, album: "Workin' Together", duration: "5:07" },
    { title: "Son of a Preacher Man", artist: "Dusty Springfield", key: "F", original_key: "F", tempo: 100, genre: "Soul", year: 1968, album: "Dusty in Memphis", duration: "2:28" },
    { title: "Stop Draggin' My Heart Around", artist: "Stevie Nicks with Tom Petty", key: "G", original_key: "G", tempo: 120, genre: "Rock", year: 1981, album: "Bella Donna", duration: "4:06" },
    { title: "Stuck in the middle with you", artist: "Stealers Wheel", key: "D", original_key: "D", tempo: 120, genre: "Folk Rock", year: 1972, album: "Stealers Wheel", duration: "3:23" },
    { title: "Stupid Girl", artist: "Garbage", key: "Bb", original_key: "Bb", tempo: 110, genre: "Alternative Rock", year: 1996, album: "Garbage", duration: "4:18" },
    { title: "Summer of 69", artist: "Bryan Adams", key: "D", original_key: "D", tempo: 138, genre: "Rock", year: 1984, album: "Reckless", duration: "3:34" },
    { title: "Sweet Caroline (B) (capo 2)", artist: "Neil Diamond", key: "B", original_key: "C", tempo: 125, genre: "Pop", year: 1969, album: "Brother Love's Travelling Salvation Show", duration: "3:21" },
    { title: "Tainted Love", artist: "Soft Cell", key: "Am", original_key: "Am", tempo: 132, genre: "Synth-pop", year: 1981, album: "Non-Stop Erotic Cabaret", duration: "2:39" },
    { title: "Take It Easy", artist: "Eagles", key: "G", original_key: "G", tempo: 138, genre: "Rock", year: 1972, album: "Eagles", duration: "3:29" },
    { title: "The Letter", artist: "Joe Cocker", key: "Am", original_key: "Am", tempo: 140, genre: "Rock", year: 1970, album: "Mad Dogs & Englishmen", duration: "4:10" },
    { title: "Two Princes", artist: "Spin Doctors", key: "Em", original_key: "Em", tempo: 120, genre: "Alternative Rock", year: 1992, album: "Pocket Full of Kryptonite", duration: "4:17" },
    { title: "We're an American Band", artist: "Grand Funk Railroad", key: "E", original_key: "E", tempo: 120, genre: "Rock", year: 1973, album: "We're an American Band", duration: "3:25" },
    { title: "Wicked Game", artist: "Chris Isaak", key: "Bm", original_key: "Bm", tempo: 110, genre: "Alternative Rock", year: 1989, album: "Heart Shaped World", duration: "4:45" },
    { title: "You Oughta Know", artist: "Alanis Morissette", key: "F#m", original_key: "F#m", tempo: 103, genre: "Alternative Rock", year: 1995, album: "Jagged Little Pill", duration: "4:09" },
    { title: "The Way", artist: "Fastball", key: "G", original_key: "G", tempo: 120, genre: "Alternative Rock", year: 1998, album: "All the Pain Money Can Buy", duration: "4:01" },
    { title: "The Door", artist: "Teddy Swims", key: "C", original_key: "C", tempo: 75, genre: "R&B", year: 2023, album: "I've Tried Everything But Therapy (Part 1)", duration: "3:15" },
    { title: "Margaritaville", artist: "Jimmy Buffett", key: "D", original_key: "D", tempo: 120, genre: "Country Rock", year: 1977, album: "Changes in Latitudes, Changes in Attitudes", duration: "4:06" },

    # Additional Classic Rock Songs
    { title: "Bad Moon Rising", artist: "Creedence Clearwater Revival", key: "D", original_key: "D", tempo: 180, genre: "Rock", year: 1969, album: "Green River", duration: "2:19" },
    { title: "Born To Be Wild", artist: "Steppenwolf", key: "E", original_key: "E", tempo: 148, genre: "Hard Rock", year: 1968, album: "Steppenwolf", duration: "3:30" },
    { title: "Can't You See", artist: "Marshall Tucker Band", key: "D", original_key: "D", tempo: 85, genre: "Southern Rock", year: 1973, album: "The Marshall Tucker Band", duration: "4:58" },
    { title: "Centerfield", artist: "John Fogerty", key: "A", original_key: "A", tempo: 132, genre: "Rock", year: 1985, album: "Centerfield", duration: "3:57" },
    { title: "Cocaine", artist: "Eric Clapton", key: "E", original_key: "E", tempo: 104, genre: "Rock", year: 1977, album: "Slowhand", duration: "3:35" },
    { title: "Come Together", artist: "The Beatles", key: "Dm", original_key: "Dm", tempo: 82, genre: "Rock", year: 1969, album: "Abbey Road", duration: "4:19" },
    { title: "Cuts Like A Knife", artist: "Bryan Adams", key: "E", original_key: "E", tempo: 134, genre: "Rock", year: 1983, album: "Cuts Like a Knife", duration: "5:05" },
    { title: "Dancing With Myself", artist: "Billy Idol", key: "E", original_key: "E", tempo: 140, genre: "New Wave", year: 1981, album: "Don't Stop", duration: "4:50" },
    { title: "Driving My Life Away", artist: "Eddie Rabbitt", key: "G", original_key: "G", tempo: 138, genre: "Country Rock", year: 1980, album: "Horizon", duration: "3:41" },
    { title: "Gimme Three Steps", artist: "Lynyrd Skynyrd", key: "G", original_key: "G", tempo: 118, genre: "Southern Rock", year: 1973, album: "Pronounced Leh-nerd Skin-nerd", duration: "4:30" },
    { title: "Handle With Care", artist: "Traveling Wilburys", key: "C", original_key: "C", tempo: 120, genre: "Rock", year: 1988, album: "Traveling Wilburys Vol. 1", duration: "3:18" },
    { title: "Heart of Gold", artist: "Neil Young", key: "Em", original_key: "Em", tempo: 102, genre: "Folk Rock", year: 1972, album: "Harvest", duration: "3:07" },
    { title: "Honky Tonk Woman", artist: "The Rolling Stones", key: "G", original_key: "G", tempo: 132, genre: "Rock", year: 1969, album: "Through the Past, Darkly", duration: "3:01" },
    { title: "I Melt With You", artist: "Modern English", key: "A", original_key: "A", tempo: 125, genre: "New Wave", year: 1982, album: "After the Snow", duration: "3:54" },
    { title: "I Saw Her Standing There", artist: "The Beatles", key: "E", original_key: "E", tempo: 156, genre: "Rock & Roll", year: 1963, album: "Please Please Me", duration: "2:55" },
    { title: "Jumping Jack Flash", artist: "The Rolling Stones", key: "Bb", original_key: "Bb", tempo: 126, genre: "Rock", year: 1968, album: "Through the Past, Darkly", duration: "3:42" },
    { title: "Keep on Rockin In The Free World", artist: "Neil Young", key: "Em", original_key: "Em", tempo: 108, genre: "Rock", year: 1989, album: "Freedom", duration: "4:41" },
    { title: "Keep Your Hands To Yourself", artist: "Georgia Satellites", key: "E", original_key: "E", tempo: 158, genre: "Rock", year: 1986, album: "Georgia Satellites", duration: "3:28" },
    { title: "Last Train To Clarksville", artist: "The Monkees", key: "G", original_key: "G", tempo: 132, genre: "Pop Rock", year: 1966, album: "The Monkees", duration: "2:47" },
    { title: "Long Cool Woman", artist: "The Hollies", key: "Em", original_key: "Em", tempo: 138, genre: "Rock", year: 1972, album: "Distant Light", duration: "3:17" },
    { title: "Lyin' Eyes", artist: "Eagles", key: "G", original_key: "G", tempo: 140, genre: "Country Rock", year: 1975, album: "One of These Nights", duration: "6:21" },
    { title: "Mony Mony", artist: "Tommy James & The Shondells", key: "G", original_key: "G", tempo: 138, genre: "Pop Rock", year: 1968, album: "Mony Mony", duration: "2:45" },
    { title: "Pretty Woman", artist: "Roy Orbison", key: "A", original_key: "A", tempo: 126, genre: "Rock & Roll", year: 1964, album: "Oh, Pretty Woman", duration: "2:58" },
    { title: "Rock Around The Clock", artist: "Bill Haley & His Comets", key: "A", original_key: "A", tempo: 180, genre: "Rock & Roll", year: 1954, album: "Rock Around the Clock", duration: "2:10" },
    { title: "Rock This Town", artist: "Stray Cats", key: "Bb", original_key: "Bb", tempo: 180, genre: "Rockabilly", year: 1981, album: "Stray Cats", duration: "3:18" },
    { title: "Secret Agent Man", artist: "Johnny Rivers", key: "Em", original_key: "Em", tempo: 126, genre: "Rock", year: 1966, album: "...And I Know You Wanna Dance", duration: "2:35" },
    { title: "Sexy and 17", artist: "Stray Cats", key: "A", original_key: "A", tempo: 150, genre: "Rockabilly", year: 1983, album: "Rant N' Rave with the Stray Cats", duration: "3:51" },
    { title: "Sharp Dressed Man", artist: "ZZ Top", key: "C", original_key: "C", tempo: 124, genre: "Rock", year: 1983, album: "Eliminator", duration: "4:13" },
    { title: "Sister Golden Hair", artist: "America", key: "E", original_key: "E", tempo: 118, genre: "Folk Rock", year: 1975, album: "Hearts", duration: "3:20" },
    { title: "Stray Cat Strut", artist: "Stray Cats", key: "Bbm", original_key: "Bbm", tempo: 132, genre: "Rockabilly", year: 1981, album: "Stray Cats", duration: "3:17" },
    { title: "Sugar Pie Honey Bunch", artist: "Kid Rock", key: "F", original_key: "F", tempo: 140, genre: "Rock", year: 1998, album: "Devil Without a Cause", duration: "4:10" },
    { title: "Twilight Zone", artist: "Golden Earring", key: "Am", original_key: "Am", tempo: 132, genre: "Rock", year: 1982, album: "Cut", duration: "7:10" },
    { title: "What I Like About You", artist: "The Romantics", key: "E", original_key: "E", tempo: 158, genre: "Rock", year: 1980, album: "The Romantics", duration: "3:57" },
    { title: "Wrap It Up", artist: "Fabulous Thunderbirds", key: "A", original_key: "A", tempo: 126, genre: "Blues Rock", year: 1986, album: "Tuff Enuff", duration: "3:58" },
    { title: "You Wreck Me", artist: "Tom Petty", key: "E", original_key: "E", tempo: 108, genre: "Rock", year: 1994, album: "Wildflowers", duration: "3:34" }
  ].freeze

  # Band-specific song title constants
  SIDE_PIECE_TITLES = [
    "My Church", "Glory Days", "Faith", "Lay Down Sally", "Tipsy", "Let Your Love Flow",
    "Jolene", "Have You Ever Seen the Rain", "Flowers", "Wagon Wheel", "Pink Houses",
    "Mary Jane's Last Dance", "Crazy Little Thing", "Don't Start Now", "Karma Chameleon",
    "Santeria", "Jenny", "American Girl", "Country Roads", "When Will I Be Loved",
    "Your Mama Don't Dance", "Hurts So Good", "You May Be Right", "You Belong With Me",
    "Tennessee Whiskey", "Rolling in the Deep", "Take It On the Run", "The Weight",
    "Hotel California", "Hard to Handle", "Go Your Own Way", "Suspicious Minds",
    "Friends in Low Places", "Sweet Caroline", "Who Says You Can't Go Home",
    "Every Rose Has Its Thorn", "Good Riddance"
  ].freeze

  SOUND_BITE_TITLES = [
    "American Girl", "Authority Song", "Back On The Chain Gang", "Bang a Gong",
    "Because the Night", "Black Velvet", "Blood and Roses", "Blue On Black",
    "Comfortably Numb", "Creep", "Dreams", "Everybody Talks", "Ex's & Oh's",
    "Friends in Low Places", "Gimme Some Lovin", "Girlfriend", "Gold On the Ceiling",
    "Good", "Hold the Line", "Hurts So Good", "I Feel Fine", "I Hate Myself for Loving You",
    "I'm a Believer", "Lay Down Sally", "Learn To Fly", "Lonely is the Night",
    "Love Shack", "Lovin Touchin Squeezin", "Mary Jane's Last Dance", "My Own Worst Enemy",
    "New Orleans", "No Excuses", "No Matter What", "Not Dead Yet", "Play that Funky Music",
    "Promises in the Dark", "Proud Mary", "Son of a Preacher Man", "Stop Draggin' My Heart Around",
    "Stuck in the middle with you", "Stupid Girl", "Summer of 69", "Sweet Caroline (B) (capo 2)",
    "Tainted Love", "Take It Easy", "The Letter", "Two Princes", "We're an American Band",
    "Who Says You Can't Go Home", "Wicked Game", "You Oughta Know"
  ].freeze

  ON_TAP_TITLES = [
    "Sweet Home Alabama", "Hotel California", "Don't Stop Believin'", "Livin' on a Prayer",
    "Brown Eyed Girl", "Sweet Caroline", "Fire and Rain", "Eye of the Tiger", "Don't Stop Me Now",
    "Jump", "Walk This Way", "Wonderwall", "Smells Like Teen Spirit", "Black", "Mr. Brightside",
    "Friends in Low Places", "Wagon Wheel", "Take Me Home, Country Roads", "Pride and Joy",
    "Mustang Sally", "No Woman No Cry", "Three Little Birds", "Float On", "Seven Nation Army",
    "Dancing Queen", "My Girl", "Superstition", "Blitzkrieg Bop", "London Calling", "Enter Sandman",
    "Torn", "1979", "Zombie", "Fly Me to the Moon", "Brown Sugar", "Start Me Up", "Wild Thing"
  ].freeze

  # Helper methods for band-specific song lists
  def self.side_piece_songs
    GLOBAL_SONGS.select { |song| SIDE_PIECE_TITLES.include?(song[:title]) }
  end

  def self.sound_bite_songs
    GLOBAL_SONGS.select { |song| SOUND_BITE_TITLES.include?(song[:title]) }
  end

  def self.on_tap_songs
    GLOBAL_SONGS.select { |song| ON_TAP_TITLES.include?(song[:title]) }
  end
end