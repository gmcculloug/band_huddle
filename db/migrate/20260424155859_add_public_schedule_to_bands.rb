class AddPublicScheduleToBands < ActiveRecord::Migration[7.0]
  def change
    add_column :bands, :public_schedule_enabled, :boolean, default: false
    add_index :bands, :public_schedule_enabled, name: 'index_bands_on_public_schedule_enabled'
  end
end