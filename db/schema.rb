# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_04_26_165312) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "bands", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "google_calendar_enabled", default: false
    t.string "google_calendar_id"
    t.string "google_calendar_sync_token"
    t.string "name", null: false
    t.text "notes"
    t.bigint "owner_id"
    t.boolean "public_schedule_enabled", default: false
    t.string "slug"
    t.string "timezone", default: "UTC"
    t.datetime "updated_at", null: false
    t.index ["google_calendar_enabled"], name: "index_bands_on_google_calendar_enabled"
    t.index ["google_calendar_id"], name: "index_bands_on_google_calendar_id"
    t.index ["name"], name: "index_bands_on_name", unique: true
    t.index ["owner_id"], name: "index_bands_on_owner_id"
    t.index ["public_schedule_enabled"], name: "index_bands_on_public_schedule_enabled"
    t.index ["slug"], name: "index_bands_on_slug", unique: true
  end

  create_table "blackout_dates", force: :cascade do |t|
    t.date "blackout_date", null: false
    t.datetime "created_at", null: false
    t.string "reason"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["blackout_date"], name: "index_blackout_dates_on_blackout_date"
    t.index ["user_id", "blackout_date"], name: "index_blackout_dates_on_user_id_and_blackout_date", unique: true
    t.index ["user_id"], name: "index_blackout_dates_on_user_id"
  end

  create_table "gig_songs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "gig_id", null: false
    t.boolean "has_transition", default: false
    t.integer "position", null: false
    t.integer "set_number", default: 1, null: false
    t.integer "song_id", null: false
    t.text "transition_notes"
    t.integer "transition_timing"
    t.string "transition_type"
    t.datetime "updated_at", null: false
    t.index ["gig_id", "set_number", "position"], name: "index_gig_songs_on_gig_id_and_set_number_and_position"
    t.index ["gig_id"], name: "index_gig_songs_on_gig_id"
    t.index ["position"], name: "index_gig_songs_on_position"
    t.index ["set_number"], name: "index_gig_songs_on_set_number"
    t.index ["song_id"], name: "index_gig_songs_on_song_id"
  end

  create_table "gigs", force: :cascade do |t|
    t.integer "band_id", null: false
    t.datetime "created_at", null: false
    t.datetime "end_time"
    t.string "name", null: false
    t.text "notes"
    t.date "performance_date"
    t.datetime "start_time"
    t.datetime "updated_at", null: false
    t.integer "venue_id"
    t.index ["band_id", "performance_date"], name: "index_gigs_on_band_id_and_performance_date"
    t.index ["band_id"], name: "index_gigs_on_band_id"
    t.index ["name"], name: "index_gigs_on_name"
    t.index ["performance_date"], name: "index_gigs_on_performance_date"
    t.index ["venue_id"], name: "index_gigs_on_venue_id"
  end

  create_table "google_calendar_events", force: :cascade do |t|
    t.bigint "band_id", null: false
    t.datetime "created_at", null: false
    t.bigint "gig_id", null: false
    t.string "google_event_id", null: false
    t.datetime "last_synced_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }
    t.datetime "updated_at", null: false
    t.index ["band_id", "google_event_id"], name: "index_google_calendar_events_on_band_id_and_google_event_id", unique: true
    t.index ["band_id"], name: "index_google_calendar_events_on_band_id"
    t.index ["gig_id"], name: "index_google_calendar_events_on_gig_id"
    t.index ["google_event_id"], name: "index_google_calendar_events_on_google_event_id"
    t.index ["last_synced_at"], name: "index_google_calendar_events_on_last_synced_at"
  end

  create_table "login_attempts", force: :cascade do |t|
    t.datetime "attempted_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.boolean "successful", default: false
    t.datetime "updated_at", null: false
    t.text "user_agent"
    t.string "username", null: false
    t.index ["attempted_at"], name: "index_login_attempts_on_attempted_at"
    t.index ["ip_address", "attempted_at"], name: "index_login_attempts_on_ip_address_and_attempted_at"
    t.index ["username", "attempted_at"], name: "index_login_attempts_on_username_and_attempted_at"
  end

  create_table "practice_availabilities", force: :cascade do |t|
    t.string "availability", null: false
    t.datetime "created_at", null: false
    t.text "notes"
    t.bigint "practice_id", null: false
    t.date "specific_date"
    t.time "suggested_end_time"
    t.time "suggested_start_time"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["availability"], name: "index_practice_availabilities_on_availability"
    t.index ["practice_id", "user_id", "specific_date"], name: "index_practice_availabilities_on_practice_user_date", unique: true
    t.index ["practice_id"], name: "index_practice_availabilities_on_practice_id"
    t.index ["user_id"], name: "index_practice_availabilities_on_user_id"
  end

  create_table "practices", force: :cascade do |t|
    t.bigint "band_id", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_user_id", null: false
    t.text "description"
    t.integer "duration", comment: "Duration in minutes"
    t.date "end_date"
    t.date "start_date", null: false
    t.datetime "start_time", precision: nil
    t.string "status", default: "active"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["band_id", "start_date"], name: "index_practices_on_band_id_and_start_date"
    t.index ["band_id"], name: "index_practices_on_band_id"
    t.index ["created_by_user_id"], name: "index_practices_on_created_by_user_id"
    t.index ["start_date"], name: "index_practices_on_start_date"
    t.index ["status"], name: "index_practices_on_status"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "data"
    t.string "session_id", null: false
    t.datetime "updated_at", null: false
    t.index ["session_id"], name: "index_sessions_on_session_id", unique: true
    t.index ["updated_at"], name: "index_sessions_on_updated_at"
  end

  create_table "song_catalogs", force: :cascade do |t|
    t.string "album"
    t.boolean "archived", default: false, null: false
    t.datetime "archived_at"
    t.string "artist", null: false
    t.datetime "created_at", null: false
    t.string "duration"
    t.string "genre"
    t.string "key", null: false
    t.text "lyrics"
    t.text "notes"
    t.string "original_key"
    t.integer "tempo"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.string "url"
    t.integer "year"
    t.index ["archived"], name: "index_song_catalogs_on_archived"
    t.index ["archived_at"], name: "index_song_catalogs_on_archived_at"
    t.index ["artist"], name: "index_song_catalogs_on_artist"
    t.index ["key"], name: "index_song_catalogs_on_key"
    t.index ["title"], name: "index_song_catalogs_on_title"
  end

  create_table "songs", force: :cascade do |t|
    t.string "album"
    t.boolean "archived", default: false, null: false
    t.datetime "archived_at", precision: nil
    t.string "artist", null: false
    t.datetime "created_at", null: false
    t.string "duration"
    t.string "genre"
    t.string "key", null: false
    t.text "lyrics"
    t.text "notes"
    t.string "original_key"
    t.bigint "song_catalog_id"
    t.integer "tempo"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.string "url"
    t.integer "year"
    t.index ["archived"], name: "index_songs_on_archived"
    t.index ["archived_at"], name: "index_songs_on_archived_at"
    t.index ["artist"], name: "index_songs_on_artist"
    t.index ["song_catalog_id"], name: "index_songs_on_song_catalog_id"
    t.index ["title"], name: "index_songs_on_title"
  end

  create_table "songs_bands", id: false, force: :cascade do |t|
    t.bigint "band_id", null: false
    t.boolean "practice_state", default: false, null: false
    t.datetime "practice_state_updated_at", precision: nil
    t.bigint "song_id", null: false
    t.string "transposed_key", limit: 10
    t.integer "transposition_semitones", default: 0
    t.index ["band_id", "practice_state"], name: "index_songs_bands_on_band_id_and_practice_state"
    t.index ["band_id"], name: "index_songs_bands_on_band_id"
    t.index ["practice_state"], name: "index_songs_bands_on_practice_state"
    t.index ["song_id", "band_id"], name: "index_songs_bands_on_song_id_and_band_id", unique: true
    t.index ["song_id"], name: "index_songs_bands_on_song_id"
  end

  create_table "user_bands", force: :cascade do |t|
    t.bigint "band_id", null: false
    t.datetime "created_at", null: false
    t.string "role", default: "member", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["band_id", "role"], name: "index_user_bands_on_band_id_and_role"
    t.index ["band_id"], name: "index_user_bands_on_band_id"
    t.index ["role"], name: "index_user_bands_on_role"
    t.index ["user_id", "band_id"], name: "index_user_bands_on_user_id_and_band_id", unique: true
    t.index ["user_id", "role"], name: "index_user_bands_on_user_id_and_role"
    t.index ["user_id"], name: "index_user_bands_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "display_name"
    t.string "email"
    t.integer "failed_attempts_count", default: 0, null: false
    t.datetime "last_failed_attempt_at", precision: nil
    t.integer "last_selected_band_id"
    t.datetime "locked_at", precision: nil
    t.string "oauth_email"
    t.string "oauth_provider"
    t.string "oauth_uid"
    t.string "oauth_username"
    t.string "password_digest"
    t.string "timezone", default: "UTC"
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["last_selected_band_id"], name: "index_users_on_last_selected_band_id"
    t.index ["locked_at"], name: "index_users_on_locked_at"
    t.index ["oauth_provider", "oauth_uid"], name: "index_users_on_oauth_provider_and_oauth_uid", unique: true
    t.index ["timezone"], name: "index_users_on_timezone"
    t.index ["username", "locked_at"], name: "index_users_on_username_and_locked_at"
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  create_table "venues", force: :cascade do |t|
    t.boolean "archived", default: false, null: false
    t.datetime "archived_at", precision: nil
    t.bigint "band_id"
    t.string "contact_name", null: false
    t.datetime "created_at", null: false
    t.string "location", null: false
    t.string "name", null: false
    t.text "notes"
    t.string "phone_number", null: false
    t.datetime "updated_at", null: false
    t.string "website"
    t.index ["archived"], name: "index_venues_on_archived"
    t.index ["archived_at"], name: "index_venues_on_archived_at"
    t.index ["band_id", "name"], name: "index_venues_on_band_id_and_name"
    t.index ["band_id"], name: "index_venues_on_band_id"
    t.index ["name"], name: "index_venues_on_name"
  end

  add_foreign_key "bands", "users", column: "owner_id"
  add_foreign_key "blackout_dates", "users"
  add_foreign_key "gig_songs", "gigs"
  add_foreign_key "gig_songs", "songs"
  add_foreign_key "gigs", "bands"
  add_foreign_key "gigs", "venues"
  add_foreign_key "google_calendar_events", "bands"
  add_foreign_key "google_calendar_events", "gigs"
  add_foreign_key "practice_availabilities", "practices"
  add_foreign_key "practice_availabilities", "users"
  add_foreign_key "practices", "bands"
  add_foreign_key "practices", "users", column: "created_by_user_id"
  add_foreign_key "songs", "song_catalogs"
  add_foreign_key "songs_bands", "bands"
  add_foreign_key "songs_bands", "songs"
  add_foreign_key "user_bands", "bands"
  add_foreign_key "user_bands", "users"
  add_foreign_key "users", "bands", column: "last_selected_band_id"
  add_foreign_key "venues", "bands"
end
