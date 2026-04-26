class AddTimezoneToBands < ActiveRecord::Migration[7.0]
  def change
    add_column :bands, :timezone, :string, default: 'UTC'
  end
end
