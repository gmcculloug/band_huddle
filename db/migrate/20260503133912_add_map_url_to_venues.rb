class AddMapUrlToVenues < ActiveRecord::Migration[7.0]
  def change
    add_column :venues, :map_url, :string
  end
end
