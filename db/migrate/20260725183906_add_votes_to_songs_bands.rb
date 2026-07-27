class AddVotesToSongsBands < ActiveRecord::Migration[7.0]
  def change
    add_column :songs_bands, :votes_count, :integer, default: 0, null: false
    add_column :songs_bands, :votes_date, :date
    add_index :songs_bands, :votes_count
    add_index :songs_bands, :votes_date

    create_table :song_votes do |t|
      t.references :song, null: false, foreign_key: true
      t.references :band, null: false, foreign_key: true
      t.string :ip_address, null: false
      t.timestamps
    end
    add_index :song_votes, [:song_id, :band_id, :ip_address, :created_at], name: 'index_song_votes_on_song_band_ip_time'
  end
end
