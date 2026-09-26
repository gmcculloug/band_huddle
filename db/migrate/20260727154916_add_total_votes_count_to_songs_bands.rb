class AddTotalVotesCountToSongsBands < ActiveRecord::Migration[7.0]
  def change
    add_column :songs_bands, :total_votes_count, :integer, default: 0, null: false
    add_index :songs_bands, :total_votes_count
  end
end
