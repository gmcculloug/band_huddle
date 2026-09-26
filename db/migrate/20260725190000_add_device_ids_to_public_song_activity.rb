class AddDeviceIdsToPublicSongActivity < ActiveRecord::Migration[7.0]
  def change
    add_column :song_votes, :device_id, :string
    add_index :song_votes, [:song_id, :band_id, :device_id, :created_at],
      name: 'index_song_votes_on_song_band_device_time'

    add_column :song_recommendations, :device_id, :string
    add_index :song_recommendations, [:device_id, :created_at],
      name: 'index_song_recommendations_on_device_id_and_created_at'
  end
end
